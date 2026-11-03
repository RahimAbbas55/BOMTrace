h1 align="center">BOMTrace</h1>
 
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
  <img src="https://img.shields.io/badge/Progress-Day_2_of_10-blue?style=for-the-badge" alt="Progress: Day 2 of 10">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License: MIT">
  <img src="https://img.shields.io/github/last-commit/RahimAbbas55/BOMTrace?style=for-the-badge" alt="Last commit">
</p>

Manage items, multi-level bills of materials (BOMs) and engineering change orders on Oracle Autonomous Database. Live demo and screenshots will be added after deployment.

## Why this project

Product lifecycle management is built on three things: items, the BOMs that connect them, and the change orders that modify them. BOMTrace models that domain in Oracle Database and keeps the business rules in a PL/SQL package, so the rules hold no matter which client talks to the database.

## What it does

- Stores items with a type (make, buy, assembly) and a lifecycle (prototype, active, obsolete).
- Models multi-level BOMs and explodes them with rolled-up quantities.
- Answers where-used: every assembly, at any level, that contains a part.
- Runs change orders through a controlled workflow: draft, submitted, approved or rejected, implemented.
- Enforces the rules in PL/SQL: valid status transitions, no BOM cycles, no changes to obsolete items, no self-approval, atomic implementation.
- Keeps an audit trail of every change.

## Architecture

```
React (Vite)  ->  Express API (MVC)  ->  PL/SQL package PLM_PKG  ->  Oracle Autonomous DB
                  JWT auth, roles        business rules, BOM        tables, constraints,
                  validation             queries, workflow          indexes, audit triggers
```

The API is layered: routes, controllers, models (all SQL and PL/SQL calls), plus middlewares for authentication, role checks, validation and error handling. An architecture diagram will replace the sketch above at the end of the project.

## Tech stack

| Layer | Choice |
|---|---|
| Database | Oracle Autonomous Database (OCI Always Free) |
| Database logic | PL/SQL package and triggers |
| API | Node.js, Express, `node-oracledb` (thin mode) |
| Auth | JWT, bcrypt, role-based middleware (planned) |
| Frontend | React with Vite (planned) |
| Tests | PL/SQL test scripts, Jest and Supertest (planned) |
| DevOps | Docker, GitHub Actions, OCI Compute (planned) |

## Data model

Seven tables, all with named constraints, identity primary keys and indexed foreign keys.

| Table | Purpose |
|---|---|
| `USERS` | Logins with an `ENGINEER` or `APPROVER` role |
| `ITEMS` | Item master: number, name, type, lifecycle status |
| `BOM_LINES` | Parent to child links with a quantity, indexed by child for fast where-used |
| `CHANGE_ORDERS` | Change order header and workflow status |
| `CHANGE_ORDER_ITEMS` | The individual changes within a change order |
| `APPROVALS` | Approval decisions and comments |
| `AUDIT_LOG` | Generic JSON audit trail |

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
| 3 | `add_bom_line` with cycle rejection, change order workflow procedures | Next |
| 4 | Business rules and custom errors, audit triggers, PL/SQL tests | Planned |
| 5 to 6 | Express API, JWT auth, role middleware, API tests | Planned |
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
- [x] `USERS` and `ITEMS` tables
- [x] `BOM_LINES` with uniqueness, self-reference check and where-used index
- [x] `CHANGE_ORDERS`, `CHANGE_ORDER_ITEMS` and `APPROVALS` tables
- [x] `AUDIT_LOG` table and a dev reset script
- [x] Seed data: users, 58 items, 66 BOM lines, 5 change orders
- [x] `PLM_PKG.explode_bom` and `PLM_PKG.where_used` (recursive queries with cycle protection)

### Next up

**Day 3: BOM editing and the change order workflow**
- [ ] `add_bom_line` that rejects cycles (a child cannot be an ancestor of the parent)
- [ ] `create_change_order` and `add_co_item`
- [ ] `submit_change_order`, `approve_change_order`, `reject_change_order`
- [ ] `implement_change_order` as one atomic transaction
- [ ] `impact_report` for a change order

**Day 4: rules, errors, audit and tests**
- [ ] Custom exceptions with error codes `-20001` and up
- [ ] Status transition checks, obsolete item protection, no self-approval
- [ ] Audit triggers on `ITEMS`, `BOM_LINES` and `CHANGE_ORDERS`
- [ ] PL/SQL tests: cycle detection, where-used at depth 4, every valid and invalid transition, atomic implement, self-approval rejection

**After that:** REST API and auth (Day 5 to 6), React UI (Day 7 to 8), Docker and CI/CD (Day 9), polish and demo video (Day 10).

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
    schema/          table scripts and the dev reset script
    seed/            demo data
    plsql/           PLM_PKG
    tests/           PL/SQL tests (to come)
  web/               React app (to come)
  docs/
```

## Local setup

1. Create an Oracle Cloud account and provision an **Autonomous Database** (Transaction Processing, Always Free).
2. Download the instance wallet and unzip it into `api/wallet/`. This folder is gitignored.
3. As `ADMIN`, run `db/schema/00_create_app_user.sql`. The password must be 12 to 30 characters with an uppercase letter, a lowercase letter and a digit.
4. As `PLM_APP`, run in order:
   - `db/schema/01_users_items.sql`, `02_bom_lines.sql`, `03_change_orders.sql`, `04_audit_log.sql`
   - `db/seed/01_seed_users_items.sql`, `02_seed_bom.sql`, `03_seed_change_orders.sql`
   - `db/plsql/plm_pkg.sql`
5. Copy `.env.example` to `api/.env` and fill in the values:

   | Variable | Meaning |
   |---|---|
   | `DB_USER` | `PLM_APP` |
   | `DB_PASSWORD` | the `PLM_APP` password |
   | `DB_CONNECT_STRING` | an alias from `wallet/tnsnames.ora`, for example `bomtrace_low` |
   | `DB_WALLET_DIR` | `./wallet` |
   | `DB_WALLET_PASSWORD` | the password set when downloading the wallet |

6. Start the API:
   ```bash
   cd api
   npm install
   npm run dev
   ```
7. Check it:
   ```bash
   curl localhost:3000/api/health
   ```
   Expected: `{"status":"ok","db":"up"}`

To rebuild the schema from scratch, run `db/schema/99_reset.sql` (it drops all data), then repeat step 4.

## Testing

PL/SQL and API tests are planned for Day 4 to 6. The README will report the real coverage numbers once they exist.

## License

[MIT](LICENSE)