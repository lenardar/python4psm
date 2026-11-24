library(heemod)

os_survival <- function(t, lambda, shape, delta) {
  pgamma(lambda * t^delta, shape = shape, lower.tail = FALSE)
}

survival_table <- function(mu, sigma, lambda, shape, delta, endpoint) {
  time <- 0:n_cycles
  months <- time * cycle_years * 12
  os <- os_survival(months, lambda, shape, delta)
  pfs <- 1 / (1 + (months / exp(mu))^(1 / sigma))
  define_surv_table(data.frame(
    time = time,
    survival = if (endpoint == "pfs") pmin(pfs, os) else os
  ))
}

build_model <- function() {
  inputs <- lapply(base_inputs, rlang::new_quosure, env = environment())
  derived <- define_parameters(
    pfs_mu = dispatch_strategy(ICC = icc_pfs_llogis_mu, Dato = dato_pfs_llogis_mu),
    pfs_sigma = dispatch_strategy(ICC = icc_pfs_llogis_sigma, Dato = dato_pfs_llogis_sigma),
    os_lambda = dispatch_strategy(ICC = icc_os_gg_lambda, Dato = dato_os_gg_lambda),
    os_shape = dispatch_strategy(ICC = icc_os_gg_shape, Dato = dato_os_gg_shape),
    os_delta = dispatch_strategy(ICC = icc_os_gg_delta, Dato = dato_os_gg_delta),
    pfs_cost = dispatch_strategy(
      ICC = cost_icc_pfs + cost_admin + cost_port + cost_monitoring,
      Dato = cost_dato_pfs + cost_admin + cost_monitoring
    ),
    pd_cost = dispatch_strategy(ICC = cost_icc_pd, Dato = cost_dato_pd),
    pfs_utility = dispatch_strategy(ICC = u_icc_pfs, Dato = u_dato_pfs),
    pd_utility = dispatch_strategy(ICC = u_icc_pd, Dato = u_dato_pd),
    new_deaths = os_survival((model_time - 1) * cycle_years * 12, os_lambda, os_shape, os_delta) -
      os_survival(model_time * cycle_years * 12, os_lambda, os_shape, os_delta),
    terminal_cost = cost_terminal * new_deaths,
    discount_factor_cost = (1 + discount_cost)^(-cycle_years * (model_time - 1)),
    discount_factor_qaly = (1 + discount_qaly)^(-cycle_years * (model_time - 1))
  )
  for (arm in c("icc", "dato")) {
    for (kind in c("cost", "loss")) {
      terms <- vapply(ae_names, function(ae) {
        rate <- paste0("ae_", arm, "_", ae)
        if (kind == "cost") {
          paste0(rate, " * ae_cost_", ae)
        } else {
          paste0(rate, " * disutility_", ae, " * duration_", ae, " / 365")
        }
      }, character(1))
      derived[[paste0(arm, "_ae_", kind)]] <- rlang::new_quosure(
        str2lang(paste(terms, collapse = " + ")),
        env = environment()
      )
    }
  }
  derived <- c(derived, define_parameters(
    ae_cost = dispatch_strategy(ICC = icc_ae_cost, Dato = dato_ae_cost),
    ae_loss = ae_enabled * dispatch_strategy(ICC = icc_ae_loss, Dato = dato_ae_loss)
  ))
  parameters <- define_parameters_(c(inputs, derived))
  transition <- define_part_surv(
    pfs = survival_table(pfs_mu, pfs_sigma, os_lambda, os_shape, os_delta, "pfs"),
    os = survival_table(pfs_mu, pfs_sigma, os_lambda, os_shape, os_delta, "os"),
    state_names = c(progression_free = "PFS", progression = "PD", death = "Dead")
  )

  pfs <- define_state(
    cost = (pfs_cost + terminal_cost) * discount_factor_cost,
    qaly = pfs_utility * cycle_years * discount_factor_qaly
  )
  pd <- define_state(
    cost = (pd_cost + terminal_cost) * discount_factor_cost,
    qaly = pd_utility * cycle_years * discount_factor_qaly
  )
  dead <- define_state(cost = terminal_cost * discount_factor_cost, qaly = 0)
  strategy <- define_strategy(
    transition = transition, PFS = pfs, PD = pd, Dead = dead,
    starting_values = define_starting_values(cost = ae_cost, qaly = -ae_loss)
  )
  run_model(
    ICC = strategy, Dato = strategy, parameters = parameters,
    cycles = n_cycles, init = c(1, 0, 0), method = "life-table", cost = cost, effect = qaly
  )
}
