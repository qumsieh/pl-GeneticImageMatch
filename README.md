pl-GeneticImageMatch
====================

Genetic Algorithm to Match Images in Perl

    Usage:   gaImgMatch.pl  [options]

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
                                Default = ./$$
