# MA Payer Platform

30-day all-cause readmission on CMS DE-SynPUF synthetic Medicare claims. Snowflake + dbt + Streamlit.

Nancy Tanaka · [live demo pending]

## Numbers

Computed on SynPUF Sample 1 (2008–2010):

| | |
|---|---|
| Index admissions | 66,705 |
| Excluded (transfers + overlaps) | 2,097 |
| Eligible denominator | 64,608 |
| 30-day readmissions | 6,420 |
| **30-day all-cause readmit rate** | **9.94%** |
| Average days to readmit | 14.1 |

SynPUF rates run well below real Medicare FFS (~18%) because the data was synthesized with simplified care patterns. The measure logic itself is portable to real payer data.

## Pipeline

```
CMS DE-SynPUF CSVs  →  Snowflake RAW_SYNPUF  →  dbt STAGING (views)  →  dbt MARTS (tables)  →  Streamlit
```

- **RAW_SYNPUF** — CSVs loaded with `PUT` + `COPY INTO`, schema inferred from headers
- **STAGING** — column rename, YYYYMMDD → DATE casts, CCW chronic flags to booleans
- **MARTS** — `dim_beneficiary`, `fct_admission`, `fct_readmission_30d`

## Stack

Python 3.11 · Snowflake (XS warehouse) · dbt Core 1.8 + dbt_utils · Streamlit + Plotly

Source data: CMS DE-SynPUF Sample 1 — 8 CSVs, ~400 MB, 11.5M rows.

## Things worth knowing

**Multi-segment inpatient claims.** A `unique(claim_id)` test failed on 68 claims that had separate revenue-code rows in the CSV. Grain is `(claim_id, segment)` in staging; `fct_admission` collapses back to one row per claim.

**Transfers and overlaps excluded.** 2,097 admission pairs had a next admission starting on or before the index discharge — interfacility transfers and interrupted stays. HEDIS convention treats these as a single episode, not a readmission.

**30-day window is from discharge, not admission.** Numerator: next admission on days 1–30 after discharge.

**Custom `generate_schema_name` macro.** Default dbt prepends `{target}_` to the schema, which would put marts in `STAGING_MARTS`. The macro strips that so `+schema: MARTS` lands in `MARTS`.

## Run it

Requires Snowflake trial, Python 3.11.

```bash
git clone https://github.com/nancytanaka1/ma-payer-platform
cd ma-payer-platform
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
```

Download SynPUF Sample 1 from CMS, extract to `E:\data\synpuf\sample_01\csv\`.

Auth setup (key-pair for dev, service account for the app) is in [docs/auth-setup.md](docs/auth-setup.md).
Full teardown + rebuild procedure is in [docs/rebuild-from-scratch.md](docs/rebuild-from-scratch.md).

```bash
# load raw (run in order)
snowsql -f sql/01_setup_and_stage.sql
snowsql -f sql/02_load_raw.sql

# build models
cd ma_payer && dbt deps && dbt build

# dashboard
streamlit run streamlit/app.py
```

## Caveats

- SynPUF is synthetic. Distributions mirror real FFS claims but individual beneficiary histories are fabricated.
- ICD-9 only — data predates the ICD-10 transition.
- FFS data, not MA. Measure logic transfers but MA-specific tables (encounters, capitation) aren't here.
- No planned-admission exclusion. Full HEDIS PCR excludes planned readmits via CPT/HCPCS; this is a simpler proxy.

## License

Apache 2.0 · see [LICENSE](LICENSE).

## Contact

nancytanaka1@gmail.com
