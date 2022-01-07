# load packages and data
library(here)
library(tidyverse)
library(latex2exp)
library(ggsci)
pd <- position_dodge(0.5)
load(here("data", "shiftmedexamp.Rdata"))

# confidence interval multipliers
ci_level <- 0.95
ci_mult <- abs(qnorm(p = (1 - ci_level) / 2))

# shift grid
delta_ipsi <- exp(seq(-10, 10, by = 0.5))
delta_ipsi_nonnull <- delta_ipsi[delta_ipsi != 1]
delta_ipsi_nonnull_trim <- delta_ipsi_nonnull[log(delta_ipsi_nonnull) >= -5 &
                                              log(delta_ipsi_nonnull) <= 5]
out_trimmed <- out[[which(ipsi_trim_idx)]]
names(out) <- log(delta_ipsi_nonnull)

# build summaries for each delta and estimator
out_clean <- lapply(out,
  function(estim_delta) {
    # separate estimates for the DE and IE
    de_ie_est <- estim_delta %>%
      as_tibble %>%
      mutate(
        estimate = -1 * estimate,
        ci_lwr = estimate - ci_mult * ses,
        ci_upr = estimate + ci_mult * ses
      ) %>%
      select(-n) %>%
      group_by(parameter, estimator)
    return(de_ie_est)
  }) %>%
  bind_rows(.id = "delta") %>%
  dplyr::filter(as.numeric(delta) >= -5 & as.numeric(delta) <= 5) %>%
  mutate(
    delta = factor(exp(as.numeric(delta)), levels = delta_ipsi_nonnull),
    parameter = ifelse(parameter == "DE", "Direct Effect", "Indirect Effect"),
    estimator = ifelse(estimator == "OS", "One step estimate", "TML estimate")
  )

# make plots of DE and IE estimates
p_de_ie <- out_clean %>%
  ggplot(aes(x = delta, y = estimate, group = estimator, colour = estimator,
             shape = estimator, fill = estimator)) +
  geom_hline(aes(yintercept = 0), linetype = "dashed", colour = "black") +
  geom_errorbar(aes(ymin = ci_lwr, ymax = ci_upr), width = 0.3,
                linetype = "dotted", colour = "black", position = pd) +
  geom_line(linetype = "dashed", size = 1, position = pd) +
  geom_point(alpha = 0.75, size = 6, position = pd) +
  labs(x = TeX(paste("Odds $\\delta$ of exposure to adaptive versus static",
                     "prescription strategies")),
       y = TeX("Estimated change in population intervention risk of relapse"),
       title = paste("Adaptive prescription strategies directly lower",
                     "risk of OUD relapse"),
       subtitle = paste("based on estimated stochastic interventional",
                        "(in)direct effects")
      ) +
  theme_bw() +
  theme(legend.background = element_rect(fill = "gray90", size = 0.25,
                                           linetype = "dotted"),
          legend.position = "bottom",
          legend.title = element_blank(),
          text = element_text(size = 25),
          axis.text.x = element_text(angle = 30, size = 22, hjust = 1),
          axis.text.y = element_text(size = 22)) +
  guides(colour = guide_legend(override.aes = list(alpha = 1))) +
  facet_grid(parameter ~ ., scales = "free_y") +
  scale_shape_manual(values = c(22, 25, 12, 13, 23, 24)) +
  scale_x_discrete(labels = formatC(delta_ipsi_nonnull_trim,
                                    format = "e", 1)) +
  scale_colour_nejm() +
  scale_fill_nejm()

# save plot
ggsave(filename = here("graphs", "manuscript_xbot.pdf"),
       plot = p_de_ie, width = 22, height = 14)
