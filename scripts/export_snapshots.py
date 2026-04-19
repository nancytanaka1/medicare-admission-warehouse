"""Export aggregate query results as CSV snapshots for static Streamlit deployment.

Run this locally whenever dbt marts change:
    python scripts/export_snapshots.py

Writes three files into streamlit/data/:
    - headline.csv
    - chronic.csv
    - monthly.csv

Reads Snowflake credentials from .streamlit/secrets.toml.
Requires snowflake-snowpark-python (in requirements-dev.txt, not runtime requirements.txt).
"""
from __future__ import annotations

import sys
import tomllib
from pathlib import Path

from snowflake.snowpark import Session

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "streamlit" / "data"
SECRETS = ROOT / ".streamlit" / "secrets.toml"

HEADLINE = """
SELECT
    COUNT(*)::FLOAT AS total_admissions,
    SUM(IFF(is_transfer_or_overlap, 1, 0))::FLOAT AS transfers,
    SUM(IFF(NOT is_transfer_or_overlap, 1, 0))::FLOAT AS eligible,
    SUM(IFF(is_30d_readmit, 1, 0))::FLOAT AS readmissions,
    (SUM(IFF(is_30d_readmit, 1, 0)) * 100.0
     / NULLIF(SUM(IFF(NOT is_transfer_or_overlap, 1, 0)), 0))::FLOAT AS readmit_rate_pct,
    AVG(CASE WHEN is_30d_readmit THEN days_to_readmit END)::FLOAT AS avg_days_readmit
FROM MA_PAYER.MARTS.FCT_READMISSION_30D
"""

CHRONIC = """
WITH j AS (
    SELECT r.is_30d_readmit, d.has_chf, d.has_copd, d.has_diabetes, d.has_ckd,
           d.has_ischemic_heart, d.has_stroke_tia
    FROM MA_PAYER.MARTS.FCT_READMISSION_30D r
    JOIN MA_PAYER.MARTS.DIM_BENEFICIARY d USING (beneficiary_id)
    WHERE NOT r.is_transfer_or_overlap
)
SELECT 'CHF' AS cohort, SUM(IFF(has_chf, 1, 0))::FLOAT AS admissions,
       (SUM(IFF(has_chf AND is_30d_readmit, 1, 0)) * 100.0
        / NULLIF(SUM(IFF(has_chf, 1, 0)), 0))::FLOAT AS rate FROM j
UNION ALL SELECT 'COPD', SUM(IFF(has_copd, 1, 0))::FLOAT,
       (SUM(IFF(has_copd AND is_30d_readmit, 1, 0)) * 100.0
        / NULLIF(SUM(IFF(has_copd, 1, 0)), 0))::FLOAT FROM j
UNION ALL SELECT 'Diabetes', SUM(IFF(has_diabetes, 1, 0))::FLOAT,
       (SUM(IFF(has_diabetes AND is_30d_readmit, 1, 0)) * 100.0
        / NULLIF(SUM(IFF(has_diabetes, 1, 0)), 0))::FLOAT FROM j
UNION ALL SELECT 'CKD', SUM(IFF(has_ckd, 1, 0))::FLOAT,
       (SUM(IFF(has_ckd AND is_30d_readmit, 1, 0)) * 100.0
        / NULLIF(SUM(IFF(has_ckd, 1, 0)), 0))::FLOAT FROM j
UNION ALL SELECT 'Ischemic Heart', SUM(IFF(has_ischemic_heart, 1, 0))::FLOAT,
       (SUM(IFF(has_ischemic_heart AND is_30d_readmit, 1, 0)) * 100.0
        / NULLIF(SUM(IFF(has_ischemic_heart, 1, 0)), 0))::FLOAT FROM j
UNION ALL SELECT 'Stroke/TIA', SUM(IFF(has_stroke_tia, 1, 0))::FLOAT,
       (SUM(IFF(has_stroke_tia AND is_30d_readmit, 1, 0)) * 100.0
        / NULLIF(SUM(IFF(has_stroke_tia, 1, 0)), 0))::FLOAT FROM j
ORDER BY rate DESC
"""

MONTHLY = """
SELECT
    DATE_TRUNC('month', index_admission_date) AS month,
    COUNT(*)::FLOAT AS admissions,
    SUM(IFF(is_30d_readmit, 1, 0))::FLOAT AS readmissions,
    (SUM(IFF(is_30d_readmit, 1, 0)) * 100.0
     / NULLIF(COUNT(*), 0))::FLOAT AS readmit_rate_pct
FROM MA_PAYER.MARTS.FCT_READMISSION_30D
WHERE NOT is_transfer_or_overlap
  AND index_admission_date IS NOT NULL
GROUP BY 1
ORDER BY 1
"""


def main() -> int:
    if not SECRETS.exists():
        print(f"ERROR: {SECRETS} not found.", file=sys.stderr)
        return 1

    with SECRETS.open("rb") as f:
        cfg = tomllib.load(f)["connections"]["snowflake"]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    session = Session.builder.configs(cfg).create()

    for name, sql in (("headline", HEADLINE), ("chronic", CHRONIC), ("monthly", MONTHLY)):
        df = session.sql(sql).to_pandas()
        out = OUT_DIR / f"{name}.csv"
        df.to_csv(out, index=False)
        print(f"Wrote {out}: {len(df)} rows")

    session.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
