# Beezap Real-Time Analytics Pipeline

CDC-based analytics pipeline for the Beezap multi-tenant WhatsApp blasting
platform.

```
 Server A (existing)        Server B (existing)        New Ubuntu server (this repo)
┌───────────────────┐      ┌──────────────────┐      ┌─────────────────────────────────┐
│ PostgreSQL OLTP    │ CDC  │ Apache Kafka      │ cdc.*│ Kafka Connect + Debezium        │
│ xx.xx.x.93:5432    │─────▶│ xx.xx.8.60:9092   │─────▶│   ──▶ ClickHouse ──▶ Superset    │
│ public.tenants     │ (logical replication)    │      │                                  │
│ tenant_<uuid>.*    │      │                   │      │  (Next.js dashboard: follow-up) │
└───────────────────┘      └──────────────────┘      └─────────────────────────────────┘
```

- **Server A / Server B already exist** and are only touched for
  configuration (Postgres logical replication + a role, and a firewall rule
  on Server B). No new software is installed on either.
- **Everything new** (Kafka Connect/Debezium, ClickHouse, Superset, and their
  supporting Postgres/Redis) runs via Docker Compose on a **new Ubuntu
  server**.

---

## Repo layout

```
analytics-beezap/
├── postgres/
│   └── 01_logical_replication_setup.sql   # run on Server A (superuser)
├── kafka/
│   └── create-topics.sh                   # run inside kafka-connect container, against Server B
├── kafka-connect/
│   ├── connectors/beezap-postgres-cdc.json
│   └── register-connector.sh              # run on the new server (host)
├── clickhouse/
│   ├── 00_functions.sql ... 08_views.sql
│   └── apply.sh                           # run on the new server (host)
├── superset/
│   ├── Dockerfile
│   └── superset_config.py
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## Prerequisites

- A new Ubuntu server with **Docker Engine + Docker Compose plugin**
  installed (`docker compose version` works).
- Network connectivity:
  - new server → Server A `xx.xx.x.93:5432` (Postgres)
  - new server → Server B `xx.xx.8.60:9092` (Kafka)
- Admin access to Server A (shell access to its `docker-compose.yml`/Postgres
  container, to run SQL as a superuser and adjust replication settings /
  `pg_hba.conf`) and to Server B (to add one firewall rule). Both are done
  manually, following the steps below.
- This repo copied onto the new server (e.g. `git clone` or `scp -r`).

---

## Step 1 — Server A: enable logical replication & create the CDC role

**Server A's PostgreSQL runs via Docker Compose.** Steps 2-4 below use plain
`docker exec <pg_container>` (works from any directory, targets the
container directly — replace `<pg_container>` with the actual container name,
e.g. `db_postgres`, from `docker ps`). Step 1 edits `docker-compose.yml`
itself, so it must be run from the directory containing that file (and uses
the **service name**, e.g. `postgres`, not the container name).

1. Set `wal_level = logical` (and the replication slot/sender limits) by
   adding a `command:` override to the Postgres service in Server A's
   `docker-compose.yml`. This works for any Postgres-based image and
   overrides whatever is in `postgresql.conf`:
   ```yaml
   services:
     postgres:                  # service name — check with `docker compose ps`
       image: postgres:16        # whatever image is already in use — don't change it
       command:
         - postgres
         - -c
         - wal_level=logical
         - -c
         - max_replication_slots=10
         - -c
         - max_wal_senders=10
       # ... keep existing volumes / environment / ports / networks as-is
   ```
   Apply it — this **recreates/restarts the container**, which is required
   for `wal_level` to take effect (schedule a maintenance window). Run from
   the directory containing this `docker-compose.yml`:
   ```bash
   docker compose up -d postgres
   ```
   If Server A already bind-mounts a custom `postgresql.conf` from the host,
   you can instead set the same three settings there and run
   `docker compose restart postgres` — either approach works.

2. Edit `pg_hba.conf` to allow the new server (replace `<NEW_SERVER_IP>` and
   `<pg_container>`). For the official `postgres` image, `pg_hba.conf` lives
   inside the data volume at `/var/lib/postgresql/data/pg_hba.conf`:
   ```bash
   docker exec <pg_container> bash -c \
     "echo 'host    beezap          debezium        <NEW_SERVER_IP>/32   scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf && \
      echo 'host    replication     debezium        <NEW_SERVER_IP>/32   scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"
   ```
   Verify the lines were appended:
   ```bash
   docker exec <pg_container> tail -3 /var/lib/postgresql/data/pg_hba.conf
   ```
   Then reload (no restart needed for `pg_hba.conf`):
   ```bash
   docker exec <pg_container> psql -U <superuser> -d beezap -c "SELECT pg_reload_conf();"
   ```

3. Open `postgres/01_logical_replication_setup.sql`, set a strong password in
   place of `CHANGE_ME_STRONG_PASSWORD`, and remember it for `.env`
   (`DEBEZIUM_DB_PASSWORD`) in Step 3. Copy the file into the Postgres
   container and run it as a superuser:
   ```bash
   docker cp postgres/01_logical_replication_setup.sql <pg_container>:/tmp/cdc_setup.sql
   docker exec <pg_container> psql -U <superuser> -d beezap -f /tmp/cdc_setup.sql
   ```
   (Equivalently, pipe it in without copying:
   `docker exec -i <pg_container> psql -U <superuser> -d beezap < postgres/01_logical_replication_setup.sql`)

   This creates the `debezium` replication role, grants `SELECT` on
   `public` and every existing `tenant_*` schema, and creates
   `CREATE PUBLICATION beezap_cdc FOR ALL TABLES`.

4. Verify (queries are also at the bottom of the SQL file):
   ```bash
   docker exec <pg_container> psql -U <superuser> -d beezap -c "SHOW wal_level;"
   docker exec <pg_container> psql -U <superuser> -d beezap -c "SELECT pubname, puballtables FROM pg_publication;"
   docker exec <pg_container> psql -U <superuser> -d beezap -c "SELECT rolname, rolreplication FROM pg_roles WHERE rolname = 'debezium';"
   ```
   Expected: `wal_level = logical`, `beezap_cdc | t`, `debezium | t`.

5. Make sure port 5432 is published from the container to the host (`ports:
   - "5432:5432"` in Server A's `docker-compose.yml`), and that Server A's
   host firewall allows the new server's IP on 5432, e.g.:
   ```bash
   sudo ufw allow from <NEW_SERVER_IP> to any port 5432 proto tcp
   ```

### A note on `public.tenants` and `tenant_*.users` sensitive columns

The Debezium connector (Step 5) excludes these columns at the source — they
never reach Kafka/Postgres replication slot output beyond Postgres itself:
- `public.tenants`: `wa_number`, `waba_id`, `email_wa`, `password_wa`
- `tenant_*.users`: `password`, `meta_data`
- `tenant_*.wa_chat_contacts`: `meta_data`, `last_message`
- `tenant_*.wa_chat_messages`: `content`, `media_url`, `media_filename`,
  `meta_data`, `error_message`, `template_parameters`, `attachment`,
  `link_file`, `bot_response`

If you need any of these for analytics later, see "Reversing column
exclusions" near the end of this file.

---

## Step 2 — Server B: firewall rule

Allow the new server to reach the existing Kafka broker on port 9092
(replace `<NEW_SERVER_IP>`):
```bash
# example using ufw
sudo ufw allow from <NEW_SERVER_IP> to any port 9092 proto tcp
```
Also confirm Kafka's `advertised.listeners` resolves to an address reachable
from the new server (not just `localhost`/internal hostnames).

---

## Step 3 — New Ubuntu server: bootstrap

1. Install Docker + Compose plugin (if not already):
   ```bash
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker "$USER"   # log out/in afterwards
   ```

2. Copy this repo to the server, then create your `.env`:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and fill in:
   - `PG_HOST` / `PG_PORT` / `PG_DATABASE` / `DEBEZIUM_DB_USER` /
     `DEBEZIUM_DB_PASSWORD` — match Step 1 (Server A).
   - `KAFKA_BOOTSTRAP_SERVERS` — Server B, e.g. `xx.xx.8.60:9092`.
   - `CLICKHOUSE_PASSWORD` — pick a strong password.
   - `SUPERSET_SECRET_KEY` — generate with `openssl rand -base64 42`.
   - `SUPERSET_ADMIN_*` and `SUPERSET_DB_PASSWORD` — pick strong values.

3. Local firewall on the new server:
   - `8088` (Superset UI) — open to whoever needs the dashboards.
   - `8083` (Kafka Connect REST API) and `8123`/`9000` (ClickHouse) —
     restrict to your admin IP(s)/VPN; they don't need to be public. They're
     only used for connector management and ClickHouse queries from
     Superset (which runs on the same Docker network and doesn't need the
     published ports at all).

---

## Step 4 — Start Kafka Connect & create Kafka topics

```bash
docker compose up -d kafka-connect
```

Wait ~30s for the worker to come up, then create the CDC + Kafka Connect
internal topics on Server B:
```bash
docker compose exec kafka-connect bash /kafka/create-topics.sh
```
This is idempotent (`--if-not-exists`) and prints the resulting topic list.
If Server B has more than one broker, re-run with
`REPLICATION_FACTOR=<n> docker compose exec -e REPLICATION_FACTOR=<n> kafka-connect bash /kafka/create-topics.sh`.

---

## Step 5 — Register the Debezium PostgreSQL connector

On the host (not inside a container) — requires `curl`, `jq`, and `envsubst`
(`gettext-base`):
```bash
sudo apt-get install -y jq gettext-base   # if missing
chmod +x kafka-connect/register-connector.sh
./kafka-connect/register-connector.sh
```
This renders `kafka-connect/connectors/beezap-postgres-cdc.json` with values
from `.env` and POSTs (or PUTs, if it already exists) it to the Connect REST
API, then prints the connector status.

Confirm `connector.state` and the task's `state` are both `RUNNING`:
```bash
curl -s http://localhost:8083/connectors/beezap-postgres-cdc/status | jq .
```

The connector will:
1. Take an initial snapshot of `public.tenants` and every
   `tenant_*.{users,wa_chat_contacts,wa_chat_messages,user_sessions,contact_results,contact_results_history}`
   table.
2. Then stream ongoing changes via the `beezap_cdc` publication /
   `debezium_beezap` replication slot.
3. Route everything into the unified `cdc.<table>` topics (e.g.
   `cdc.wa_chat_messages` contains rows from every tenant, tagged with
   `__source_schema`).

---

## Step 6 — Start ClickHouse & apply the schema

```bash
docker compose up -d clickhouse
```

Apply all schema files (functions, Kafka engine tables, materialized views,
target tables, convenience/analytics views) — requires `envsubst`:
```bash
chmod +x clickhouse/apply.sh
./clickhouse/apply.sh
```

Verify the Kafka consumers are healthy and not erroring:
```bash
docker compose exec clickhouse clickhouse-client \
  --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" \
  --query "SELECT table, consumer_id, assignments.topic, assignments.partition_id, num_messages_read, last_exception FROM system.kafka_consumers FORMAT Vertical"
```

Once the initial snapshot has flowed through, sanity-check row counts:
```bash
docker compose exec clickhouse clickhouse-client \
  --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" \
  --query "SELECT 'tenants', count() FROM beezap.v_tenants
           UNION ALL SELECT 'wa_chat_messages', count() FROM beezap.v_wa_chat_messages
           UNION ALL SELECT 'wa_chat_contacts', count() FROM beezap.v_wa_chat_contacts
           UNION ALL SELECT 'users', count() FROM beezap.v_users
           UNION ALL SELECT 'user_sessions', count() FROM beezap.v_user_sessions
           UNION ALL SELECT 'contact_results', count() FROM beezap.v_contact_results
           UNION ALL SELECT 'contact_results_history', count() FROM beezap.v_contact_results_history"
```

---

## Step 7 — Start Superset

1. Build the custom image (adds the `clickhouse-connect` driver) and bring up
   its dependencies:
   ```bash
   docker compose build superset
   docker compose up -d superset-db redis
   ```

2. Initialize Superset's metadata DB and admin user (one-off commands):
   ```bash
   docker compose run --rm superset superset db upgrade

   docker compose run --rm superset superset fab create-admin \
     --username "$SUPERSET_ADMIN_USER" \
     --firstname "$SUPERSET_ADMIN_FIRSTNAME" \
     --lastname "$SUPERSET_ADMIN_LASTNAME" \
     --email "$SUPERSET_ADMIN_EMAIL" \
     --password "$SUPERSET_ADMIN_PASSWORD"

   docker compose run --rm superset superset init
   ```
   (`$SUPERSET_*` vars come from `.env` — either `export $(grep -v '^#' .env | xargs)`
   first, or substitute the values directly.)

3. Start the web server:
   ```bash
   docker compose up -d superset
   ```
   Visit `http://<new-server-ip>:8088` and log in with the admin credentials.

4. Add the ClickHouse connection: **Settings → Database Connections → + Database**,
   choose "Other", and use the SQLAlchemy URI:
   ```
   clickhousedb://default:<CLICKHOUSE_PASSWORD>@clickhouse:8123/beezap
   ```
   (host `clickhouse` and port `8123` are the Docker Compose service name and
   HTTP port — reachable on the internal Docker network without the published
   ports.)

5. Create datasets on top of the views in `clickhouse/08_views.sql`:
   - `beezap.v_message_delivery_funnel` — message counts by tenant / day /
     campaign / category / sender / status. Build a stacked bar or line chart
     of `status` over `day`, filterable by `tenant_id`/`tenant_name` and
     `campaign_id`.
   - `beezap.v_contact_growth` — new contacts by tenant / day / campaign /
     service_type. Build a time-series chart of `new_contacts` over `day`.
   - `beezap.v_agent_sessions` — session counts and online time by tenant /
     agent / day. Build a table or bar chart of `online_seconds` /
     `session_count` by `username`.
   - `beezap.v_wa_chat_messages`, `v_wa_chat_contacts`, `v_users`,
     `v_user_sessions`, `v_contact_results`, `v_contact_results_history`,
     `v_tenants` — raw "current state" views for ad-hoc exploration / drilldowns.

   Combine these charts into dashboards, e.g. "Message Delivery Funnel",
   "Campaign Performance", "Agent Activity", "Contact Growth", "Daily Message
   Volume by Tenant".

---

## New tenant onboarding

When a new `tenant_<uuid_with_underscores>` schema (and its
users/wa_chat_contacts/wa_chat_messages/user_sessions/contact_results/contact_results_history
tables) is created on Server A:

1. Grant the `debezium` role read access to the new schema (run on Server A
   as superuser, replacing the schema name):
   ```sql
   SELECT beezap_grant_cdc_privileges('tenant_<new_uuid_with_underscores>');
   ```
   (`beezap_grant_cdc_privileges` was created by
   `postgres/01_logical_replication_setup.sql` and is reusable.)

2. The `beezap_cdc` publication is `FOR ALL TABLES`, so the new schema's
   tables are already included at the WAL level — no `ALTER PUBLICATION`
   needed. The Debezium connector's `schema.include.list = public,tenant_.*`
   and `table.include.list` regexes already match the new schema/tables by
   pattern.

3. In most cases, data from the new tenant starts flowing within seconds of
   the first insert/update — no connector restart required. If you don't see
   new rows in ClickHouse (`beezap.v_<entity>`) after a few minutes:
   ```bash
   curl -X POST http://localhost:8083/connectors/beezap-postgres-cdc/restart
   ```
   or re-run `./kafka-connect/register-connector.sh` (PUTs the same config,
   which Kafka Connect treats as a restart trigger).

---

## Monitoring & troubleshooting

- **Connector status**:
  ```bash
  curl -s http://localhost:8083/connectors/beezap-postgres-cdc/status | jq .
  ```
  Look for `"state": "RUNNING"` on both the connector and its task. A
  `FAILED` task usually means a Postgres connectivity/permissions issue or a
  schema mismatch — check `trace` in the response.

- **Connector logs**:
  ```bash
  docker compose logs -f kafka-connect
  ```

- **ClickHouse Kafka consumer lag/errors**:
  ```sql
  SELECT table, consumer_id, num_messages_read, num_commits, last_exception
  FROM system.kafka_consumers FORMAT Vertical;
  ```
  A non-empty `last_exception` usually means a JSON shape mismatch between a
  `*_queue` table and what the connector is producing (e.g. a column was
  renamed/removed in Postgres). Fix the queue table's column list/types and
  re-run `clickhouse/apply.sh` for that entity (drop and recreate the
  `_queue`/`_mv` first — see "Re-applying ClickHouse schema changes" below).

- **Re-applying ClickHouse schema changes**: `CREATE TABLE`/`CREATE
  MATERIALIZED VIEW`/`CREATE FUNCTION` in this repo use `IF NOT EXISTS` /
  `OR REPLACE` and are safe to re-run. The `CREATE VIEW` statements in
  `08_views.sql` are not — drop the specific view first
  (`DROP VIEW IF EXISTS beezap.v_xxx`) before re-running that file.

---

## Security notes (recap)

- Kafka traffic is **plaintext** (no SASL/TLS) — acceptable only because
  Server B and the new server communicate over a trusted network. Revisit if
  that assumption changes.
- No schema registry — all topics carry plain JSON
  (`schemas.enable=false`).
- `.env` holds real credentials and is **git-ignored** — never commit it.
- Sensitive/large columns are excluded at the Debezium connector level (see
  Step 1) and never reach Kafka or ClickHouse.

### Reversing column exclusions

To bring back an excluded column (e.g. `wa_chat_messages.content`):
1. Remove it from `column.exclude.list` in
   `kafka-connect/connectors/beezap-postgres-cdc.json`, then re-run
   `./kafka-connect/register-connector.sh`.
2. Add the column to the corresponding `*_queue` table, target table, and
   materialized view `SELECT` in `clickhouse/0X_*.sql`, then re-run
   `clickhouse/apply.sh` (drop+recreate that entity's `_queue`/`_mv`/table
   first if they already exist with the old column list).

---

## Assumptions to verify against real data

- **`tenant_id` derivation** (`clickhouse/00_functions.sql`,
  `beezap_tenant_id`): assumes schema names follow
  `tenant_<uuid-with-dashes-replaced-by-underscores>`, e.g. UUID
  `123e4567-e89b-12d3-a456-426614174000` → schema
  `tenant_123e4567_e89b_12d3_a456_426614174000`. After the initial snapshot,
  spot-check:
  ```sql
  SELECT DISTINCT __source_schema, beezap_tenant_id(__source_schema)
  FROM beezap.wa_chat_messages_queue LIMIT 20;
  ```
  ...and confirm the derived UUIDs exist in `beezap.tenants`/`public.tenants`.
  If the naming convention differs, adjust the `beezap_tenant_id` function
  body and re-run `clickhouse/apply.sh`.

- **Timestamp parsing** (`beezap_parse_datetime` /
  `beezap_parse_datetime_or_null`): the source schema docs note several
  timestamp columns are stored as `VARCHAR` in Postgres with inconsistent
  formats (epoch seconds/millis as strings, ISO8601, etc.). The UDFs handle
  all of these with a fallback to the Debezium event timestamp. After the
  initial snapshot, spot-check a few rows per entity for `1970-01-01` or
  otherwise implausible timestamps, which would indicate an unhandled format
  — extend the `multiIf` branches in `00_functions.sql` if so.

---

## Next.js dashboard integration (follow-up, out of scope here)

Two common options once dashboards are built in Superset:
1. **Superset Embedded SDK** — embed dashboards/charts in the existing
   Next.js app via guest tokens (`@superset-ui/embedded-sdk`).
2. **Direct ClickHouse queries** — the Next.js backend queries
   `beezap.v_*` views directly via `clickhouse-connect`'s Node client for
   fully custom UI.

---

## Verification checklist

- [ ] `GET http://<new-server>:8083/connectors/beezap-postgres-cdc/status` →
      connector and task both `RUNNING`.
- [ ] `SELECT * FROM system.kafka_consumers` in ClickHouse → no
      `last_exception`, `num_messages_read` increasing (or stable after
      snapshot completes).
- [ ] Insert/update a row in a `tenant_*.wa_chat_messages` table on Server A
      → appears in `beezap.v_wa_chat_messages` within a few seconds.
- [ ] In Superset: ClickHouse connection test succeeds; `SELECT count() FROM
      beezap.wa_chat_messages` returns a non-zero count; build one chart from
      `v_message_delivery_funnel`.
