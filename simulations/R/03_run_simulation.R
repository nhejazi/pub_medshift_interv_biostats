# virtual environment and packages
Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS="true")
renv::activate(here::here(".."))
library(here)
library(data.table)
library(foreach)
library(future)
library(doFuture)
library(doRNG)
library(hal9001)
library(origami)
library(sl3)
library(SuperLearner)
library(tidyverse)
devtools::load_all(here("..", "intmedlite"))

# load scripts, parallelization, PRNG
source(here("R", "01_setup_data.R"))
source(here("R", "02_fit_estimators.R"))
setDTthreads(2L)
registerDoFuture()
plan(multicore, workers = round(0.8 * availableCores()))

# simulation parameters
set.seed(7259)
n_sim <- 400                                  # number of simulations
n_obs <- c(400, 800, 1600, 2400, 3200)        # sample sizes
ipsi_delta <- 2                               # IPSI shift

# perform simulation across sample sizes
sim_results <- lapply(n_obs, function(sample_size) {
  # get results in parallel
  results <- foreach(this_iter = seq_len(n_sim),
                     .options.multicore = list(preschedule = FALSE),
                     .errorhandling = "remove") %dorng% {
    data_sim <- sim_data(n_obs = sample_size)
    est_out <- fit_estimators(data = data_sim, delta = ipsi_delta)
    return(est_out)
  }

  # concatenate iterations
  results_out <- bind_rows(results, .id = "sim_iter")
  return(results_out)
})

# save results to file
names(sim_results) <- paste("n", n_obs, sep = "_")
timestamp <- str_replace_all(Sys.time(), " ", "_")
saveRDS(object = sim_results,
        file = here("data", paste0("lite_intmedshift_", timestamp, ".rds")))
