args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
here <- dirname(normalizePath(script))
source(file.path(here, "parameters.R"))
source(file.path(here, "model.R"))
out <- file.path(dirname(dirname(dirname(here))), "output", "heemod")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
model <- build_model()
print(summary(model))
values <- get_values(model)
write.csv(values, file.path(out, "cycle_values.csv"), row.names = FALSE)
saveRDS(model, file.path(out, "base_case.rds"))
totals <- aggregate(value ~ .strategy_names + value_names, values, sum)
base <- reshape(totals, idvar = ".strategy_names", timevar = "value_names", direction = "wide")
names(base) <- sub("value\\.", "", names(base))
names(base)[1] <- "strategy"
write.csv(base, file.path(out, "base_case.csv"), row.names = FALSE)
comparison <- merge(reference, base, by = "strategy", suffixes = c("_excel", "_heemod"))
comparison$cost_difference <- comparison$cost_heemod - comparison$cost_excel
comparison$qaly_difference <- comparison$qaly_heemod - comparison$qaly_excel
print(comparison)
write.csv(comparison, file.path(out, "excel_comparison.csv"), row.names = FALSE)
save_plot <- function(p, name, height = 6) {
  ggplot2::ggsave(file.path(out, name), plot = p, width = 9, height = height, dpi = 180)
}
save_plot(plot(model), "state_trace.png")

if (!"--base-only" %in% args) {
  n_psa <- if ("--psa" %in% args) as.integer(args[match("--psa", args) + 1]) else 1000L
  dsa_args <- list()
  for (name in names(base_inputs)[base_inputs != 0]) {
    value <- base_inputs[[name]]
    bounds <- if (startsWith(name, "discount_")) c(0, 0.05) else value * c(0.9, 1.1)
    dsa_args <- c(dsa_args, list(as.name(name), bounds[1], bounds[2]))
  }
  dsa <- run_dsa(model, do.call(define_dsa, dsa_args))
  write.csv(as.data.frame(dsa$dsa), file.path(out, "owsa.csv"), row.names = FALSE)
  saveRDS(dsa, file.path(out, "owsa.rds"))
  save_plot(plot(dsa, result = "icer", type = "difference", limits_by_bars = FALSE),
    "tornado.png",
    height = max(6, length(dsa_args) / 3 * 0.24)
  )

  distributions <- lapply(names(psa_family), function(name) {
    mean <- base_inputs[[name]]
    sd <- mean * 0.1
    expression <- switch(psa_family[[name]],
      Beta = {
        k <- mean * (1 - mean) / sd^2 - 1
        sprintf("beta(%s, %s)", mean * k, (1 - mean) * k)
      },
      Gamma = sprintf("gamma(mean = %s, sd = %s)", mean, sd),
      Lognormal = sprintf("lognormal(meanlog = %s, sdlog = %s)", log(mean), log(1.2 / 0.8) / 3.92)
    )
    rlang::new_quosure(as.formula(paste(name, "~", expression)), env = environment())
  })
  set.seed(20261031)
  psa <- run_psa(model, define_psa_(distributions), N = n_psa)
  saveRDS(psa, file.path(out, "psa.rds"))
  write.csv(psa$psa, file.path(out, "psa_samples.csv"), row.names = FALSE)
  save_plot(plot(psa, type = "ce", diff = TRUE, threshold = wtp), "psa_scatter.png")
  save_plot(plot(psa, type = "ac", max_wtp = 300000, n = 61, log_scale = FALSE), "ceac.png")
}
