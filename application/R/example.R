# load packages and helper files
library(here)
library(hal9001)
library(tidyverse)
library(SuperLearner)
source(here("R", "utils.R"))
set.seed(7518)

# simulation parameters
n_obs <- 100
delta_ipsi <- exp(seq(-10, 10, by = 0.5))

# make mock data
#data <- simdata(n_obs)
#head(data)

# load permuted data from Kara
data <- read_csv(here("data", "xbot_permuted.csv"))

# permutation bug: A is all zero for some reason?!
table(data$A)
data$A <- rbinom(nrow(data), 1, 0.6)

# also, too many W for me to run on my personal machine, so we reduce here
W_random <- as.data.frame(data[, substr(names(data), 1, 1) == "W"][, 10:19])
data_reduced <- cbind(data[, c(str_subset(names(data), "Z"), "Y", "L", "A")],
                      W_random)

# remove extra stuff from utils.R
rm(list = setdiff(ls(), c("bound", "truncate", "gfun", "gdeltafun", "gdelta1",
                          "delta_ipsi", "data", "data_reduced")))
ls()
source(here("R", "slfuns.R"))
source(here("R", "estimate.R"))

# set up SL library + smaller library for faster debugging
sl_lib <- c("SL.mean", "SL.bayesglm", "SL.earth", "SL.gam", "SL.myglm",
            "SL.myglmnet", "SL.hal9001", "SL.caretXGB", "SL.caretRF")
sl_lib_debug <- c("SL.mean", "SL.bayesglm")

# estimate nuisance parameters
nuisance <- fitnuisance(data_reduced, nfolds = 5, sl_lib = sl_lib_debug)

# construct estimates of (in)direct effects
out <- lapply(delta_ipsi, function(delta) {
  results <- estimators(data, delta = delta, nuisance, sl_lib = sl_lib_debug)
  return(results)
})
out
