# Auth setup

Two separate identities talk to Snowflake:

- `DBT_SVC` — my dbt builds. Key-pair auth, full read/write on STAGING + MARTS.
- `APP_SVC` — the Streamlit dashboard. Password, read-only on MARTS.

`ACCOUNTADMIN` is used for bootstrap only. Nothing day-to-day runs as it.

No password, no passphrase, and no private key is committed to this repo.

## Files and where they live

| File | Committed? |
|---|---|
| `~/.snowflake/rsa_key.p8` | No — outside repo |
| `~/.snowflake/rsa_key.pub` | No |
| `~/.dbt/profiles.yml` | No — dbt keeps it outside the project by default |
| `~/.snowflake/connections.toml` | No |
| `.streamlit/secrets.toml` | No — gitignored |
| `.streamlit/secrets.toml.example` | Yes — placeholders only |
| `sql/03_create_roles.sql` | Yes — no secrets |

## Dev: key-pair auth

### 1. Generate the key

```powershell
New-Item -ItemType Directory -Path $HOME\.snowflake -Force | Out-Null

openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out $HOME\.snowflake\rsa_key.p8
openssl rsa -in $HOME\.snowflake\rsa_key.p8 -pubout -out $HOME\.snowflake\rsa_key.pub
```

The first command prompts for a passphrase. Pick one and remember it.

### 2. Register the public key in Snowflake

```powershell
Get-Content $HOME\.snowflake\rsa_key.pub
```

Copy the base64 body (not the BEGIN/END lines). Then in Snowsight as ACCOUNTADMIN:

```sql
ALTER USER DBT_SVC SET RSA_PUBLIC_KEY = '<paste here>';
DESC USER DBT_SVC;   -- RSA_PUBLIC_KEY_FP should now be populated
```

### 3. Store the passphrase as an env var

```powershell
[System.Environment]::SetEnvironmentVariable(
    'SNOWFLAKE_PRIVATE_KEY_PASSPHRASE', '<your passphrase>', 'User'
)
```

Restart the terminal so the var is picked up.

### 4. dbt profile

`~/.dbt/profiles.yml`:

```yaml
ma_payer:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your-account-identifier>
      user: DBT_SVC
      role: MA_PAYER_DEV
      warehouse: WH_XS
      database: MA_PAYER
      schema: STAGING
      private_key_path: <path-to-your-rsa-key>.p8
      private_key_passphrase: "{{ env_var('SNOWFLAKE_PRIVATE_KEY_PASSPHRASE') }}"
      threads: 4
```

### 5. VS Code Snowflake extension

`~/.snowflake/connections.toml`:

```toml
[ma_payer_dev]
account          = "<your-account-identifier>"
user             = "DBT_SVC"
role             = "MA_PAYER_DEV"
warehouse        = "WH_XS"
database         = "MA_PAYER"
schema           = "STAGING"
authenticator    = "SNOWFLAKE_JWT"
private_key_file = "<path-to-your-rsa-key>.p8"
```

The passphrase is prompted at connect time; don't put it in this file.

### 6. Verify

```powershell
cd ma_payer
..\.venv\Scripts\dbt.exe debug
```

If you see `Could not decode private key`, the passphrase env var didn't load — restart the terminal.

## App: Streamlit viewer

### Local

```powershell
Copy-Item .streamlit\secrets.toml.example .streamlit\secrets.toml
# edit .streamlit\secrets.toml and fill in APP_SVC's password
streamlit run streamlit\app.py
```

Sanity-check that it won't get committed:

```powershell
git check-ignore .streamlit\secrets.toml
# prints the path = ignored
```

### Streamlit Cloud

Don't upload `secrets.toml`. Push the repo (private first), then in Streamlit Cloud:

1. Create the app.
2. App settings → Secrets → paste the same TOML content.
3. `st.secrets` picks it up at runtime.

### Optional hardening

- Attach a network policy to `APP_SVC` restricting to Streamlit Cloud's egress IPs.
- Rotate the password quarterly.
- Pre-aggregate dashboard queries into one summary table so `MA_PAYER_VIEWER` only needs SELECT on a single object.

## Rotation

**Rotating my dev key:**

```powershell
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out $HOME\.snowflake\rsa_key.p8
openssl rsa -in $HOME\.snowflake\rsa_key.p8 -pubout -out $HOME\.snowflake\rsa_key.pub
```

```sql
ALTER USER DBT_SVC SET RSA_PUBLIC_KEY = '<new base64 body>';
```

No config files change — they point at the file path, and the file was overwritten.

**Rotating APP_SVC password:**

```sql
ALTER USER APP_SVC SET PASSWORD = '<new password>';
```

Update `.streamlit/secrets.toml` (local) and the Streamlit Cloud Secrets UI.

## If a secret ever hits git

Assume it's compromised. The moment it lands in a commit — pushed or not — treat it as leaked.

1. Rotate the credential in Snowflake.
2. Purge from history (`git filter-repo` or BFG).
3. Force-push.
4. If the repo was already public, accept that rotation is the only real fix — history rewrites don't un-scrape what bots already pulled.

## Pre-push checklist

```powershell
git status                                          # nothing sensitive listed
git check-ignore .streamlit\secrets.toml            # path printed
git check-ignore .streamlit\secrets.toml.example    # empty = will commit
git grep -iE "password\s*=\s*['\"][^'\"<>]{8,}"     # only the .example placeholder
```

If those four look right, it's safe to push.
