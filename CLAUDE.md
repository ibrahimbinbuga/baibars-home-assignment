# CLAUDE.md — Vehicle Fleet Monitoring (Home Assignment)

This file is the single source of truth for building this project. Read it fully before doing anything.
Work **phase by phase** (Section 12). After each phase: run the tests, summarize what changed and why,
list any decision you made that is not in this file, and **stop and wait for confirmation** before the next phase.

The developer will defend every line of this code in a technical interview. Therefore:
- Prefer simple, conventional, readable code over clever code.
- Do not add libraries, layers, or patterns that this file does not ask for. If you think one is needed, ask first.
- When you make a non-obvious choice, leave a short comment explaining *why* (not *what*).
- Never present hardcoded data in the mobile app as live data. All data comes from the backend.

---

## 1. Assignment summary

An operations team monitors multiple remote vehicles through a mobile app. They need to:
1. See registered vehicles
2. Understand each vehicle's operational status
3. See vehicle locations
4. Monitor changing vehicle information (real-time)
5. Review previous activity (history)
6. Only access information they are permitted to see

Hard constraints from the assignment:
- Mobile app must use our backend (no hardcoded sample data presented as live).
- Data must persist across backend restarts.
- Permissions must be enforced by the backend, not only in the UI.
- Deliverables: backend + mobile source, README (prerequisites, config, run steps), tests + how to run them,
  screenshots or a short video, and a technical decisions document (Section 14).
- Timeframe: 5 calendar days. A smaller, well-reasoned, working solution beats many half-finished features.
- Avoid enterprise complexity unless justified.

Company context: the employer builds agricultural drones/vehicles (Mersin, Turkey). The simulator places
vehicles around the Çukurova plain (Tarsus/Adana) for realism. Keep the domain generic ("vehicle"), do not
over-specialize it into drones.

---

## 2. Clarification questions & working assumptions

Questions were sent to the company. Until they answer, build on these assumptions. Keep each one
easy to change (config value or a single isolated class).

| # | Topic | Assumption | Where it lives / how to change |
|---|-------|-----------|--------------------------------|
| A1 | Access scope | Access is granted per **fleet**. A user sees vehicles only in fleets assigned to them. | `UserFleetAccess` table + `IVehicleAccessService`. Per-vehicle access would mean swapping this table; the policy layer stays the same. |
| A2 | Roles | `Admin` sees all fleets. `Operator` sees only assigned fleets. Both are **read-only**. | `Role` enum on `User`. |
| A3 | Scale | Tens of vehicles, one update every ~2 s per vehicle. | Simulator config `Simulator:IntervalSeconds`. |
| A4 | Scope | Monitoring only. No commands sent to vehicles. | Out of scope (documented). |
| A5 | Online/offline | Derived on the server: a vehicle with no telemetry for **30 s** is `Offline`. | `Telemetry:OfflineThresholdSeconds`. |
| A6 | Activity | "Previous activity" = telemetry history (position/battery/speed over time) + activity events (status changes, online/offline, low battery, fault). | `TelemetryRecord`, `ActivityEvent`. |
| A7 | Retention | No retention policy; history kept indefinitely for the demo. | Documented as future work. |
| A8 | Vehicle → backend protocol | Vehicles push telemetry over HTTPS with a per-vehicle device key. | `POST /api/ingest/telemetry`. MQTT noted as a production alternative. |
| A9 | Mobile offline | No offline cache. The app shows clear stale/disconnected states and recovers on reconnect. | Documented simplification. |
| A10 | Unauthorized resource | Requesting a vehicle outside your scope returns **404**, not 403, so existence is not leaked. | `VehiclesController`. |

---

## 3. Tech stack

### Backend
- **.NET 10 (LTS)** ASP.NET Core Web API with **controllers** (not minimal APIs — familiar and easy to read).
  If .NET 10 SDK is not installed, stop and ask; do not silently downgrade.
- **PostgreSQL 16** via **EF Core** + `Npgsql.EntityFrameworkCore.PostgreSQL`. Migrations are committed.
- **SignalR** for real-time delivery to the mobile app.
- **JWT bearer** auth (`Microsoft.AspNetCore.Authentication.JwtBearer`), passwords hashed with `BCrypt.Net-Next`.
- `TimeProvider` (built into .NET) for all "now" logic, so time-dependent code is testable.
- Errors returned as RFC 7807 `ProblemDetails`.
- OpenAPI document (`Microsoft.AspNetCore.OpenApi`) + Swagger UI (`Swashbuckle.AspNetCore.SwaggerUI`), turned on by the
  config flag `Swagger:Enabled` (not by environment name). Default `false` in `appsettings.json`; `true` in
  `appsettings.Development.json` and in compose.

### Simulator
- Separate .NET console app (`Fleet.Simulator`) that behaves like real vehicles: it calls the ingest endpoint
  over HTTP with each vehicle's device key. It is a separate process **on purpose**: it shows the real
  vehicle → backend boundary, and stopping it shows offline detection working.

### Mobile
- **Flutter** (latest stable), Android + iOS.
- State: `flutter_riverpod`
- HTTP: `dio`
- Token storage: `flutter_secure_storage`
- Real-time: `signalr_netcore`
- Map: `flutter_map` + `latlong2` (OpenStreetMap tiles, so reviewers need no API key)
- Testing: `flutter_test` + `mocktail`

### Tests
- Backend: xUnit, `Microsoft.AspNetCore.Mvc.Testing` (WebApplicationFactory), `Testcontainers.PostgreSql`
  (real Postgres in tests, no in-memory provider), `Microsoft.Extensions.TimeProvider.Testing` (FakeTimeProvider).
- Assertions: plain xUnit `Assert` or `Shouldly`. **Do not use FluentAssertions** (v8+ has a commercial license).

### Infra
- `docker-compose.yml` with `db`, `api`, `simulator`. `docker compose up --build` must start the whole backend
  from a clean clone with zero manual steps.
- Compose runs the API with `ASPNETCORE_ENVIRONMENT=Production` (no developer exception page, so no stack traces leak).
  Demo features are switched on with explicit flags instead: `Swagger__Enabled=true`, `Seed__Enabled=true`.
  The demo JWT signing key and DB password live in compose, marked demo-only.
- Postgres is published on host port **5433** (`5433:5432`) so `dotnet run` with `appsettings.Development.json`
  (connection string on port 5433) can use the same database.

---

## 4. Repository layout

```
/
├── CLAUDE.md
├── README.md
├── docker-compose.yml
├── .gitignore                      # .NET + Flutter + IDE files
├── docs/
│   ├── DECISIONS.md                # technical decisions document (Section 14)
│   ├── API.md                      # endpoint + hub contract (generated from Section 7–8, kept in sync)
│   └── media/                      # screenshots, demo video link
├── backend/
│   ├── Fleet.sln
│   ├── src/
│   │   ├── Fleet.Api/
│   │   │   ├── Program.cs
│   │   │   ├── appsettings.json
│   │   │   ├── appsettings.Development.json
│   │   │   ├── Dockerfile
│   │   │   ├── Auth/               # login, JWT issuing, current-user helper
│   │   │   ├── Vehicles/           # controller, DTOs, access service
│   │   │   ├── Telemetry/          # ingest controller, ingestion service, offline detector
│   │   │   ├── Realtime/           # FleetHub, broadcaster
│   │   │   ├── Data/               # DbContext, entities, configurations, migrations, seeder
│   │   │   └── Common/             # ProblemDetails setup, options classes
│   │   └── Fleet.Simulator/
│   │       ├── Program.cs
│   │       ├── Dockerfile
│   │       └── ...
│   └── tests/
│       └── Fleet.Api.Tests/
└── mobile/
    └── fleet_monitor/              # Flutter app
```

Backend organization is **by feature folder in a single API project**, not Clean Architecture with
4 projects. Reason (put this in DECISIONS.md): the domain is small; extra projects add indirection
without adding testability, since integration tests run against the real HTTP pipeline anyway.

---

## 5. Domain model

### Entities

**User**
- `Id` (Guid), `Email` (unique, lowercase), `PasswordHash`, `DisplayName`, `Role` (`Admin` | `Operator`), `CreatedAt`

**Fleet**
- `Id` (Guid), `Name`, `Region` (string, e.g. "Tarsus")

**UserFleetAccess**
- `UserId`, `FleetId` (composite PK)

**Vehicle**
- `Id` (Guid), `FleetId`, `Name`, `Model`, `SerialNumber` (unique), `DeviceKeyHash`, `CreatedAt`
- Latest-state columns (denormalized for a fast list/map query):
  `LastLatitude`, `LastLongitude`, `LastSpeedKmh`, `LastHeadingDeg`, `LastBatteryPct`,
  `LastReportedState` (`Moving` | `Idle` | `Charging` | `Fault`), `LastTelemetryAt` (device time),
  `LastSeenAt` (server receive time), `Connectivity` (`Online` | `Offline`), `LastSequence` (long)
- `Status` shown to users is computed: `Offline` if `Connectivity == Offline`, otherwise `LastReportedState`.

**TelemetryRecord** (history)
- `Id` (long, identity), `VehicleId`, `Sequence` (long), `RecordedAt` (device time), `ReceivedAt` (server time),
  `Latitude`, `Longitude`, `SpeedKmh`, `HeadingDeg`, `BatteryPct`, `ReportedState`
- **Unique index** on (`VehicleId`, `Sequence`) → idempotent ingestion.
- Index on (`VehicleId`, `RecordedAt` DESC) → history queries.

**ActivityEvent**
- `Id` (long), `VehicleId`, `Type` (`CameOnline` | `WentOffline` | `StateChanged` | `LowBattery` | `FaultRaised`),
  `OccurredAt`, `Details` (short string, e.g. "Idle → Moving")
- Index on (`VehicleId`, `OccurredAt` DESC).

All timestamps are `DateTimeOffset` stored as UTC (`timestamptz`).

### Seed data (only when `Seed:Enabled` is true, idempotent: skip if users exist)
- `Seed:Enabled` is `false` by default in `appsettings.json`; `true` in `appsettings.Development.json` and in compose.
- Fleets: `Tarsus Field Ops` (Tarsus), `Adana Field Ops` (Adana)
- 4 vehicles per fleet (8 total), positioned around Tarsus (~36.92, 34.89) and Adana (~36.99, 35.33).
- Users (demo passwords, documented in README, **never** used outside demo):
  - `admin@demo.local` / `Admin123!` → Admin
  - `tarsus.operator@demo.local` / `Operator123!` → Operator, Tarsus only
  - `adana.operator@demo.local` / `Operator123!` → Operator, Adana only
- Device keys: the seeder writes the hashes; the simulator gets the plaintext keys from a shared config
  (`devices.json` mounted in compose). Document that in production each device would be provisioned individually.

---

## 6. Authentication & authorization

- `POST /api/auth/login` → `{ accessToken, expiresAt, user: { id, email, displayName, role } }`
- JWT: HS256, 60-minute lifetime, claims `sub`, `email`, `role`. Signing key from config
  `Jwt:SigningKey` (env var `Jwt__SigningKey` in compose). No refresh tokens (documented simplification;
  the app sends the user back to login on 401).
- Login failure returns a generic 401 ("Invalid email or password"). Do not reveal which part was wrong.
- **All** `/api/vehicles/**` endpoints and the hub require authentication.

### The access rule (most important part of the project)
- Exactly **one** place decides what a user may see: `IVehicleAccessService`
  - `Task<IReadOnlyList<Guid>> GetAccessibleFleetIdsAsync(ClaimsPrincipal user)` (Admin → all fleets)
  - `IQueryable<Vehicle> ScopeVehicles(IQueryable<Vehicle> query, IReadOnlyList<Guid> fleetIds)`
- Every vehicle query (list, detail, telemetry, activity) goes through this scoping. No controller filters by hand.
- Out-of-scope vehicle → **404** (A10).
- The SignalR hub uses the same service (Section 8). Real-time must never leak data across fleets.

### Ingestion auth
- `POST /api/ingest/telemetry` uses header `X-Device-Key`, not a user JWT.
- The key identifies the vehicle; the body never chooses which vehicle it writes to.
  Wrong/missing key → 401.

---

## 7. REST API

Base path `/api`. JSON camelCase. Enums serialized as strings.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/auth/login` | none | Get JWT |
| GET | `/auth/me` | user | Current user + accessible fleets |
| GET | `/fleets` | user | Fleets the user can see |
| GET | `/vehicles?fleetId=&status=` | user | List vehicles in scope with latest state |
| GET | `/vehicles/{id}` | user | One vehicle with latest state |
| GET | `/vehicles/{id}/telemetry?from=&to=&limit=` | user | History. Default: last 1 hour, `limit` default 500, max 2000, newest first |
| GET | `/vehicles/{id}/activity?before=&limit=` | user | Activity events, cursor pagination by `before` (timestamp), `limit` default 50, max 200 |
| POST | `/ingest/telemetry` | device key | Vehicle pushes one telemetry sample |
| GET | `/health` | none | Liveness + DB check |

### VehicleDto
```json
{
  "id": "guid", "fleetId": "guid", "fleetName": "Tarsus Field Ops",
  "name": "TR-01", "model": "AgriRover X", "serialNumber": "SN-0001",
  "status": "Moving | Idle | Charging | Fault | Offline",
  "connectivity": "Online | Offline",
  "latitude": 36.92, "longitude": 34.89,
  "speedKmh": 12.4, "headingDeg": 270, "batteryPct": 76,
  "lastTelemetryAt": "2026-11-26T10:00:00Z",
  "lastSeenAt": "2026-11-26T10:00:01Z"
}
```
Vehicles with no telemetry yet: location/metric fields are `null`, status `Offline`.

### Ingest request
```json
{
  "sequence": 1042,
  "recordedAt": "2026-11-26T10:00:00Z",
  "latitude": 36.92, "longitude": 34.89,
  "speedKmh": 12.4, "headingDeg": 270, "batteryPct": 76,
  "state": "Moving"
}
```
Validation: lat ∈ [-90, 90], lon ∈ [-180, 180], battery ∈ [0, 100], speed ≥ 0, heading ∈ [0, 360),
`recordedAt` not more than 5 minutes in the future (clock skew guard). Invalid → 400 ProblemDetails.

Response: `202 Accepted` for new samples, `200 OK` with `{ "duplicate": true }` for a repeated sequence.

---

## 8. Real-time (SignalR)

Hub path: `/hubs/fleet`. JWT passed as `access_token` query parameter (configure
`JwtBearerEvents.OnMessageReceived` to read it for `/hubs` paths only).

**Group membership is decided by the server, never by the client.**
- `OnConnectedAsync`: resolve accessible fleet IDs via `IVehicleAccessService`, add the connection to
  group `fleet:{fleetId}` for each. No `Subscribe(fleetId)` method exists that a client could abuse.
- Note in DECISIONS.md: if a user's access changes, it applies on their next connection (acceptable for demo).

Server → client messages:
| Method | Payload | When |
|---|---|---|
| `VehicleUpdated` | `VehicleDto` | After a new telemetry sample is stored |
| `ActivityRaised` | `ActivityEventDto` (`id, vehicleId, type, occurredAt, details`) | When an activity event is created |

Broadcast only to `fleet:{vehicle.FleetId}`.
Broadcast **after** the DB transaction commits, never before.

Wrap hub sending in an `IFleetBroadcaster` interface so ingestion logic is testable without SignalR.

---

## 9. Ingestion & consistency rules

`TelemetryIngestionService.IngestAsync(vehicleId, request)` in one DB transaction:
1. Insert `TelemetryRecord`. If the unique (`VehicleId`, `Sequence`) index is violated → return Duplicate,
   do nothing else. (Catch the specific Postgres unique-violation error code `23505`, not all exceptions.)
2. Always set `LastSeenAt = now` (server time). If the vehicle was `Offline`, set `Online` and add a `CameOnline` event.
3. **Only if** `request.RecordedAt > vehicle.LastTelemetryAt` (or it is null): update all `Last*` fields.
   Late/out-of-order samples go to history but do not overwrite the latest state.
4. Events (only when latest state is updated):
   - `StateChanged` when reported state differs from the previous one
   - `FaultRaised` when the new state is `Fault`
   - `LowBattery` when battery drops below 20 % (fire once when crossing the threshold, not on every sample)
5. Commit, then broadcast `VehicleUpdated` and any `ActivityRaised`.

Concurrency: the simulator sends one vehicle's samples in order, so per-vehicle write conflicts are unlikely.
Still, add `xmin` as an EF Core concurrency token on `Vehicle`. On conflict, retry once.
Document this choice briefly.

### Offline detection
`OfflineDetectorService : BackgroundService` runs every 5 s (config). It finds `Online` vehicles with
`LastSeenAt < now - OfflineThreshold`, sets them `Offline`, creates `WentOffline` events,
commits, and broadcasts. Use `TimeProvider` so tests can advance time.

---

## 10. Simulator

- Reads `devices.json` (vehicle serial, device key, start lat/lon) and config `Simulator:ApiBaseUrl`, `Simulator:IntervalSeconds` (default 2).
- Each vehicle runs its own loop: moves along a simple random-walk / waypoint path within ~3 km of its start,
  battery slowly drains while moving and recharges while `Charging`, randomly switches Idle/Moving,
  rare `Fault` (e.g. 1 % chance per tick, clears after ~20 s).
- One vehicle (configurable) periodically "drops out" for 45 s, to show offline detection in the demo.
- Sequence numbers increase per vehicle. On HTTP failure: log it and retry with backoff, and keep the sequence
  (shows idempotency if the request actually succeeded).
- Waits for `/health` before starting.
- Keep it simple. It is a demo data source, not a physics engine.

---

## 11. Mobile app

### Structure
```
lib/
├── main.dart
├── app.dart                      # MaterialApp, routing, theme
├── core/
│   ├── config.dart               # API_BASE_URL from --dart-define
│   ├── api_client.dart           # dio + auth interceptor (401 → logout)
│   ├── auth/                     # token storage, auth state notifier
│   └── realtime/                 # SignalR connection service + connection state
├── features/
│   ├── auth/                     # login screen
│   ├── vehicles/
│   │   ├── data/                 # models (fromJson), VehiclesRepository
│   │   ├── state/                # providers: vehicle list, vehicle detail
│   │   └── ui/                   # list, map, detail screens, widgets
│   └── activity/                 # history + events UI
└── shared/                       # status badge, time-ago text, connection banner
```

### Screens
1. **Login**: email/password, loading + error states. Demo accounts listed only in README, not in the UI.
2. **Vehicles** (bottom nav: *List* | *Map*):
   - List: name, fleet, status badge (color + text, not color only), battery, "updated Xs ago". Filter by status and fleet (fleet filter only if the user has more than one fleet).
   - Map: `flutter_map` markers colored by status; tap → detail.
   - Pull-to-refresh.
3. **Vehicle detail**: live values (status, position on a small map, speed, heading, battery, last update),
   tabs **Activity** (event list, paginated) and **History** (last 1 h telemetry as a simple list; a battery/speed
   chart is optional, only if time allows).
4. App bar: user name + role, logout.

### Real-time & connectivity behaviour (reviewers will test this)
- After login: fetch the REST snapshot, then start the SignalR connection. `VehicleUpdated` replaces the vehicle
  in state by id. Ignore an update whose `lastTelemetryAt` is older than what is already in state.
- Connection state shown in a top banner: `Connected` (hidden) / `Reconnecting…` / `Disconnected – Retry`.
- Use automatic reconnect with backoff (0, 2, 5, 10, 30 s, then keep 30 s).
- **On reconnect: re-fetch the REST snapshot**, because updates may have been missed while disconnected.
- Stale indicator: if `now - lastSeenAt > 30 s` while the app thinks the vehicle is online, show it as stale
  (grey "last seen Xm ago"). The server status is authoritative; this only covers the gap before the server's message arrives.
- Pause the SignalR connection when the app is backgrounded and reconnect + re-fetch on resume.
- 401 anywhere → clear token, go to login.

### Config
- `--dart-define=API_BASE_URL=http://10.0.2.2:8080` (Android emulator) / `http://localhost:8080` (iOS simulator).
  Document both in README. Allow cleartext HTTP for the dev host only (Android network security config / iOS ATS exception for localhost), and note it in DECISIONS.md.

---

## 12. Phases (stop after each one)

### Phase 0 — Scaffolding
- `.gitignore`, solution, projects, `docker-compose.yml` (db + api), Dockerfiles, `/health`.
- **Done when:** `docker compose up --build` starts Postgres + API and `/health` returns healthy.

### Phase 1 — Data & auth
- Entities, DbContext, configurations, first migration, auto-migrate on startup, seeder.
- Login endpoint, JWT, `/auth/me`.
- Tests: login success, wrong password → 401, protected endpoint without token → 401.
- **Done when:** data survives `docker compose down && docker compose up` (no `-v`).

### Phase 2 — Vehicles API & access control
- `IVehicleAccessService`, fleets + vehicles + telemetry + activity endpoints, ProblemDetails.
- Tests (**priority**): operator lists only own fleet; operator gets 404 for another fleet's vehicle on
  detail, telemetry and activity; admin sees all; `fleetId` filter cannot be used to see another fleet.

### Phase 3 — Ingestion, offline detection, simulator
- Ingest endpoint + service (Section 9), `OfflineDetectorService`, simulator project + compose service.
- Tests: bad device key → 401; valid sample updates latest state; duplicate sequence ignored;
  out-of-order sample stored but does not overwrite latest; state change creates event; low battery event fires once;
  offline after threshold using FakeTimeProvider; comes back online on next sample.

### Phase 4 — Real-time hub
- `FleetHub`, server-side groups, broadcaster, JWT via query string.
- Tests: using `Microsoft.AspNetCore.SignalR.Client` against the test server: Tarsus operator receives
  Tarsus updates and **does not** receive Adana updates; unauthenticated connection is rejected.

### Phase 5 — Mobile: auth, list, map
- Project setup, config, api client, login, vehicle list, map, detail (REST only).
- Tests: model JSON parsing (including nulls), list widget test with a fake repository.

### Phase 6 — Mobile: real-time, connectivity, history
- SignalR service, connection banner, reconnect + re-fetch, stale indicator, lifecycle handling, activity + history tabs.
- Tests: vehicle state notifier applies newer updates and ignores older ones; staleness calculation.

### Phase 7 — Documentation & polish
- README, `docs/DECISIONS.md`, `docs/API.md`, screenshots/video checklist (Section 15).
- Clean-clone check: delete local build outputs, follow the README step by step, confirm everything works.

---

## 13. Coding conventions

### C#
- Nullable reference types enabled, warnings as errors in `Fleet.Api`.
- Async all the way, pass `CancellationToken` through.
- DTOs are `record`s. Never return EF entities from controllers.
- Options pattern (`IOptions<T>`) for config sections; validate on start.
- Structured logging with `ILogger` message templates (no string interpolation in log calls). Never log device keys, passwords or tokens.
- No repository pattern on top of EF Core. `DbContext` is used directly in services.

### Dart
- `flutter analyze` must be clean (use `flutter_lints`).
- Immutable models with `copyWith`. Hand-written `fromJson` is fine; do not add code generation unless asked.
- No business logic in widgets; widgets read providers.

### Git
- Small, focused commits with conventional prefixes (`feat:`, `fix:`, `test:`, `docs:`, `chore:`).
- Never commit secrets, `bin/`, `obj/`, `build/`, `.dart_tool/`, or IDE folders.
- The demo JWT signing key in compose/appsettings.Development is clearly marked as demo-only.

---

## 14. Technical decisions document (`docs/DECISIONS.md`)

Must answer the assignment's four questions in plain, short language (the developer will edit it into his own words):

1. **What would I ideally clarify?** — Section 2 questions plus: existing identity provider/SSO, how vehicles connect today
   (protocol, network quality), latency expectations, data retention/compliance, which platforms the team uses, whether operators need alerts/push notifications.
2. **Assumptions and why** — table from Section 2, each with a one-line reason.
3. **Main components and why** — diagram (Mermaid) of Simulator → Ingest API → PostgreSQL → SignalR → Mobile;
   why a single API project; why SignalR (vs polling/SSE/MQTT to the phone); why Postgres; why server-side groups; why denormalized latest state + history table.
4. **What I left out or simplified** — commands to vehicles, refresh tokens, user/fleet management UI, push notifications,
   offline cache, retention/partitioning of telemetry, horizontal scaling (SignalR backplane e.g. Redis), HTTPS/TLS termination,
   rate limiting, device provisioning, map tile caching. For each, one line on how it would be done with more time.

Plus a short **"Known limitations / incomplete"** section, kept honest.

---

## 15. README requirements

- One-paragraph overview + architecture diagram link.
- Prerequisites with versions (Docker, .NET 10 SDK for running tests, Flutter stable, Android Studio/Xcode).
- Run backend: `docker compose up --build`; URLs (API, Swagger).
- Run mobile: exact `flutter run --dart-define=...` commands for Android emulator and iOS simulator.
- Demo accounts table.
- Running tests: backend (`dotnet test`, Docker must be running for Testcontainers) and mobile (`flutter test`).
- Demo scenarios to try:
  1. Log in as Tarsus operator → only Tarsus vehicles visible.
  2. `curl` another fleet's vehicle with that token → 404.
  3. Watch vehicles move live; open a vehicle and watch activity events appear.
  4. `docker compose stop simulator` → vehicles turn Offline within ~30 s; start it → back Online.
  5. `docker compose restart api` → app shows Reconnecting, recovers, data intact.
- Screenshots / video section (`docs/media/`).

---

## 16. Things NOT to do
- Do not add Redis, message brokers, Kubernetes, CQRS/MediatR, AutoMapper, or a generic repository.
- Do not add features outside Section 1 without asking.
- Do not use EF Core InMemory provider for tests.
- Do not let the client choose which SignalR groups it joins.
- Do not filter by permission in the mobile app only.
- Do not skip a failing test or weaken an assertion to make it pass. Report it instead.
