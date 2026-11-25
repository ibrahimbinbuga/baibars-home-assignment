# Technical decisions — running notes

> Working notes collected during development. Phase 7 turns this into the final document
> (the four questions from CLAUDE.md Section 14). Keep entries short: decision + why.

## Hosting & configuration
- **No HTTPS inside the container.** The API listens on plain HTTP 8080 and has no `UseHttpsRedirection`/HSTS.
  In production TLS is terminated by a reverse proxy / load balancer in front of the API.
- **Compose runs as `Production`, demo features are flags.** `ASPNETCORE_ENVIRONMENT=Production` means no developer
  exception page (no stack traces to clients). Swagger and seeding are turned on with explicit flags
  (`Swagger:Enabled`, `Seed:Enabled`), off by default in `appsettings.json`.
- **Demo secrets in compose.** The JWT signing key, DB password and device keys in `docker-compose.yml` /
  `config/devices.json` are demo-only. Production would use a secret store (e.g. environment from a vault).
- **Fail fast on bad config.** Options are validated at startup (`ValidateOnStart`): e.g. a JWT signing key shorter
  than 32 bytes (HS256 minimum) stops the app instead of issuing weak tokens.
- **`GSS Encryption Mode=Disable` in every connection string.** Npgsql otherwise tries to load the Kerberos library
  (`libgssapi_krb5`), which the `aspnet` image doesn't ship, and logs a harmless but alarming error. We don't use
  Kerberos, so turning it off is cleaner than installing a library we don't need.
- **Postgres published on host port 5433** so `dotnet run` (appsettings.Development) can use the compose database
  without clashing with a local Postgres on 5432.

## Data
- **Migrations at startup** (hosted service, before the server accepts requests). Fine for a single instance.
  TODO: with several instances they would race to apply the same migration; production would run migrations as a
  separate deploy step (EF migration bundle / pipeline job). The seeder has the same race: two instances could both
  see "no users" and the second would fail on the unique email index. Seeding would also move to that one-off step
  (and in production there is no demo seed at all).
- **Enums stored as text** so the database is readable without the code.
- **`xmin` as concurrency token on `Vehicle`** (Postgres system column, no extra column).
- **Seeder is idempotent** (skips if any user exists) and writes everything in one `SaveChanges` (one transaction).
- **Entity named `VehicleFleet`**, not `Fleet`: a type named `Fleet` clashes with the root namespace `Fleet`.
  Table and API still say "fleet".
- **Single `config/devices.json`** is the source for both the seeder (stores hashes) and the simulator (sends keys).
- **`config/devices.json` contains demo-only device keys, committed on purpose** so `docker compose up` works from a
  clean clone. In production each device is provisioned individually and keys never live in the repo.
  (TODO: same line in README, Phase 7.)
- **TODO README (Phase 7):** state honestly that the app was verified end-to-end on the iOS simulator; Android builds
  (`flutter build apk --debug`) but was not run on an emulator.
- **TODO README (Phase 7):** with Flutter 3.44.3 + Xcode 27.2, `flutter build ios --simulator` fails in Flutter's own
  framework check (it calls `lipo -verify_arch x86_64 arm64`, which Xcode 27's `lipo` no longer accepts). Use
  `flutter run -d <simulator>` (builds only the simulator's architecture). Not a project issue; no SDK patch.

## Auth
- **Device keys hashed with SHA-256 (unique index), not BCrypt.** Device keys are 256-bit random secrets, not
  human passwords, so brute force is not realistic and a slow salted hash adds nothing. A deterministic hash lets
  ingestion find the vehicle from the key with one indexed lookup; a salted hash cannot be looked up, and BCrypt
  would cost ~100 ms on every telemetry sample.
- **User passwords hashed with BCrypt** (work factor 11).
- **Login does not reveal whether an email exists**: same 401 body for both cases, and an unknown email still runs
  one `BCrypt.Verify` against a dummy hash so response time is similar.
- **Email normalized** (trim + lowercase) on login and when stored.
- **JWT claims kept short** (`MapInboundClaims = false`): `sub`, `email`, `role` as in the token.
- **Role is read from the token**, so a role change applies at the next login (60-minute tokens, no refresh tokens).
- **Fallback authorization policy**: every endpoint requires a logged-in user unless marked `[AllowAnonymous]`
  (login, `/health`, OpenAPI document). A new endpoint can't be exposed by forgetting an attribute.
- **Login rate limit**: built-in ASP.NET Core rate limiter, fixed window per client IP, on `POST /api/auth/login`
  only (`RateLimiting:Login:*`, default 5 per 60 s), 429 as ProblemDetails.
  Behind a reverse proxy the client IP would come from `X-Forwarded-For` (`UseForwardedHeaders` with the proxy
  configured as trusted); without that, every client would share the proxy's IP and one limit.

## Vehicles API
- **Access check lives in one place.** `VehicleQueryService` starts every vehicle query from
  `IVehicleAccessService.ScopeVehicles`; controllers never filter. Out of scope and nonexistent give the same 404
  (A10). A `fleetId` filter is applied *after* scoping, so an out-of-scope fleet returns `200 []` and can't be used
  to probe which fleets exist.
- **One status expression.** `VehicleProjections.ToDto` is the only place the user-facing status is derived. The
  `?status=` filter runs on the projected DTO (EF translates a filter after a member-init projection), so the list and
  the filter can't disagree.
- **Read queries project straight to DTOs** (`AsNoTracking` + `Select`): one SQL statement per request, `fleetName`
  via a join, no `Include`.
- **Telemetry window capped at 7 days** (400 above that) and `limit` clamped to 2000: bounds the cost of one request.
  `limit < 1` is a 400 rather than silently becoming 1.
- **Activity uses keyset pagination with an opaque cursor** over (`OccurredAt`, `Id`), not offset paging (stable while
  new events arrive) and not a bare timestamp (events created in one ingestion share a timestamp and would be skipped
  at page boundaries). The cursor truncates to microseconds, Postgres' `timestamptz` precision, so it compares equal
  to stored values. It is not signed: a modified cursor can only move within the caller's own scoped data, and a
  malformed one is a 400.
- **Timestamps from query strings are converted to UTC** before querying (Npgsql only accepts UTC for `timestamptz`).

## Ingestion & offline detection
- **Duplicates: `INSERT … ON CONFLICT ("VehicleId", "Sequence") DO NOTHING`, not catching error 23505.** A repeated
  sample is a normal event (device retries after a timeout), not an error. With `ON CONFLICT` a duplicate is just
  "0 rows inserted": no exception, Postgres logs no `ERROR` line per duplicate, and the transaction stays usable, so
  the code is a straight line. It is still race-safe (the unique index decides). Cost: one hand-written SQL statement,
  kept in one method and covered by the duplicate tests.
- **Device authentication is its own scheme** (`DeviceKey` authentication handler) next to JWT. User tokens can't
  ingest; device keys can't read user endpoints; the vehicle id comes only from the key.
- **One transaction per sample**, `xmin` as optimistic concurrency token on the vehicle row. On a conflict the whole
  attempt is rolled back, the vehicle is re-read and the attempt is retried once; a second conflict returns 503 and the
  device retries the same sample (idempotent by sequence). Conflicts are rare (one sender per vehicle); the realistic
  source is the offline detector writing the same row.
- **Offline detection vs. ingestion race.** The detector reads stale vehicles, then writes each one with the `xmin` it
  read. If a sample arrived in between, the row changed, the update matches nothing, and that vehicle is skipped:
  it just reported in. Each vehicle is its own `SaveChanges`, so one conflict doesn't undo the others.
- **Offline window 30–35 s**: threshold 30 s, check every 5 s. A shorter interval tightens the window at the cost of
  more queries (one indexed query per pass).
- **Broadcasts only after commit**, never inside the transaction, so clients never see data that might be rolled back.
  The pushed `VehicleDto` is re-read with the same projection as `GET /vehicles/{id}`. A failed broadcast is logged
  and not retried: the data is safe, and clients re-fetch the snapshot on reconnect.
- **Event rules**: `FaultRaised` only when entering Fault (a 20 s fault = 1 event, not 10); no `StateChanged` on the
  first sample (`CameOnline` covers it); `LowBattery` on crossing below 20 %, re-armed after recovering.
- **All event timestamps are server time.** Device clocks drift; one clock keeps the activity order and the cursor
  consistent. The device time is kept in `TelemetryRecord.RecordedAt`.
- **Clock-skew guard**: `recordedAt` more than 5 min in the future is rejected, otherwise a device with a fast clock
  would block newer real samples from becoming the latest state.

## Simulator
- **Separate process calling the real ingest endpoint** with each vehicle's key, so it exercises the same path a real
  vehicle would; stopping it demonstrates offline detection.
- **Sequence starts at the current Unix time in ms**, +1 per sample. A real device keeps its counter in flash; with an
  in-memory counter starting at 1, a restarted simulator would only send duplicates and vehicles would never come back
  Online.
- **Plain `HttpClient` with a manual retry loop** (1, 2, 4, 8, max 10 s) for network errors, 5xx and 429, resending the
  same sample. No resilience library: the logic is ~20 lines and easy to read.
- **Options validated with `Validator.TryValidateObject`** instead of `ValidateDataAnnotations()`, which would need one
  more package in the simulator.
- **`SN-0004` drops out for 45 s every 3 minutes** to show offline detection without touching Docker.

## Logging
- Single-line console logs with timestamps, so `docker compose logs -f` is readable.
- API: per-sample ingestion at Debug; activity events (CameOnline/WentOffline/StateChanged/…) at Information;
  503 after retries at Warning. EF Core and ASP.NET Core framework logs at Warning (migrations at Information).
- Simulator: each send at Debug; startup, state changes, dropout start/end at Information; retries at Warning;
  rejected samples at Error.

## Ordering updates on the client
- **`Vehicle.UpdatedAt` (server time) is the per-vehicle ordering key**, set on every write to the vehicle row
  (ingestion and offline detection) and exposed as `updatedAt` on REST and the hub. `lastTelemetryAt` doesn't work:
  going Offline doesn't change it, and a REST snapshot read *before* the Offline flip but arriving *after* the live
  Offline update would have the same `lastTelemetryAt` and flip the vehicle back to Online.
- **Strictly increasing per vehicle**: truncated to microseconds (Postgres precision, so clients compare exactly what
  is stored) and at least 1 µs after the previous value, even within one microsecond or if the clock steps back.
  The `xmin` token already serializes writers per vehicle, so "previous" is always the committed value.
- Clients keep the copy with the greater `updatedAt` and ignore equal or older ones, for live updates and REST
  snapshots alike.

## Real-time (SignalR hub)
- **Strongly typed hub (`Hub<IFleetClient>`) with no client → server methods.** Group membership is decided in
  `OnConnectedAsync` from `IVehicleAccessService`, the same rule as REST. A client cannot ask to join a fleet, so the
  real-time channel can't leak data across fleets. Access changes apply on the next connection (acceptable for the
  demo; production would remove a user from groups when their access is revoked).
- **Sends go to `fleet:{fleetId}` groups only**, through `IHubContext<FleetHub, IFleetClient>` behind
  `IFleetBroadcaster`, after commit.
- **Same JSON settings for REST and SignalR** (`JsonConfiguration.Apply`), so the app parses one `VehicleDto` shape.
- **Hub accepts only the JWT scheme.** Device keys can't connect.
- **`access_token` query parameter accepted only on `/hubs/fleet`.** WebSocket clients can't always set headers; on
  every other path a token in the URL is ignored, so tokens don't spread into URLs.
- **Tokens in the hub URL are not logged.** Checked: ASP.NET Core request logs (which include the query string) are
  at Information, and the `Microsoft.AspNetCore` category is configured at Warning; SignalR/connection/Kestrel logs
  that mention connections are Debug/Trace. After a WebSocket session on compose, the API logs contained no
  `access_token`, `/hubs/` or JWT text. If request logging is ever turned on, the query string must be redacted
  first. A reverse proxy in front would need the same care.
- **`CloseOnAuthenticationExpiration = true`.** Without it an open connection keeps receiving data after the JWT
  expires. It closes at the token's `exp`: JwtBearer copies `exp` into the authentication properties and the
  connection layer checks it about once per second. `ClockSkew` (30 s) only applies when a token is validated, so it
  does not extend an open connection (a test with a 3 s token closes in ~5 s, well under the skew). The app then has
  to log in again (no refresh tokens) and reconnect.
- **Tests use long polling** through the in-memory TestServer (WebSockets there need extra setup). Negotiate, auth,
  groups and the JSON protocol are the same; the compose smoke test covered real WebSockets.

## Mobile app (foundation)
- **Riverpod 3 without code generation**, plain `Notifier`/`AsyncNotifier`/`Provider`. Automatic provider retry is
  turned off: errors are shown with an explicit retry, and retrying a 401/404 only repeats the failure.
- **No router package.** The home screen follows the auth state (login vs. app), so any logout lands on login.
  Revisit if the 5b design needs deep links or nested navigation.
- **One `ApiClient` (dio)** that adds the token and turns every failure into a typed `ApiException` built from the
  server's ProblemDetails. A 401 logs out, **except on `POST /api/auth/login`**, where 401 means wrong credentials and
  429 means rate-limited.
- **Session in secure storage** (Keychain / Android Keystore via `flutter_secure_storage`): token, `expiresAt` and the
  user. The app restores without a network call; an expired token on start goes to login with "session expired",
  and a timer logs out when `expiresAt` passes while the app is open. Relies on the device clock (the server's
  30 s skew covers small drift; a badly wrong clock just causes an earlier/later logout).
- **Unknown enum values never crash**: status, connectivity, state, activity type and role have an explicit `unknown`,
  so a newer API can add values without breaking older app versions.
- **Client-side filtering over the full list**: the list state holds every vehicle the user can see (already scoped by
  the server), filters are a view on top. Live updates can then always be applied by id. Server-side filter params
  are still available in the repository.
- **Ordering by `updatedAt`** (see "Ordering updates on the client"): live updates and REST snapshots both keep the
  strictly newer copy per vehicle. A snapshot decides which vehicles are listed.
- **Cleartext HTTP only for dev hosts**: Android `network_security_config` allows it only for `10.0.2.2` and
  `localhost` (everything else HTTPS-only); iOS uses `NSAllowsLocalNetworking`, which allows plain HTTP to local
  addresses only. A production build would use an HTTPS API and need neither.
- **iOS deployment target 15.0** (template had 13.0, which Xcode 27 rejects).
