library(flexsurv)

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
stopifnot(length(script_arg) == 1L)
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg)))
root <- dirname(dirname(script_dir))
analysis_dir <- file.path(root, "output", "survival_analysis")
dir.create(file.path(analysis_dir, "parameters"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(analysis_dir, "sessions"), recursive = TRUE, showWarnings = FALSE)
distributions <- c(
  Exponential = "exp", Weibull = "weibull", Gompertz = "gompertz",
  "Log logistic" = "llogis", "Log normal" = "lnorm",
  "Generalized Gamma" = "gengamma"
)
all_models <- list()
metrics <- list()
native <- list()
conversion_checks <- list()

for (curve in c("pfs_dato", "pfs_icc", "os_dato", "os_icc")) {
  ipd <- read.csv(file.path(analysis_dir, "data", paste0(curve, "_ipd.csv")))
  stopifnot(all(is.finite(ipd$time)), all(ipd$time > 0), all(ipd$status %in% 0:1))
  excel_rows <- list()
  for (label in names(distributions)) {
    dist <- distributions[[label]]
    fit <- flexsurvreg(
      Surv(time, status) ~ 1,
      data = ipd,
      dist = dist,
      control = list(maxit = 10000, reltol = 1e-10)
    )
    stopifnot(
      fit$opt$convergence == 0,
      all(is.finite(fit$res[, "est"])),
      all(is.finite(fit$cov)),
      min(eigen(fit$cov, symmetric = TRUE, only.values = TRUE)$values) > 0
    )
    p <- setNames(fit$res[, "est"], rownames(fit$res))
    compatible <- TRUE
    formula <- switch(
      dist,
      exp = "EXP(-lambda*t)",
      weibull = "EXP(-lambda*t^gamma)",
      gompertz = "EXP(-lambda*(EXP(gamma*t)-1)/gamma)",
      llogis = "1/(1+(t/EXP(lambda))^(1/gamma))",
      lnorm = "1-NORM.S.DIST((LN(t)-lambda)/gamma,TRUE)",
      gengamma = "1-GAMMA.DIST(lambda*t^delta,gamma,1,TRUE)"
    )
    converted <- switch(
      dist,
      exp = c(lambda = unname(p["rate"])),
      weibull = c(lambda = unname(p["scale"]^(-p["shape"])), gamma = unname(p["shape"])),
      gompertz = c(lambda = unname(p["rate"]), gamma = unname(p["shape"])),
      llogis = c(lambda = unname(log(p["scale"])), gamma = unname(1/p["shape"])),
      lnorm = c(lambda = unname(p["meanlog"]), gamma = unname(p["sdlog"])),
      gengamma = {
        stopifnot(abs(p["Q"]) > 1e-8)
        delta <- unname(p["Q"]/p["sigma"])
        if (p["Q"] < 0) {
          compatible <- FALSE
          formula <- "GAMMA.DIST(lambda*t^delta,gamma,1,TRUE)"
        }
        c(lambda = unname(exp(-p["mu"]*delta)/p["Q"]^2),
          gamma = unname(1/p["Q"]^2), delta = delta)
      }
    )
    times <- c(0.001, 0.1, seq(1, 180, length.out = 300))
    a <- converted["lambda"]
    b <- converted["gamma"]
    cpar <- converted["delta"]
    mapped <- switch(
      dist,
      exp = exp(-a*times),
      weibull = exp(-a*times^b),
      gompertz = if (abs(b) < 1e-12) exp(-a*times) else exp(-a*expm1(b*times)/b),
      llogis = 1/(1+(times/exp(a))^(1/b)),
      lnorm = pnorm(log(times), mean = a, sd = b, lower.tail = FALSE),
      gengamma = pgamma(a*times^cpar, shape = b, lower.tail = !compatible)
    )
    predicted <- summary(fit, t = times, type = "survival", ci = FALSE)[[1]]$est
    message(curve, " / ", dist)
    max_error <- max(abs(mapped - predicted))
    stopifnot(is.finite(max_error), max_error < 1e-8)
    key <- paste(curve, dist, sep = ":")
    all_models[[key]] <- fit
    k <- length(p)
    n <- nrow(ipd)
    aic <- AIC(fit)
    bic <- BIC(fit)
    stopifnot(abs(aic - (2*k - 2*fit$loglik)) < 1e-7,
              abs(bic - (log(n)*k - 2*fit$loglik)) < 1e-7)
    metrics[[key]] <- data.frame(
      curve = curve, distribution = label, flexsurv_dist = dist,
      n = n, events = sum(ipd$status), parameters = k,
      logLik = fit$loglik, AIC = aic, BIC = bic,
      convergence = fit$opt$convergence,
      excel_formula_compatible = compatible,
      survival_formula = formula
    )
    native[[key]] <- data.frame(
      curve = curve, distribution = label, parameter = names(p),
      estimate = unname(p), lower_95 = fit$res[, "L95%"],
      upper_95 = fit$res[, "U95%"], se = fit$res[, "se"]
    )
    conversion_checks[[key]] <- data.frame(curve = curve, distribution = label,
                                          max_survival_difference = max_error)
    excel_rows[[label]] <- data.frame(
      distribution = c(label, rep("", length(converted)-1)),
      parameter = c(lambda = "Lambda (λ)", gamma = "Gamma (γ)", delta = "Delta (δ)")[names(converted)],
      estimate = unname(converted),
      AIC = c(aic, rep(NA_real_, length(converted)-1)),
      BIC = c(bic, rep(NA_real_, length(converted)-1)),
      excel_formula_compatible = compatible,
      note = if (compatible) "" else "For Q < 0 use the lower-tail gamma CDF to calculate survival."
    )
  }
  write.csv(
    do.call(rbind, excel_rows),
    file.path(analysis_dir, "parameters", paste0(curve, "_excel_parameters.csv")),
    row.names = FALSE, na = "", fileEncoding = "UTF-8"
  )
}
metrics <- do.call(rbind, metrics)
metrics$AIC_rank <- ave(metrics$AIC, metrics$curve, FUN = function(x) rank(x, ties.method = "min"))
metrics$BIC_rank <- ave(metrics$BIC, metrics$curve, FUN = function(x) rank(x, ties.method = "min"))
metrics$delta_AIC <- metrics$AIC - ave(metrics$AIC, metrics$curve, FUN = min)
metrics$delta_BIC <- metrics$BIC - ave(metrics$BIC, metrics$curve, FUN = min)
write.csv(metrics, file.path(analysis_dir, "parameters", "model_comparison.csv"), row.names = FALSE)
write.csv(do.call(rbind, native), file.path(analysis_dir, "parameters", "flexsurv_parameters.csv"), row.names = FALSE)
write.csv(do.call(rbind, conversion_checks), file.path(analysis_dir, "parameters", "parameter_conversion_check.csv"), row.names = FALSE)
saveRDS(all_models, file.path(analysis_dir, "parameters", "flexsurv_models.rds"))
writeLines(capture.output(sessionInfo()), file.path(analysis_dir, "sessions", "fit_survival_session.txt"))
print(metrics[, c("curve", "distribution", "AIC", "BIC", "AIC_rank", "BIC_rank", "excel_formula_compatible")], row.names = FALSE)
