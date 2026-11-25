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
