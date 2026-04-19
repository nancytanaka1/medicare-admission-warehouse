# Rebuild from scratch

Full teardown + rebuild to verify the pipeline is still reproducible. ~15-20 min, most of it re-uploading CSVs.

Run these phases in order. If any phase fails, stop and fix before moving on.

## 1. Pre-flight

Source data still on disk:

```powershell
ls E:\data\synpuf\sample_01\csv\
```

Should list 8 `.csv` files. If missing, re-download from CMS before continuing.

SnowSQL CLI installed:

```powershell
if (Get-Command snowsql -ErrorAction SilentlyContinue) {
    snowsql --version
} else {
    winget install Snowflake.SnowSQL --accept-source-agreements --accept-package-agreements
}
```

If winget just installed it, open a new PowerShell window so PATH picks it up.

## 2. Snowflake teardown

```powershell
snowsql -a <your-account-identifier> -u <your-username> -f sql\00_teardown.sql
```

Enter password when prompted. The three `SHOW` checks at the end of the script should all return 0 rows.

## 3. Local cleanup

From the repo root:

```powershell
Remove-Item -Recurse -Force ma_payer\target, ma_payer\dbt_packages, ma_payer\logs -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .venv -ErrorAction SilentlyContinue

Test-Path ma_payer\target, ma_payer\dbt_packages, .venv
```

All three should print `False`. Deleting `.venv` is deliberate — it proves `requirements-dev.txt` is complete.

## 4. Rebuild Python env

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt

dbt --version         # dbt-core 1.8.9, snowflake 1.8.4
streamlit --version   # 1.39.x
```

## 5. Reload raw data

```powershell
snowsql -a <your-account-identifier> -u <your-username> -f sql\01_setup_and_stage.sql
snowsql -a <your-account-identifier> -u <your-username> -f sql\02_load_raw.sql
```

Row-count check at the end of `02`:

| table | expected |
|---|---|
| BENEFICIARY_2008 | 116,352 |
| BENEFICIARY_2009 | 114,538 |
| BENEFICIARY_2010 | 112,137 |
| INPATIENT_CLAIMS | 66,773 |
| OUTPATIENT_CLAIMS | 790,790 |
| CARRIER_CLAIMS | 5,209,572 |
| PRESCRIPTION_DRUG_EVENTS | 3,418,797 |

If any row count doesn't match, stop and investigate before building dbt.

## 6. dbt build

```powershell
cd ma_payer
dbt deps
dbt build
cd ..
```

Last line should read:

```
Completed successfully
Done. PASS=<N> WARN=0 ERROR=0 SKIP=0 TOTAL=<N>
```

Any `ERROR` or `FAIL` — stop, do not proceed to Streamlit.

## 7. Streamlit

```powershell
streamlit run streamlit\app.py
```

Browser opens at `localhost:8501`. Expected KPI values:

- Index Admissions: **64,608**
- 30-Day Readmissions: **6,420**
- Readmit Rate: **9.94%**
- Avg Days to Readmit: **14.1**

If those four match, the pipeline is fully reproducible.

## Avoiding the password prompt

Each `snowsql` call above prompts for a password. To skip the prompt, set it once per shell session:

```powershell
$env:SNOWSQL_PWD = "<your password>"
```

Or configure a named connection in `~/.snowsql/config` and use `snowsql -c ma_payer_dev -f <script>` instead — see the SnowSQL docs.

## Gotcha

dbt's custom `generate_schema_name` macro depends on the `STAGING` and `MARTS` schemas already existing — those are created by `01_setup_and_stage.sql`. Skipping that script will cause `dbt build` to fail on the first `CREATE VIEW`. Phase 5 handles this, but worth knowing if you ever shortcut.
