<h1 align="center">BOMTrace</h1>

<p align="center">
  <b>Oracle-backed PLM change order tracker</b><br>
  Multi-level BOMs, where-used impact analysis and an approval workflow, with the business rules in PL/SQL.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Oracle_Database-F80000?style=for-the-badge&logo=oracle&logoColor=white" alt="Oracle Database">
  <img src="https://img.shields.io/badge/PL%2FSQL-F80000?style=for-the-badge&logo=oracle&logoColor=white" alt="PL/SQL">
  <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js">
  <img src="https://img.shields.io/badge/Express-000000?style=for-the-badge&logo=express&logoColor=white" alt="Express">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-In_Progress-orange?style=for-the-badge" alt="Status: in progress">
  <img src="https://img.shields.io/badge/Progress-Day_4_of_10-blue?style=for-the-badge" alt="Progress: Day 4 of 10">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License: MIT">
  <img src="https://img.shields.io/github/last-commit/RahimAbbas55/BOMTrace?style=for-the-badge" alt="Last commit">
</p>

Manage items, multi-level bills of materials (BOMs) and engineering change orders on Oracle Autonomous Database. Live demo and screenshots will be added after deployment.

## Why this project

Product lifecycle management is built on three things: items, the BOMs that connect them, and the change orders that modify them. BOMTrace models that domain in Oracle Database and keeps the business rules in a PL/SQL package, so the rules hold no matter which client talks to the database.

## What it does

- Stores items with a type (make, buy, assembly) and a lifecycle (prototype, active, obsolete). New items start as prototypes, and the lifecycle only changes through change orders.
- Models multi-level BOMs, explodes them with rolled-up quantities, and answers where-used: every assembly, at any level, that contains a part.
- Runs change orders through a controlled workflow: draft, submitted, approved or rejected, implemented.
- Reports the impact of a change order: for every line, the assemblies and finished products above the changed item.
- Enforces the rules in PL/SQL:
  - only valid status transitions
  - no BOM cycles, including loops that two separate change orders would create together
  - no changes to obsolete items
  - only approvers decide, and the creator cannot approve their own change order
  - a rejection needs a comment
  - implementation is atomic, and rejects change orders that went stale after they were drafted
- Keeps an audit trail of every insert, update and delete on items, BOM lines and change orders, with the acting user.

## Architecture

```
React (Vite)  ->  Express API (MVC)  ->  PL/SQL packages PLM_PKG, PLM_AUDIT  ->  Oracle Autonomous DB
                  JWT auth, roles        business rules, BOM queries,            tables, constraints,
                  validation             workflow, audit context                 indexes, audit triggers
```

The API is layered: routes, controllers, models (all SQL and PL/SQL calls), plus middlewares for authentication, role checks, validation and error handling. An architecture diagram will replace the sketch above at the end of the project.

## Tech stack

| Layer | Choice |
|---|---|
| Database | Oracle Autonomous Database (OCI Always Free) |
| Database logic | PL/SQL packages and triggers |
| API | Node.js, Express, `node-oracledb` (thin mode) |
| Auth | JWT, bcrypt, role-based middleware (planned) |
| Frontend | React with Vite (planned) |
| Tests | PL/SQL tests with a Node runner, Jest and Supertest for the API (planned) |
| DevOps | Docker, GitHub Actions, OCI Compute (planned) |

## Data model

Seven tables, all with named constraints, identity primary keys and indexed foreign keys, plus one sequence for change order numbers.

| Table | Purpose |
|---|---|
| `USERS` | Logins with an `ENGINEER` or `APPROVER` role |
| `ITEMS` | Item master: number, name, type, lifecycle status |
| `BOM_LINES` | Parent to child links with a quantity, indexed by child for fast where-used |
| `CHANGE_ORDERS` | Change order header and workflow status |
| `CHANGE_ORDER_ITEMS` | The individual changes within a change order |
| `APPROVALS` | Approval decisions and comments |
| `AUDIT_LOG` | Generic JSON audit trail, before and after values |

## PL/SQL packages

`PLM_PKG` is the only way the application changes data. Every rule failure raises a named `ORA-200xx` error, documented in [docs/error-codes.md](docs/error-codes.md).

| Area | Procedures and functions |
|---|---|
| BOM queries | `explode_bom`, `where_used` |
| BOM editing | `add_bom_line` (rejects cycles), `remove_bom_line` |
| Items | `create_item`, `update_item` |
| Change orders | `create_change_order`, `add_co_item`, `submit_change_order`, `approve_change_order`, `reject_change_order`, `implement_change_order`, `impact_report` |

`PLM_AUDIT` holds the acting user for the session and writes the audit rows that the triggers on `ITEMS`, `BOM_LINES` and `CHANGE_ORDERS` produce.

## Seed data

The seed scripts load a small electric bike as demo data:

- 58 items: 15 assemblies, 17 make parts and 26 buy parts.
- 66 BOM lines forming a 4-level structure (bike, drive unit, motor, controller board, MOSFET).
- 5 sample change orders, one in each status.

Demo logins (public demo credentials, only for the seeded database):

| Role | Email | Password |
|---|---|---|
| Engineer | `engineer@bomtrace.dev` | `BomTrace-Eng-2026` |
| Approver | `approver@bomtrace.dev` | `BomTrace-App-2026` |

## Progress

### Daily log

| Day | Plan | Status |
|---|---|---|
| 1 | Oracle Cloud account, Autonomous DB, working Node connection | Done |
| 2 | Schema, constraints, indexes, seed data, `explode_bom`, `where_used` | Done |
| 3 to 4 | Complete PL/SQL layer: BOM editing, change order workflow, implement, impact report, items, audit triggers, tests | Done |
| 5 to 6 | Express API, JWT auth, role middleware, API tests | Next |
| 7 to 8 | React UI | Planned |
| 9 | Docker, GitHub Actions, deployment to OCI | Planned |
| 10 | README polish, architecture diagram, demo video | Planned |

### Done so far

**Day 1**
- [x] Autonomous Database provisioned (Always Free)
- [x] `PLM_APP` schema user created, so the API never connects as `ADMIN`
- [x] Express API scaffold with the MVC structure
- [x] Validated environment config and Oracle connection pool
- [x] `GET /api/health` checks the database through route, controller and model
- [x] Central error handler and not-found middleware

**Day 2**
- [x] Tables for users, items, BOM lines, change orders, approvals and the audit log
- [x] Seed data: users, 58 items, 66 BOM lines, 5 change orders
- [x] `explode_bom` and `where_used` (recursive queries with cycle protection)

**Day 3 to 4**
- [x] Named exceptions and an error code reference
- [x] `add_bom_line` with cycle detection, and `remove_bom_line`
- [x] `create_change_order` (auto-numbered) and `add_co_item` with per-type validation
- [x] Status transition check, `submit_change_order`, `approve_change_order`, `reject_change_order`
- [x] `implement_change_order`: atomic, with stale-change detection
- [x] `impact_report`
- [x] `create_item` and `update_item`
- [x] Audit context package and audit triggers
- [x] PL/SQL tests, an end-to-end workflow test, a test runner and a PL/SQL installer script

### Next up

**Day 5 to 6: REST API and auth**
- [ ] JWT login and registration, role middleware for `ENGINEER` and `APPROVER`
- [ ] Middleware that sets the acting user for the audit trail on every request
- [ ] Map `ORA-200xx` errors to HTTP statuses using the error code reference
- [ ] Items, BOM, change order and impact endpoints, each calling a model that calls `PLM_PKG`
- [ ] Input validation, Helmet and rate limiting on the auth routes
- [ ] Jest and Supertest tests for auth, roles and the full change order flow

**After that:** React UI (Day 7 to 8), Docker and CI/CD (Day 9), polish and demo video (Day 10).

## Planned API

Base path `/api`. Only the health endpoint exists today.

| Area | Endpoints |
|---|---|
| Health | `GET /health` (implemented) |
| Auth | `POST /auth/register`, `POST /auth/login` |
| Items | `GET /items`, `GET /items/:id`, `POST /items`, `PATCH /items/:id`, `GET /items/:id/bom`, `GET /items/:id/where-used` |
| BOM | `POST /bom-lines`, `DELETE /bom-lines/:id` |
| Change orders | `GET /change-orders`, `GET /change-orders/:id`, `POST /change-orders`, `POST /change-orders/:id/items`, `POST /change-orders/:id/submit`, `POST /change-orders/:id/approve`, `POST /change-orders/:id/reject`, `POST /change-orders/:id/implement`, `GET /change-orders/:id/impact` |

## Project structure

```
bomtrace-plm/
  api/
    scripts/         run-db-tests.js, install-plsql.js
    src/
      config/        environment and Oracle pool
      routes/        URL to controller mapping
      controllers/   HTTP layer
      models/        all SQL and PL/SQL calls
      middlewares/   error handling (auth and validation to come)
      utils/         AppError, asyncHandler
      app.js
      server.js
  db/
    schema/          table scripts, change order number sequence, dev reset script
    seed/            demo data
    plsql/           PLM_PKG, PLM_AUDIT, audit triggers
    tests/           PL/SQL tests
  web/               React app (to come)
  docs/              error code reference
```

## Local setup

1. Create an Oracle Cloud account and provision an **Autonomous Database** (Transaction Processing, Always Free).
2. Download the instance wallet and unzip it into `api/wallet/`. This folder is gitignored.
3. As `ADMIN`, run `db/schema/00_create_app_user.sql`. The password must be 12 to 30 characters with an uppercase letter, a lowercase letter and a digit.
4. As `PLM_APP`, run in order:
   - `db/schema/01_users_items.sql`, `02_bom_lines.sql`, `03_change_orders.sql`, `04_audit_log.sql`, `05_co_number_seq.sql`
   - `db/seed/01_seed_users_items.sql`, `02_seed_bom.sql`, `03_seed_change_orders.sql`
5. Copy `.env.example` to `api/.env` and fill in the values:

   | Variable | Meaning |
   |---|---|
   | `DB_USER` | `PLM_APP` |
   | `DB_PASSWORD` | the `PLM_APP` password |
   | `DB_CONNECT_STRING` | an alias from `wallet/tnsnames.ora`, for example `bomtrace_low` |
   | `DB_WALLET_DIR` | `./wallet` |
   | `DB_WALLET_PASSWORD` | the password set when downloading the wallet |

6. Install the PL/SQL packages and triggers. This prints any compile errors:
   ```bash
   cd api
   npm install
   npm run db:plsql
   ```
7. Start the API and check it:
   ```bash
   npm run dev
   curl localhost:3000/api/health
   ```
   Expected: `{"status":"ok","db":"up"}`

To rebuild the database from scratch, run `db/schema/99_reset.sql` (it drops all data), then repeat steps 4 and 6.

## Testing

The PL/SQL layer has one test file per feature in `db/tests/`, plus an end-to-end workflow test. Each file prints `PASS` or `FAIL` lines and rolls back everything it did.

```bash
cd api
npm run test:db
```

The runner executes every file, prints the pass count per file, and exits with a non-zero code if any check fails, so it can run in CI. Run it against a database that only holds the seed data, because some tests rely on the seeded change orders and quantities. The numbers here are the real ones from the last run: 9 files, 117 checks.

API tests with Jest and Supertest come with Day 5 and 6, and their coverage will be reported here.

## License

[MIT](LICENSE)