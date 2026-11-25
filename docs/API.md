# API contract

Base URL: `http://localhost:8080`. JSON is camelCase; enums are strings. Errors are RFC 7807 ProblemDetails
(`application/problem+json`). Timestamps are ISO 8601; responses are always UTC.

All endpoints require `Authorization: Bearer <accessToken>` unless marked **anonymous**.

> Sections for ingestion (Phase 3) and the SignalR hub (Phase 4) are added when those are built.

## Health

### `GET /health` — anonymous
`200 Healthy` when the API runs and the database answers; `503 Unhealthy` otherwise.

## Auth

### `POST /api/auth/login` — anonymous, rate limited
```json
{ "email": "admin@demo.local", "password": "Admin123!" }
```
- `200` → `{ "accessToken": "...", "expiresAt": "...", "user": { "id", "email", "displayName", "role" } }`
- `401` → `"Invalid email or password."` (same for unknown email and wrong password)
- `400` → missing fields
- `429` → too many attempts from this IP (default 5 per 60 s, `RateLimiting:Login:*`)

Email is trimmed and case-insensitive. The token is valid for 60 minutes; there are no refresh tokens.

### `GET /api/auth/me`
`200` → `{ "user": { "id", "email", "displayName", "role" }, "fleets": [ { "id", "name", "region" } ] }`

## Fleets

### `GET /api/fleets`
Fleets the caller can see, sorted by name: `[ { "id", "name", "region" } ]`.
Admin: all fleets. Operator: assigned fleets only.

## Vehicles

### Access rule
A user only sees vehicles in their fleets. A vehicle outside the caller's scope is answered exactly like a vehicle that
does not exist: **`404` "Vehicle not found."** on detail, telemetry and activity. This avoids revealing which vehicles
exist.

### `GET /api/vehicles?fleetId=&status=`
Vehicles in scope with their latest state, sorted by fleet name, then vehicle name.

| Param | Type | Notes |
|---|---|---|
| `fleetId` | guid, optional | A fleet outside the caller's scope returns `200 []` (same as an empty fleet). |
| `status` | `Moving` \| `Idle` \| `Charging` \| `Fault` \| `Offline`, optional | Unknown value → `400`. |

`VehicleDto`:
```json
{
  "id": "guid", "fleetId": "guid", "fleetName": "Tarsus Field Ops",
  "name": "TR-01", "model": "AgriRover X", "serialNumber": "SN-0001",
  "status": "Moving", "connectivity": "Online",
  "latitude": 36.92, "longitude": 34.89,
  "speedKmh": 12.4, "headingDeg": 270, "batteryPct": 76,
  "lastTelemetryAt": "2026-11-26T10:00:00Z",
  "lastSeenAt": "2026-11-26T10:00:01Z"
}
```
- `status` is `Offline` when `connectivity` is `Offline`, otherwise the state last reported by the vehicle.
- A vehicle that never sent telemetry has `status: "Offline"` and `null` location, metrics and timestamps.
- `lastTelemetryAt` is the vehicle's clock; `lastSeenAt` is the server's clock when the last sample arrived.

### `GET /api/vehicles/{id}`
One `VehicleDto`, or `404`.

### `GET /api/vehicles/{id}/telemetry?from=&to=&limit=`
History samples, **newest first**.

| Param | Default | Rules |
|---|---|---|
| `to` | now | ISO 8601. Any offset is accepted and converted to UTC. URL-encode `+` as `%2B`. |
| `from` | `to` − 1 hour | Must not be later than `to` → else `400`. |
| (range) | | `to` − `from` **must not exceed 7 days** → else `400`. Request several windows for longer periods. |
| `limit` | 500 | `< 1` → `400`. Values above **2000** are clamped to 2000. |

Both bounds are inclusive and compare against the vehicle's `recordedAt`.

```json
{
  "from": "2026-11-26T09:00:00Z",
  "to": "2026-11-26T10:00:00Z",
  "items": [
    { "sequence": 1042, "recordedAt": "...", "receivedAt": "...", "latitude": 36.92, "longitude": 34.89,
      "speedKmh": 12.4, "headingDeg": 270, "batteryPct": 76, "state": "Moving" }
  ]
}
```
`from`/`to` are the window actually applied (after defaults).

### `GET /api/vehicles/{id}/activity?before=&limit=`
Activity events, **newest first**, with cursor pagination.

| Param | Default | Rules |
|---|---|---|
| `before` | (none: newest page) | Opaque cursor: pass back a `nextBefore` value unchanged. Malformed → `400`. |
| `limit` | 50 | `< 1` → `400`. Values above **200** are clamped to 200. |

```json
{
  "items": [
    { "id": 981, "vehicleId": "guid", "type": "StateChanged", "occurredAt": "...", "details": "Idle → Moving" }
  ],
  "nextBefore": "NjM5MDAwMDAwMDAwMDAwMDBfOTgx"
}
```
- `type`: `CameOnline` | `WentOffline` | `StateChanged` | `LowBattery` | `FaultRaised`.
- `nextBefore` is `null` on the last page.
- Order is (`occurredAt` desc, `id` desc). The cursor holds both, so events with the same timestamp are never skipped
  or repeated across pages.
