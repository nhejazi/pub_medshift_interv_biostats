# set user-specific package library
.libPaths("/global/scratch/nhejazi/R")
Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS="true")

# set CRAN mirror and temporary directory
options(repos = structure(c(CRAN = "https://cran.rstudio.com/")))
unixtools::set.tempdir("/global/scratch/nhejazi/rtmp")

# lie to pkgbuild, as per Jeremy
pkgbuild:::cache_set("has_compiler", TRUE)

# from CRAN
install.packages(c("here", "tidyverse", "remotes", "future", "future.apply",
                   "doFuture", "foreach", "doRNG", "data.table", "devtools",
                   "Rsolnp", "nnls", "glmnet", "Rcpp", "origami", "hal9001"),
                 lib = "/global/scratch/nhejazi/R")

# use remotes to install from GitHub
remotes::install_github(c("tlverse/sl3@master",
                          "tlverse/hal9001@master"),
                        lib = "/global/scratch/nhejazi/R")

# update all packages
#update.packages(ask = FALSE, lib.loc = "/global/scratch/nhejazi/R")
