To reproduce the results of the simulation study reported in the supplementary
materials of the manuscript, examine the batch scripts in the `slurm`
subdirectory. Equivalently, the following may be run from an `R` session started
from the same directory in which this file is located

```r
install.packages("here")
library(here)
source(here("R", "00_install_pkgs.R"))
source(here("R", "03_run_simulation.R"))
```

The simulation study was originally completed on 10 April 2020. At that time,
R version 3.6.3 was used on [UC Berkeley's Savio high-performance computing
cluster](https://research-it.berkeley.edu/services/high-performance-computing/system-overview).
