# packages and programmatic housekeeping
Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS="true")
renv::activate(here::here(".."))
library(here)
library(data.table)
library(ggthemes)
library(knitr)
library(tidyverse)
library(latex2exp)
library(ggrepel)
library(ggsci)
library(ggpubr)
library(patchwork)
pd <- position_dodge(0.2)

# results file and simulation settings
sim_file <- "lite_intmedshift_2022-07-13_19:31:28.rds"
ipsi_delta <- 2

# compute truth based on DGP
source(here("R", "get_truth.R"))
truth <- get_sim_truth(delta = ipsi_delta)

# load simulation results
sim_results <- readRDS(here("data", sim_file))
n_samp <- as.numeric(str_remove(names(sim_results), "n_"))
n_sim <- length(unique(sim_results[[length(n_samp)]]$sim_iter))
sim_res_clean <- sim_results %>%
  bind_rows(.id = "n_samp") %>%
  mutate(
    n_samp = as.numeric(str_remove(n_samp, "n_")),
    sim_scenario = case_when(sim_type == "allc" ~ "All Correct",
                             sim_type == "misg" ~ "G Misspecified",
                             sim_type == "mise" ~ "E Misspecified",
                             sim_type == "mism" ~ "M Misspecified",
                             sim_type == "misb" ~ "B Misspecified",
                             sim_type == "misd" ~ "D Misspecified"),
    estim_label = case_when(estimator == "os" ~ "One-step",
                            estimator == "tmle" ~ "TMLE"),
    param_label = case_when(parameter == "direct" ~ "Direct Effect",
                            parameter == "indirect" ~ "Indirect Effect")
  ) %>%
  group_by(estimator, parameter, sim_type, n_samp, sim_scenario,
           estim_label, param_label)

# HISTOGRAM COMPARING PERFORMANCE ACROSS ALL ESTIMATORS
p_samp_dist_de <- sim_res_clean %>%
  dplyr::filter(parameter == "direct" & sim_type == "allc") %>%
  mutate(
    mean_est = mean(estimate, na.rm = TRUE)
  ) %>%
  ungroup(n_samp) %>%
  ggplot(aes(x = estimate, group = estim_label, fill = estim_label)) +
    geom_histogram(alpha = 0.75, binwidth = 0.01) +
    labs(x = "", y = "",
         title = "Direct effect: Sampling distributions"
    ) +
    facet_grid(estim_label ~ n_samp, scales = "free") +
    geom_vline(aes(xintercept = mean_est), linetype = "dotted",
               colour = "black") +
    geom_vline(aes(xintercept = as.numeric(truth[1, 2])),
               linetype = "twodash", colour = "black") +
    theme_bw() +
    theme(legend.position = "none")

p_samp_dist_ie <- sim_res_clean %>%
  dplyr::filter(parameter == "indirect" & sim_type == "allc") %>%
  mutate(
    mean_est = mean(estimate, na.rm = TRUE)
  ) %>%
  ungroup(n_samp) %>%
  ggplot(aes(x = estimate, group = estim_label, fill = estim_label)) +
    geom_histogram(alpha = 0.75, binwidth = 0.01) +
    labs(x = "", y = "",
         title = "Indirect effect: Sampling distributions"
    ) +
    facet_grid(estim_label ~ n_samp, scales = "free") +
    geom_vline(aes(xintercept = mean_est), linetype = "dotted",
               colour = "black") +
    geom_vline(aes(xintercept = as.numeric(truth[2, 2])),
               linetype = "twodash", colour = "black") +
    theme_bw() +
    theme(legend.position = "none")

p_samp_dist <- p_samp_dist_de + p_samp_dist_ie
p_samp_dist

## SUMMARY TABLE OF ESTIMATOR PERFORMANCE
table_summary_sim <- sim_res_clean %>%
  mutate(truth = case_when(parameter == "direct" ~ as.numeric(truth[1, 2]),
                           parameter == "indirect" ~ as.numeric(truth[2, 2]))
  ) %>%
  summarise(
    bias_abs = abs(mean(estimate - truth, na.rm = TRUE)),
    mc_var = var(estimate, na.rm = TRUE),
    mse = (bias_abs)^2 + mc_var
  ) %>%
  mutate(
    bias_abs_sqrtn = bias_abs * sqrt(n_samp),
    mc_se_sqrtn = sqrt(mc_var * n_samp),
    mse_n = mse * n_samp,
    true_psi = case_when(parameter == "direct" ~ as.numeric(truth[1, 2]),
                         parameter == "indirect" ~ as.numeric(truth[2, 2])),
    eff_var = case_when(parameter == "direct" ~ as.numeric(truth[1, 3]),
                        parameter == "indirect" ~ as.numeric(truth[2, 3]))
  )
#knitr::kable(table_summary_sim, format = "markdown")

## SUMMARY PLOT COMPARING BIAS (SCALED BY ROOT-N) OF ESTIMATORS
p_bias_scaled <- table_summary_sim %>%
  ggplot(aes(x = factor(n_samp), y = bias_abs_sqrtn, group = estim_label,
             shape = estim_label, colour = estim_label, fill = estim_label)) +
    geom_point(alpha = 0.75, size = 7, position = pd) +
    geom_line(linetype = "dotted", position = pd) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "black") +
    coord_cartesian(ylim = c(0, 1)) +
    labs(x = "Sample size",
         y = TeX("$\\sqrt{n} \\times$ |$\\psi - \\hat{\\psi}$|"),
         title = "Scaled bias of one-step and TML estimators"
        ) +
    scale_shape_manual(values = c(21, 23)) +
    scale_fill_nejm() +
    theme_bw() +
    theme(legend.background = element_rect(fill = "gray90", size = 0.25,
                                           linetype = "dotted"),
          legend.position = "bottom",
          legend.title = element_blank(),
          text = element_text(size = 28),
          axis.text.x = element_text(size = 20, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 25)
         ) +
    scale_y_continuous(breaks = seq(0, 2, by = 0.2)) +
    facet_grid(param_label ~ sim_scenario, scales = "free_y")
ggsave(filename = here("graphs", "bias_scaled.pdf"),
       plot = p_bias_scaled, width = 22, height = 14)

## SUMMARY PLOT COMPARING STANDARD ERROR (SCALED BY ROOT-N) OF ESTIMATORS
p_sd_scaled <- table_summary_sim %>%
  ggplot(aes(x = factor(n_samp), y = mc_se_sqrtn, group = estim_label,
             shape = estim_label, colour = estim_label, fill = estim_label)) +
    geom_point(alpha = 0.75, size = 7, position = pd) +
    geom_line(linetype = "dotted", position = pd) +
    #geom_hline(yintercept = 0, linetype = "dashed", colour = "black") +
    coord_cartesian(ylim = c(0, 3)) +
    labs(x = "Sample Size",
         y = TeX("$\\sqrt{n \\times Var(\\hat{\\psi})}$"),
         title = "Scaled variance of one-step and TML estimators"
        ) +
    scale_shape_manual(values = c(21, 23)) +
    scale_fill_nejm() +
    theme_bw() +
    theme(legend.background = element_rect(fill = "gray90", size = 0.25,
                                           linetype = "dotted"),
          legend.position = "bottom",
          legend.title = element_blank(),
          text = element_text(size = 28),
          axis.text.x = element_text(size = 20, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 25)
         ) +
    facet_grid(param_label ~ sim_scenario, scales = "free_y")
ggsave(filename = here("graphs", "sd_scaled.pdf"),
       plot = p_sd_scaled, width = 22, height = 14)

# SUMMARY PLOT COMPARING MEAN-SQUARED ERROR (SCALED BY N) OF ESTIMATORS
p_mse_scaled <- table_summary_sim %>%
  ggplot(aes(x = factor(n_samp), y = mse_n, group = estim_label,
             shape = estim_label, colour = estim_label, fill = estim_label)) +
    geom_point(alpha = 0.75, size = 7, position = pd) +
    geom_line(linetype = "dotted", position = pd) +
    geom_hline(aes(yintercept = eff_var), linetype = "dashed",
               colour = "black") +
    labs(x = "Sample Size",
         y = TeX("$n \\times ((\\psi - \\hat{\\psi})^2 + \\hat{\\sigma}^2)$"),
         title = "Scaled MSE of one-step and TML estimators"
        ) +
    scale_shape_manual(values = c(21, 23)) +
    scale_fill_nejm() +
    theme_bw() +
    theme(legend.background = element_rect(fill = "gray90", size = 0.25,
                                           linetype = "dotted"),
          legend.position = "bottom",
          legend.title = element_blank(),
          text = element_text(size = 28),
          axis.text.x = element_text(size = 20, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 25)
         ) +
    scale_y_continuous(breaks = seq(0, 5, by = 0.5)) +
    coord_cartesian(ylim = c(0, 3)) +
    facet_grid(param_label ~ sim_scenario, scales = "free_y")
ggsave(filename = here("graphs", "mse_scaled.pdf"),
       plot = p_mse_scaled, width = 22, height = 14)

# SUMMARY PANEL PLOT (BIAS, VARIANCE, MSE)
p_panel <- (p_bias_scaled + xlab("") + theme(legend.position = "none")) /
            p_mse_scaled
ggsave(filename = here("graphs", "sim_panel.pdf"),
       plot = p_panel, width = 28, height = 20)
