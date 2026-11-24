from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AE = ["anaemia", "diarrhoea", "fatigue", "ast", "leukopenia", "nausea",
      "neuropathy", "neutropenia", "stomatitis", "vomiting"]

CONFIG = dict(
    cycle_weeks=3, years=15, wtp=100000, ae_enabled=0,
    medical=1, nonmedical=0, indirect=0,
    ceac_max=300000, ceac_step=5000,
    distributions={
        "icc": {"pfs": "Log logistic", "os": "Gen Gamma"},
        "dato": {"pfs": "Log logistic", "os": "Gen Gamma"},
    },
)

REFERENCE_RESULTS = {
    "icc": {"cost": 185641.6488604935, "qaly": 1.172999346412249},
    "dato": {"cost": 371675.53369382396, "qaly": 1.2098500075757834},
}

SURVIVAL = {
    "icc_pfs_llogis_mu": 1.51735699152412,
    "icc_pfs_llogis_sigma": 0.547756589899163,
    "icc_os_gg_lambda": 0.00225567920760335,
    "icc_os_gg_shape": 0.789064131606602,
    "icc_os_gg_delta": 1.82308946127946,
    "dato_pfs_llogis_mu": 1.88915832024179,
    "dato_pfs_llogis_sigma": 0.585393857185278,
    "dato_os_gg_lambda": 0.0397320439199588,
    "dato_os_gg_shape": 1.91051253766843,
    "dato_os_gg_delta": 1.25017720796383,
}

UTILITIES = {"u_dato_pfs": 0.760, "u_icc_pfs": 0.736,
             "u_dato_pd": 0.650, "u_icc_pd": 0.650}

COSTS = {
    "cost_dato_pfs": 20514.753600000004,
    "cost_icc_pfs": 1841.9962399999997,
    "cost_admin": 268.88,
    "cost_port": 55.383041095890405,
    "cost_monitoring": 104.83,
    "cost_dato_pd": 2157.1971996899997,
    "cost_icc_pd": 6444.965011359,
    "cost_terminal": 27600.25,
}

AE_RAW_DATO = [0.014, 0, 0.019, 0.006, 0.006, 0.014, 0.003, 0.011, 0.064, 0.011]
AE_RAW_ICC = [0.026, 0.011, 0.020, 0.006, 0.074, 0.006, 0.009, 0.311, 0.026, 0.006]
AE_THRESHOLD = 0.02
DISUTILITIES = [0.010, 0.006, 0.115, 0.050, 0.003, 0.021, 0.014, 0.007, 0.151, 0.050]
DURATIONS_DAYS = [42.9, 17, 58.3, 28, 42.2, 36.2, 40.1, 40.1, 10, 13.7]
AE_COSTS = [26872.78, 21898.80, 15357.97, 9810.01, 22788.81,
            25653.82, 37676.27, 22788.81, 24075.41, 22414.76]


def parameters():
    records = {}

    def add(name, base, dist=None, low=None, high=None):
        records[name] = dict(base=base, dist=dist,
            low=base * 0.9 if low is None else low,
            high=base * 1.1 if high is None else high,
            sd=abs(base) * 0.1)

    add("discount_cost", 0.03, "Beta", 0, 0.05)
    add("discount_qaly", 0.03, "Beta", 0, 0.05)
    for name, value in SURVIVAL.items():
        add(name, value, "Lognormal")
    for name, value in UTILITIES.items():
        add(name, value, "Beta")
    for name, value in COSTS.items():
        add(name, value, "Gamma")
    for i, ae in enumerate(AE):
        add(f"ae_dato_{ae}", AE_RAW_DATO[i] if AE_RAW_DATO[i] > AE_THRESHOLD else 0)
        add(f"ae_icc_{ae}", AE_RAW_ICC[i] if AE_RAW_ICC[i] > AE_THRESHOLD else 0)
        add(f"disutility_{ae}", DISUTILITIES[i])
        add(f"duration_{ae}", DURATIONS_DAYS[i])
        add(f"ae_cost_{ae}", AE_COSTS[i], "Gamma")
    return records, CONFIG
