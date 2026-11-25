# API contract

Base URL: `http://localhost:8080`. JSON is camelCase; enums are strings. Errors are RFC 7807 ProblemDetails
(`application/problem+json`). Timestamps are ISO 8601; responses are always UTC.

All endpoints require `Authorization: Bearer <accessToken>` unless marked **anonymous**.

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
  "lastSeenAt": "2026-11-26T10:00:01Z",
  "updatedAt": "2026-11-26T10:00:01.123456Z"
}
```
- `updatedAt` is the server time of the last change to this vehicle (new sample or going Offline). It **strictly
  increases** per vehicle, so it is the ordering key for clients: when two copies of the same vehicle meet (a live
  `VehicleUpdated` and a REST snapshot), keep the one with the greater `updatedAt` and ignore the other. Do not order by
  `lastTelemetryAt`: going Offline does not change it.
- `status` is `Offline` when `connectivity` is `Offline`, otherwise the state last reported by the vehicle.
- `connectivity` is decided by the server: a vehicle with no telemetry for **30 s** is marked `Offline`. The check runs
  every 5 s, so a vehicle that stops reporting shows as `Offline` **30–35 s** after its last sample
  (`Telemetry:OfflineThresholdSeconds`, `Telemetry:OfflineCheckIntervalSeconds`).
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

## Ingestion (vehicles → API)

### `POST /api/ingest/telemetry` — device key
Authenticated with header **`X-Device-Key: <key>`**, not a user token. The key identifies the vehicle; the body cannot
choose which vehicle it writes to (a `vehicleId` field is ignored). A user JWT is not accepted here, and a device key
is not accepted on any other endpoint.

```json
{
  "sequence": 1042,
  "recordedAt": "2026-11-26T10:00:00Z",
  "latitude": 36.92, "longitude": 34.89,
  "speedKmh": 12.4, "headingDeg": 270, "batteryPct": 76,
  "state": "Moving"
}
```

| Field | Rule |
|---|---|
| all fields | required |
| `sequence` | ≥ 0, increasing per vehicle; `(vehicle, sequence)` is unique |
| `recordedAt` | device clock; not more than 5 minutes in the future |
| `latitude` | [-90, 90] |
| `longitude` | [-180, 180] |
| `speedKmh` | ≥ 0 |
| `headingDeg` | [0, 360) |
| `batteryPct` | [0, 100] |
| `state` | `Moving` \| `Idle` \| `Charging` \| `Fault` |

| Response | Meaning |
|---|---|
| `202 { "duplicate": false }` | Stored. |
| `200 { "duplicate": true }` | This sequence was already stored; nothing changed. Safe result of a retry. |
| `400` ProblemDetails | Validation failed. Do not retry unchanged. |
| `401` ProblemDetails | Missing or unknown device key. |
| `503` ProblemDetails | Concurrent update of the vehicle; retry the same sample (it is never stored twice). |

Processing rules:
- Every stored sample is kept in history and refreshes `lastSeenAt`; an `Offline` vehicle becomes `Online`
  (`CameOnline` event).
- Only a sample newer than the current latest (`recordedAt`) updates the latest state. Late samples are history only.
- Events (only when the latest state is updated), all timestamped with server time:
  - `StateChanged` when the state differs from the previous sample (not on a vehicle's first sample)
  - `FaultRaised` when the state changes into `Fault`
  - `LowBattery` when the battery drops from ≥ 20 % (or unknown) to below 20 %; again only after it recovers to ≥ 20 %
- Real-time updates (`VehicleUpdated`, `ActivityRaised`) are sent only after the data is committed.

## Real-time (SignalR)

### Hub `/hubs/fleet`
- **Auth:** user JWT only. Pass it as the `access_token` query parameter (what SignalR clients do for WebSockets) or
  as an `Authorization: Bearer` header. The query parameter is accepted **only** on `/hubs/fleet`. A device key cannot
  connect. No or invalid token → `401` on negotiate.
- **Protocol:** JSON with the same settings as the REST API: camelCase properties, enums as strings.
- **Server → client only.** There are no methods a client can call.
- **Groups are decided by the server** when the connection opens: one group per fleet the user can see (admin: all;
  operator: assigned fleets). A user with no fleets stays connected and receives nothing. If a user's access changes,
  it applies on their next connection.
- **Token expiry closes the connection** (at the token's `exp`). The client should log in again (there are no refresh
  tokens) and reconnect.

### Messages

| Method | Payload | Sent when |
|---|---|---|
| `VehicleUpdated` | `VehicleDto` (same as `GET /api/vehicles/{id}`) | After a telemetry sample is stored, and when a vehicle goes Offline |
| `ActivityRaised` | `{ "id", "vehicleId", "type", "occurredAt", "details" }` (same as an activity item) | When an activity event is created |

Each message goes only to the group of the vehicle's fleet, and only after the change is committed.
Messages are not replayed: after a reconnect, re-fetch `GET /api/vehicles` (and the open vehicle's activity) to catch
up on anything missed while disconnected.
