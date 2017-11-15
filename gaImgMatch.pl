use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use AI::Genetic;
use GD;

my %OPTS;
GetOptions(\%OPTS,
  'num_poly:i',      # number of trianlges
  'poly_alpha:i',    # transparency of triangles from 0 .. 127
  'pop_size:i',      # GA population size
  'xover_rate:f',    # crossover rate
  'mutation_rate:f', # mutation rate
  'generations:i',    # number of generations
  'iter_per_gen:i',  # iterations per generation
  'strategy:s',      # GA strategy
  'ref_image:s',     # reference PNG image
  'out_dir:s',       # output directory
  'h'                # help
);

usage() if $OPTS{h} or !$OPTS{ref_image};

my $NUM_POLY   = $OPTS{num_poly}      || 50;    # how many polygons to use
my $POLY_ALPHA = $OPTS{poly_alpha}    || 64;    # the transparency (0 .. 127)
my $GA_POP     = $OPTS{pop_size}      || 100;   # ga population size
my $XOVER_RATE = $OPTS{xover_rate}    || 0.91;  # crossover rate
my $MUT_RATE   = $OPTS{mutation_rate} || 0.01;  # mutation rate

my $GENERATIONS  = $OPTS{generations}  || 200;
my $ITER_PER_GEN = $OPTS{iter_per_gen} || 25;
my $STRATEGY     = $OPTS{strategy}     || 'rouletteTwoPoint';

my $OUT_DIR    = $OPTS{out_dir} || "./$$";
my $REFIMGFILE = $OPTS{ref_image};

unless (-e $REFIMGFILE) {
  die "ERROR: Image '$REFIMGFILE' does not exist or is not readable.\n";
}

my $REFIMG = GD::Image->newFromPng($REFIMGFILE);

# to speed things up, read the ref image into memory.
print "-- Reading reference image.\n";
my $REFDATA = readImage($REFIMG);
print "   Done.\n";

my ($WIDTH, $HEIGHT) = $REFIMG->getBounds;

print "-- Target Size is ($WIDTH x $HEIGHT) pixels.\n";
GD::Image->trueColor(1);

# create the GA.
print <<EOE;
-- Creating GA population.
   Population size = $GA_POP
   Crossover rate  = $XOVER_RATE
   Mutation rate   = $MUT_RATE
   Polygons        = $NUM_POLY
   Poly Alpha      = $POLY_ALPHA
EOE
;
my $ga = AI::Genetic->new(
	-type => 'rangevector',
	-population => $GA_POP,
	-crossover  => $XOVER_RATE,
	-mutation   => $MUT_RATE,
	-fitness    => \&fitness,
);

my @initGenes = map {
	[0, $WIDTH  - 1], # x1
	[0, $HEIGHT - 1], # y1
	[0, $WIDTH  - 1], # x2
	[0, $HEIGHT - 1], # y2
	[0, $WIDTH  - 1], # x3
	[0, $HEIGHT - 1], # y3
	[0, 255],         # r
	[0, 255],         # g
	[0, 255],         # b
} 1 .. $NUM_POLY;

#print Dumper(\@initGenes);
#print "Genes = ", scalar(@initGenes), ".\n";
$ga->init([@initGenes]);
print "   Done.\n";

print <<EOE;
-- Evolving.
   Generations           = $GENERATIONS
   Iterations/Generation = $ITER_PER_GEN

   Starting time         = @{[scalar localtime]}
   Run directory         = $OUT_DIR
EOE
;

mkdir $OUT_DIR or die "ERROR: Can not create output dir '$OUT_DIR': $!\n";

{
  open my $fh, '>', "$OUT_DIR/summary.txt";
  print $fh "
   Image           = $REFIMGFILE

   Population size = $GA_POP
   Crossover rate  = $XOVER_RATE
   Mutation rate   = $MUT_RATE
   Polygons        = $NUM_POLY
   Poly Alpha      = $POLY_ALPHA

   Generations           = $GENERATIONS
   Iterations/Generation = $ITER_PER_GEN
";
}

for my $gen (1.. $GENERATIONS) {
  print "\n-- Starting generation $gen at ", scalar(localtime), ".\n";
  $ga->evolve($STRATEGY, $ITER_PER_GEN);

  my $score = $ga->getFittest->score;
  print "   Done at ", scalar(localtime), ".\n";
  print "   Best Score so far = ", $score, ".\n";

  # save the image.
  {
    my $gd = imgFromGenes(scalar $ga->getFittest->genes);
    open my $fh, '>', "$OUT_DIR/OutGen$gen.png";
    binmode $fh;
    print $fh $gd->png;
    close $fh;
  }

  # save the gene
  {
    $score *= -1;
    open my $fh, '>', "$OUT_DIR/OutGen$gen.$score.gene";
    local $Data::Dumper::Indent  = 0;
    local $Data::Dumper::Varname = 'GENES';
    print $fh Dumper(scalar $ga->getFittest->genes), "\n";
    close $fh;
  }
}

print "   Done at ", scalar(localtime), ".\n";

sub fitness {
	my $genes = shift;
	
	my $gd = imgFromGenes($genes);
	
	# now get the image difference
	my $score = getImgDiff($REFDATA, $gd);
	
	return $score;
}

sub imgFromGenes {
	my $genes = shift;
	
	# create an image out of this organism.
	my $gd = GD::Image->new($WIDTH, $HEIGHT);
	$gd->colorAllocate(255, 255, 255); # set white background.
	
	# now loop through all the genes and extract the triangles and their coordinates and colors.
	# each triangle needs 9 genes
	# coord1 [0 .. $WIDTH - 1]
	#        [0 .. $HEIGHT - 1]
	# coord2 [0 .. $WIDTH - 1]
	#        [0 .. $HEIGHT - 1]
	# coord3 [0 .. $WIDTH - 1]
	#        [0 .. $HEIGHT - 1]
	# colorR [0 .. 255]
	# colorG [0 .. 255]
	# colorB [0 .. 255]
	
	for my $tr (0 .. $NUM_POLY - 1) {
		my $ind = 9 * $tr;
		my ($x1, $y1, $x2, $y2, $x3, $y3, $r, $g, $b) = @{$genes}[$ind .. $ind + 8];
		
		my $col = $gd->colorAllocateAlpha($r, $g, $b, $POLY_ALPHA);
		my $poly = GD::Polygon->new;
		$poly->addPt($x1, $y1);
		$poly->addPt($x2, $y2);
		$poly->addPt($x3, $y3);
		$gd->filledPolygon($poly, $col);
	}
	
	return $gd;
}

sub getImgDiff {
	my ($refData, $thisImg) = @_;

	my $score = 0;
		
	for my $x (0 .. $WIDTH - 1) {
		for my $y (0 .. $HEIGHT - 1) {
			my $i = $thisImg->getPixel($x, $y);
			my @rgb = $thisImg->rgb($i);
			
			my $dr = ($rgb[0] - $refData->[$x][$y][0]) ** 2;
			my $dg = ($rgb[1] - $refData->[$x][$y][1]) ** 2;
			my $db = ($rgb[2] - $refData->[$x][$y][2]) ** 2;
			
			$score += $dr + $dg + $db;
		}
	}
	
	return $score * -1;
}

sub readImage {
	my $gd = shift;
	
	my ($width, $height) = $gd->getBounds;
	
	my @data;
	
	for my $x (0 .. $width - 1) {
		for my $y (0 .. $height - 1) {
			my $i = $gd->getPixel($x, $y);
			my @rgb = $gd->rgb($i);
			
			$data[$x][$y] = \@rgb;
		}
	}
	
	return \@data;
}

sub usage {
	print STDERR <<EOH;
	
Usage:   $0  [options]

options:

    -ref_image <file.png>     Reference image in PNG format.        REQUIRED
    -num_poly  <integer>      Number of polygons per solution.      OPTIONAL
                              Default = 50
    -poly_alpha <integer>     Transparency of each triangle.        OPTIONAL
                              Values from 0 (opaque) to 127 (transparent).
                              Default = 64
    -pop_size <integer>       GA population size.                   OPTIONAL
                              Default = 100
    -xover_rate <float>       GA crossover rate from 0 to 1.        OPTIONAL
                              Default = 0.91
    -mutation_rate <float>    GA mutation rate from 0 to 1.         OPTIONAL
                              Default = 0.01
    -generations <integer>    The number of generations to evolve.  OPTIONAL
                              Default = 200
    -iter_per_gen <integer>   Number of iterations per generation.  OPTIONAL
                              Default = 25
    -strategy <name>          GA evolution strategy to use.         OPTIONAL
                              See AI::Genetic docs for more info.
                              Default = "rouletteTwoPoint"
    -out_dir <dirname>        Output directory.                     OPTIONAL
                              Default = ./\$\$
                              
EOH
	exit -1;
}
