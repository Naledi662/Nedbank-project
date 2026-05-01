[README.md](https://github.com/user-attachments/files/27275479/README.md)
# Nedbank DE Challenge — Pipeline

Medallion pipeline: accounts/customers/transactions → Bronze → Silver → Gold (Delta Parquet).

## Structure

```
pipeline/
  ingest.py       Bronze layer
  transform.py    Silver layer
  provision.py    Gold layer
  utils.py        SparkSession, config, DQ rules loading
  run_all.py      Entry point
config/
  pipeline_config.yaml
  dq_rules.yaml
Dockerfile
```

## Running

```bash
docker build -t candidate-submission:latest .

docker run \
  -v /path/to/data:/data \
  -m 4g --cpus="2" \
  candidate-submission:latest
```

Data must be mounted at `/data/input/` with `accounts.csv`, `customers.csv`, `transactions.jsonl`.

## Gold layer output

| Table | Fields | Notes |
|-------|--------|-------|
| `fact_transactions` | 15 | transaction_sk, account_sk, customer_sk + 12 measures |
| `dim_accounts` | 11 | customer_ref renamed to customer_id (GAP-026) |
| `dim_customers` | 9 | age_band derived from dob |

## Validation queries

All three pass on Stage 1 data:

- **Q1** - 4 transaction types, 1,000,000 total records 
- **Q2** - 0 unlinked accounts (zero tolerance) 
- **Q3** - 9 SA provinces in dim_customers 

## Design notes

**No .count() calls** - all pre-write row counts removed. Each triggers a full dataset scan.

**SparkSession reused** - created once in ingest, passed through to silver and gold. Saves ~60s of JVM startup on a 30-minute time limit.

**Broadcast joins** - dim_accounts (~100k rows) and dim_customers (~80k rows) are both broadcast in fact_transactions. Also used for orphan detection in silver. Eliminates shuffle on the 1M-row transactions table.

**Silver accounts cached** - written and cached, then passed directly into transactions for orphan detection. No second disk read, no timing risk.

**Deterministic surrogate keys** - sha2(natural_key, 256) → first 15 hex chars → BIGINT. Same input always produces the same SK.

**Multi-format date parsing** - coalesce(ISO, DD/MM/YYYY, Unix epoch) in one Spark expression. No UDFs.

**YAML-driven DQ rules** - all 6 rule codes, priorities, and currency variants live in `config/dq_rules.yaml`. Adding a new variant or rule requires no code changes.

**Schema-drift tolerant** — unknown columns pass through silver. location/metadata struct flattening is column-existence guarded. merchant_subcategory absence (Stage 1) handled without breaking the schema.

## AI usage

Built with AI assistance. All code reviewed and understood.
