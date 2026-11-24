args <- commandArgs(trailingOnly = TRUE)
source(file.path(args[1], "scripts/models/r", "parameters.R"))
source(file.path(args[1], "scripts/models/r", "model.R"))
original <- base_inputs

totals <- function() {
  values <- get_values(build_model())
  xtabs(value ~ .strategy_names + value_names, values)
}

baseline <- totals()
base_inputs["cost_terminal"] <- 0
terminal <- baseline[, "cost"] - totals()[, "cost"]
base_inputs <- original
base_inputs[startsWith(names(original), "u_")] <- 1
qaly <- totals()[, "qaly"]

base_inputs <- original
base_inputs[c("discount_cost", "discount_qaly")] <- 0
undiscounted <- totals()

base_inputs <- original
dato <- grep("dato", names(original), value = TRUE)
base_inputs[dato] <- original[sub("dato", "icc", dato)]
base_inputs["cost_port"] <- 0
matched <- totals()
delta <- matched["Dato", ] - matched["ICC", ]

base_inputs <- original
base_inputs[grepl("^(cost_|ae_cost_)", names(original))] <- 0
zero <- totals()[, "cost"]

base_inputs <- original
base_inputs["discount_qaly"] <- 0
base_inputs[startsWith(names(original), "u_")] <- 1
survival_table <- function(mu, sigma, lambda, shape, delta, endpoint) {
  define_surv_table(data.frame(time = 0:n_cycles, survival = 1))
}
os_survival <- function(t, lambda, shape, delta) rep(1, length(t))
years <- totals()[, "qaly"]
write.csv(data.frame(arm = names(qaly), qaly, terminal,
  no_dr_cost = undiscounted[, "cost"], no_dr_qaly = undiscounted[, "qaly"],
  zero, years, delta_cost = unname(delta["cost"]), delta_qaly = unname(delta["qaly"])),
  args[2], row.names = FALSE)
