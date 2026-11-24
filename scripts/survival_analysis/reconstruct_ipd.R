library(IPDfromKM)

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
stopifnot(length(script_arg) == 1L)
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg)))
root <- dirname(dirname(script_dir))
analysis_dir <- file.path(root, "output", "survival_analysis")
dir.create(file.path(analysis_dir, "data"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(analysis_dir, "images"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(analysis_dir, "sessions"), recursive = TRUE, showWarnings = FALSE)
set.seed(20030309)

specs <- list(
  pfs_dato = list(times = seq(0, 15, 3), risk = c(365, 249, 158, 66, 15, 4),
                  events = NULL, median = 6.9),
  pfs_icc = list(times = seq(0, 15, 3), risk = c(367, 205, 93, 26, 8, 1),
                 events = NULL, median = 4.9),
  os_dato = list(times = seq(0, 33, 3),
                 risk = c(365, 349, 331, 299, 259, 227, 180, 118, 49, 12, 1, 0),
                 events = 223, median = 18.6),
  os_icc = list(times = seq(0, 33, 3),
                risk = c(367, 335, 309, 283, 249, 213, 175, 123, 51, 9, 1, 0),
                events = 213, median = 18.3)
)
raw_points <- list()
km_points <- list()
checks <- list()
risk_checks <- list()

for (key in names(specs)) {
  spec <- specs[[key]]
  endpoint <- strsplit(key, "_")[[1]][1]
  arm <- if (endsWith(key, "dato")) "Dato-DXd" else "ICC"
  raw <- read.csv(
    file.path(root, "data", "survival", paste0(key, ".csv")),
    header = FALSE,
    col.names = c("time", "survival")
  )
  stopifnot(
    ncol(raw) == 2L,
    all(vapply(raw, is.numeric, logical(1))),
    all(is.finite(as.matrix(raw))),
    length(spec$times) == length(spec$risk),
    all(diff(spec$times) > 0),
    all(diff(spec$risk) <= 0)
  )
  prep <- preprocess(
    dat = raw,
    trisk = spec$times,
    nrisk = spec$risk,
    maxy = 1
  )
  result <- getIPD(
    prep = prep,
    armID = if (arm == "Dato-DXd") 1 else 0,
    tot.events = spec$events
  )
  ipd <- result$IPD
  stopifnot(
    nrow(ipd) == spec$risk[1],
    all(is.finite(ipd$time)),
    all(ipd$time >= 0),
    all(ipd$status %in% c(0, 1))
  )
  ipd$patient_id <- seq_len(nrow(ipd))
  ipd$arm <- arm
  ipd$endpoint <- toupper(endpoint)
  write.csv(
    ipd,
    file.path(analysis_dir, "data", paste0(key, "_ipd.csv")),
    row.names = FALSE
  )
  write.csv(
    prep$preprocessdat,
    file.path(analysis_dir, "data", paste0(key, "_preprocessed.csv")),
    row.names = FALSE
  )
  fit <- survfit(Surv(time, status) ~ 1, data = ipd)
  km_points[[key]] <- data.frame(
    time = c(0, fit$time),
    survival = c(1, fit$surv),
    arm = arm,
    endpoint = endpoint
  )
  raw$arm <- arm
  raw$endpoint <- endpoint
  raw_points[[key]] <- raw
  valid <- raw$time >= 0 & raw$survival >= 0 & raw$survival <= 1
  index <- findInterval(raw$time[valid], fit$time)
  reconstructed <- c(1, fit$surv)[index + 1L]
  error <- reconstructed - raw$survival[valid]
  checks[[key]] <- data.frame(
    curve = key,
    patients = nrow(ipd),
    reconstructed_events = sum(ipd$status),
    published_events = if (is.null(spec$events)) NA_integer_ else spec$events,
    reconstructed_median_months = unname(summary(fit)$table["median"]),
    published_median_months = spec$median,
    rmse_vs_raw = sqrt(mean(error^2)),
    max_absolute_error_vs_raw = max(abs(error)),
    raw_points = nrow(raw),
    preprocessed_points = nrow(prep$preprocessdat)
  )
  risk_checks[[key]] <- data.frame(
    curve = key,
    time_months = spec$times,
    published_at_risk = spec$risk,
    reconstructed_at_risk = vapply(
      spec$times,
      function(time) sum(ipd$time >= time),
      integer(1)
    )
  )
}
checks <- do.call(rbind, checks)
risk_checks <- do.call(rbind, risk_checks)
write.csv(checks, file.path(analysis_dir, "data", "ipd_summary.csv"), row.names = FALSE)
write.csv(
  risk_checks,
  file.path(analysis_dir, "data", "ipd_risk_counts.csv"),
  row.names = FALSE
)
print(checks)
raw_points <- do.call(rbind, raw_points)
km_points <- do.call(rbind, km_points)
for (endpoint in c("pfs", "os")) {
  plot <- ggplot() +
    geom_point(
      data = raw_points[raw_points$endpoint == endpoint, ],
      aes(time, survival, color = arm),
      size = 1.5, alpha = 0.45
    ) +
    geom_step(
      data = km_points[km_points$endpoint == endpoint, ],
      aes(time, survival, color = arm),
      linewidth = 0.8
    ) +
    scale_color_manual(values = c("Dato-DXd" = "#A40063", "ICC" = "#005493")) +
    scale_x_continuous(breaks = seq(0, 36, 3)) +
    scale_y_continuous(breaks = seq(0, 1, 0.2)) +
    coord_cartesian(
      xlim = c(0, if (endpoint == "pfs") 16 else 36),
      ylim = c(0, 1), expand = FALSE
    ) +
    labs(
      title = paste(toupper(endpoint), "- reconstructed KM"),
      subtitle = "Line: reconstructed IPD   |   Points: digitized curve",
      x = "Time since randomization (months)",
      y = "Survival probability",
      color = NULL
    ) +
    theme_classic(base_size = 14) +
    theme(
      legend.position = "top",
      legend.justification = "left",
      plot.title = element_text(face = "bold"),
      axis.text = element_text(color = "black")
    )
  for (extension in c("png", "pdf")) {
    ggsave(
      file.path(analysis_dir, "images", paste0(endpoint, "_ipd_overlay.", extension)),
      plot = plot,
      width = 7.2,
      height = 5.2,
      dpi = 300,
      bg = "white"
    )
  }
}
writeLines(
  capture.output(sessionInfo()),
  file.path(analysis_dir, "sessions", "reconstruct_ipd_session.txt")
)
