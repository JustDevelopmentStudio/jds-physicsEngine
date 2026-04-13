# jds-physicsEngine – Exports API

**Version:** 2.0  
**Dependencies:** `jds-advanceenvironment` (weather + time from GlobalState)

All exports are **client-side**. Use with `exports['jds-physicsEngine']:ExportName(args)`.

---

## Overview

The exports API unifies **physics**, **weather**, and **time** so other resources (HUDs, jobs, stamina, tire wear, etc.) can read physics state and weather/time in one place. Designed for future **team** and **player** overrides via options.

---

## Raw Physics State

| Export | Returns | Description |
|--------|---------|-------------|
| `GetRoadWetness()` | `number` (0..1) | Current road wetness from weather + decay |
| `GetWeatherGripModifier()` | `number` (0..1) | Weather-based grip modifier |
| `GetTireTemp()` | `number` (°C) | Simulated tire temperature |
| `GetTireGripModifier()` | `number` (0..1) | Tire temp → grip modifier |
| `GetVehicleGroundGrip(vehicle, roadWetness?)` | `number` (0..1) | Surface grip at vehicle position |
| `GetGroundGripAtPosition(x, y, z, roadWetness?)` | `number` (0..1) | Surface grip at world coords |
| `GetDamageGripModifier(vehicle)` | `number` (0..1) | Grip modifier from vehicle damage |
| `GetVehicleDamageSnapshot(vehicle?)` | `table` | Engine/body/tire health, grip mod |
| `GetTireWear()` | `number` (0..1) | Tire wear (0=new, 1=bald) |
| `GetAmbientTemp()` | `number` (°C) | Ambient temp (API or weather-based) |

---

## Weather + Time (from jds-advanceenvironment)

| Export | Returns | Description |
|--------|---------|-------------|
| `GetServerWeather()` | `string?` | Current weather name (e.g. `"RAIN"`, `"CLEAR"`) |
| `GetServerTime()` | `number, number` | `hour`, `minute` |
| `IsWeatherWet()` | `boolean` | True if rain/snow/blizzard |
| `GetWeatherTimeSnapshot()` | `table` | See below |

### GetWeatherTimeSnapshot()

```lua
local snap = exports['jds-physicsEngine']:GetWeatherTimeSnapshot()
-- snap.weather   : string
-- snap.hour      : number
-- snap.minute    : number
-- snap.isWet     : boolean
-- snap.blackout  : boolean
-- snap.timeFrozen: boolean
```

---

## Unified Physics Snapshot

### GetPhysicsSnapshot(vehicle?, options?)

Returns a single table combining physics, weather, and time. Ideal for HUDs and one-shot checks.

```lua
local snap = exports['jds-physicsEngine']:GetPhysicsSnapshot()
-- or: GetPhysicsSnapshot(vehicle)
-- or: GetPhysicsSnapshot(nil, { playerId = 1, teamId = 'police' })  -- future
```

| Field | Type | Description |
|-------|------|-------------|
| `roadWetness` | number | 0..1 |
| `surfaceGrip` | number | Surface μ at vehicle |
| `materialHash` | number? | Ground material hash |
| `weatherGripMod` | number | Weather modifier |
| `tireGripMod` | number | Tire temp modifier |
| `tireTemp` | number | Tire temp °C |
| `damageGripMod` | number | Damage grip modifier |
| `effectiveGrip` | number | surface × weather × tire × damage |
| `damage` | table? | `{ engineHealth, bodyHealth, burstTires, gripModifier }` when in vehicle |
| `weather` | string | Server weather name |
| `hour`, `minute` | number | Server time |
| `isWet` | boolean | Rain/snow active |
| `inVehicle` | boolean | Player in vehicle |
| `vehicle` | number? | Vehicle handle |
| `playerId` | number | Server ID (for team/player logic) |
| `teamId` | any? | From options, for future use |

### GetEffectiveGrip(vehicle?)

Shortcut for `effectiveGrip` only. Vehicle `nil` = current vehicle.

```lua
local grip = exports['jds-physicsEngine']:GetEffectiveGrip()
if grip < 0.5 then
    -- Low grip, show HUD warning
end
```

---

## Integration Hooks

| Export | Returns | Description |
|--------|---------|-------------|
| `UpdateRoadWetness()` | `number` | Manually update wetness (usually automatic) |
| `UpdateTireTemp(vehicle)` | `number?` | Manually update tire temp |
| `ResetTireTemp()` | - | Reset tire temp to ambient (e.g. pit stop) |

---

## Example: HUD Grip Display

```lua
-- In your HUD script
CreateThread(function()
    while true do
        Wait(500)
        local snap = exports['jds-physicsEngine']:GetPhysicsSnapshot()
        if snap.inVehicle then
            local grip = snap.effectiveGrip
            local wet = snap.roadWetness
            -- Update HUD elements
        end
    end
end)
```

---

## Example: Stamina / Job Logic (Weather + Time)

```lua
local wt = exports['jds-physicsEngine']:GetWeatherTimeSnapshot()
if wt.isWet then
    -- Heavier exertion in rain
end
if wt.hour >= 22 or wt.hour < 6 then
    -- Night shift logic
end
```

---

## Example: Team / Player Overrides (Future)

```lua
-- When ox_core or framework exposes team/job:
local snap = exports['jds-physicsEngine']:GetPhysicsSnapshot(nil, {
    teamId = 'racing_team',  -- could apply team-specific grip mods
})
```

---

## Resource Order

Ensure in `server.cfg`:
```cfg
ensure jds-advanceenvironment
ensure jds-physicsEngine
```
