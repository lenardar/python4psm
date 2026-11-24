args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
here <- file.path(dirname(dirname(dirname(normalizePath(script)))), "scripts/models/r")
source(file.path(here, "parameters.R"))
source(file.path(here, "model.R"))
target <- args[1]
trial <- as.integer(args[2])
n_psa <- as.integer(args[3])
seed <- 20261031 + trial
warm <- build_model()
rm(warm)
gc()
start <- proc.time()[["elapsed"]]
model <- build_model()
base_seconds <- proc.time()[["elapsed"]] - start

dsa_args <- list()
for (name in names(base_inputs)[base_inputs != 0]) {
  value <- base_inputs[[name]]
  bounds <- if (startsWith(name, "discount_")) c(0, 0.05) else value * c(0.9, 1.1)
  dsa_args <- c(dsa_args, list(as.name(name), bounds[1], bounds[2]))
}
dsa_spec <- do.call(define_dsa, dsa_args)
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
psa_spec <- define_psa_(distributions)
gc()
start <- proc.time()[["elapsed"]]
dsa <- run_dsa(model, dsa_spec)
owsa_seconds <- proc.time()[["elapsed"]] - start
gc()
set.seed(seed)
start <- proc.time()[["elapsed"]]
psa <- run_psa(model, psa_spec, N = n_psa)
psa_seconds <- proc.time()[["elapsed"]] - start
stopifnot(nrow(psa$psa) == 2 * n_psa)
stopifnot(length(unique(dsa$dsa$.par_names)) == length(dsa_args) / 3)
write.csv(
  data.frame(
    engine = "heemod", trial = trial, task = c("base", "owsa", "psa"),
    seconds = c(base_seconds, owsa_seconds, psa_seconds),
    psa_draws = n_psa, owsa_parameters = length(dsa_args) / 3, seed = seed
  ),
  target, row.names = FALSE
)
