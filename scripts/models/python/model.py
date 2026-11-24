import math
import pyheor as ph
from parameters import AE, parameters


def survival_curve(p, prefix, distribution):
    def value(suffix):
        return p[f"{prefix}_{suffix}"]
    if distribution == "Log logistic":
        return ph.LogLogistic(shape=1 / value("llogis_sigma"), scale=math.exp(value("llogis_mu")))
    if distribution in ("Gen Gamma", "Generalized Gamma"):
        a, b, d = value("gg_lambda"), value("gg_shape"), value("gg_delta")
        q = math.copysign(1 / math.sqrt(b), d)
        return ph.GeneralizedGamma(mu=math.log(b / a) / d, sigma=q / d, Q=q)
    raise ValueError(f"Unknown distribution: {distribution}")


def effective_cycle_rate(annual_rate, cycle_years):
    return (1 + annual_rate) ** cycle_years - 1


def build_model(*, cycle_rate=effective_cycle_rate, use_terminal_state=False):
    records, config = parameters()
    cycle = ph.Cycle(config["cycle_weeks"], "week")
    model = ph.PSMModel(
        states=["PFS", "PD", "Terminal", "Dead"] if use_terminal_state else ["PFS", "PD", "Dead"],
        terminal_state="Terminal" if use_terminal_state else None,
        survival_endpoints=["PFS", "OS"],
        strategies={"icc": "ICC", "dato": "Dato"},
        n_cycles=round(config["years"] / cycle.years), cycle=cycle,
        dr_cost=lambda p: cycle_rate(p["discount_cost"], cycle.years),
        dr_qaly=lambda p: cycle_rate(p["discount_qaly"], cycle.years),
        method="life-table",
    )
    for name, x in records.items():
        distribution = None
        if x["base"] > 0 and x["dist"] == "Beta":
            distribution = ph.Beta(mean=x["base"], sd=x["sd"])
        elif x["base"] > 0 and x["dist"] == "Gamma":
            distribution = ph.Gamma(mean=x["base"], sd=x["sd"])
        elif x["dist"] == "Lognormal" and x["base"] > 0:
            distribution = ph.LogNormal(meanlog=math.log(x["base"]), sdlog=math.log(1.2 / 0.8) / 3.92)
        model.add_param(name, x["base"], dist=distribution,
                        low=x["low"], high=x["high"], label=name)
    for arm in ("icc", "dato"):
        for endpoint in ("pfs", "os"):
            prefix, dist = f"{arm}_{endpoint}", config["distributions"][arm][endpoint]
            model.set_survival(arm, endpoint.upper(),
                lambda p, prefix=prefix, dist=dist: ph.rescale_survival(
                    survival_curve(p, prefix, dist), from_unit="month", to_period=cycle))

    med = config["medical"]
    def amount(name, multiplier=1):
        return lambda p, t: multiplier * p[name]

    def ae_cost(arm):
        return lambda p, t: med * sum(p[f"ae_{arm}_{ae}"] * p[f"ae_cost_{ae}"] for ae in AE)

    def ae_qaly(arm):
        return lambda p, t: -config["ae_enabled"] * sum(
            p[f"ae_{arm}_{ae}"] * p[f"disutility_{ae}"] * p[f"duration_{ae}"] / 365 for ae in AE)

    model.set_state_cost("PFS drug", {
        arm: {"PFS": amount(f"cost_{arm}_pfs", med)}
        for arm in ("icc", "dato")})
    model.set_state_cost("PFS administration", {
        "icc": {"PFS": lambda p, t: med * (p["cost_admin"] + p["cost_port"])},
        "dato": {"PFS": lambda p, t: med * p["cost_admin"]}})
    model.set_state_cost("PFS monitoring", {"PFS": lambda p, t: med * p["cost_monitoring"]})
    model.set_state_cost("PD treatment", {
        arm: {"PD": amount(f"cost_{arm}_pd", med)}
        for arm in ("icc", "dato")})
    if use_terminal_state:
        model.set_state_cost("Terminal", {"Terminal": amount("cost_terminal", med)})
    else:
        model.set_custom_cost("Terminal", lambda ctx: med * ctx.params["cost_terminal"] *
                              (ctx.state_curr[2] - ctx.state_prev[2]))
    for arm in ("icc", "dato"):
        model.set_starting_cost(f"AE {arm}", {arm: ae_cost(arm)})
        model.set_starting_qaly(f"AE {arm}", {arm: ae_qaly(arm)})
    model.set_state_qaly("Health", {
        arm: {state.upper(): amount(f"u_{arm}_{state}", cycle.years)
              for state in ("pfs", "pd")}
        for arm in ("icc", "dato")})
    return model, records, config
