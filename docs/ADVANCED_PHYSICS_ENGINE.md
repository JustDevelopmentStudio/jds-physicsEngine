# Advanced Physics Engine – GTA V / FiveM to Premium Level

**Version:** 1.0  
**Vision:** Bring GTA V/FiveM vehicle physics to Forza/sim-racing level by layering real-time temperature, road conditions, surface-specific grip, tire state, and suspension simulation on top of the RAGE engine.

---

## Table of Contents

0. [Exports API (for other scripts)](#exports-api)
1. [Overview](#1-overview)
2. [Data Sources](#2-data-sources)
3. [Complete Surface & Material Reference](#3-complete-surface--material-reference)
4. [Tire & Grip Model](#4-tire--grip-model)
5. [Suspension – Forza-Level Simulation](#5-suspension--forza-level-simulation)
6. [Road Conditions System](#6-road-conditions-system)
7. [Implementation Architecture](#7-implementation-architecture)
8. [Code Sketches](#8-code-sketches)
9. [Configuration Schema](#9-configuration-schema)
10. [Natives Reference](#10-natives-reference)
11. [Phase Plan](#11-phase-plan)
12. [Limitations & Workarounds](#12-limitations--workarounds)
13. [Appendix A: Handling.meta Traction](#appendix-a-handlingmeta-traction)
14. [Appendix B: Handling Flags](#appendix-b-handling-flags)
15. [References](#15-references)

---

## Exports API

For integrating with HUDs, jobs, stamina, tire wear, and other scripts, see **[EXPORTS.md](./EXPORTS.md)**. Key exports:

- `GetPhysicsSnapshot(vehicle?)` – unified physics + weather + time
- `GetWeatherTimeSnapshot()` – weather + time from jds-advanceenvironment
- `GetEffectiveGrip(vehicle?)` – surface × weather × tire grip
- `GetServerWeather()`, `GetServerTime()`, `IsWeatherWet()` – weather/time helpers
- Options: `{ playerId, teamId }` for future team-based overrides

---

## 1. Overview

| Layer | GTA V Default | Premium Target |
|-------|---------------|----------------|
| **Gravity** | Arcade float | True 9.8 m/s² |
| **Traction** | Static per surface | Temperature + surface ID + wear |
| **Suspension** | Basic springs | Comp/rebound, roll center, anti-roll, toe, camber |
| **Road Conditions** | Weather only | Wet/dry, puddles, oil, ice, decay |
| **Tire State** | None | Temp, pressure, wear |
| **Surface Grip** | Built-in | Per-surface lookup with modifiers |
| **Temperature** | Ignored | Ambient, tire, engine (simulated) |

---

## 2. Data Sources

### 2.1 Temperature

| Source | Method | Notes |
|--------|--------|-------|
| **Real-world API** | OpenWeatherMap / weatherapi.com | `main.temp`, `main.feels_like` (°C) |
| **Time of day** | `GetClockHours()` | Approximate ambient (e.g. 12–14h warmer, 4–6h cooler) |
| **Weather type** | `GetPrevWeatherTypeHashName()` | Rain/snow → typically lower ambient |
| **Tire temp** | Simulated | F(ambient, speed, RPM, braking, time) |
| **Engine bay** | Simulated | F(ambient, RPM, load, cooling time) |

**Formula (tire temp):**
```
dT = k1 * speed * dt + k2 * RPM * dt + k3 * IsBraking * dt - k4 * (T - Ambient) * dt
TireTemp = clamp(TireTemp + dT, Ambient, 150)
```

**Recommended:** Sync ambient from weather API; compute tire/engine temps client-side every frame or at 50–100 ms intervals.

### 2.2 Weather – Complete Hash List

| Weather Name | Hash (hex) | Condition | Road Wetness | Grip Modifier |
|--------------|------------|-----------|--------------|---------------|
| EXTRASUNNY | 0x97AA0A79 | Dry | 0 | 1.0 |
| CLEAR | 0x36A83D84 | Dry | 0 | 1.0 |
| CLOUDS | 0x30FDAF5C | Dry | 0 | 1.0 |
| OVERCAST | 0xBB898D2D | Dry / damp | ~0.05 | 0.98 |
| RAIN | 0x54A69840 | Wet | 0.5–0.7 | 0.6–0.75 |
| THUNDER | 0xB677829F | Heavy wet | 0.8–1.0 | 0.5–0.6 |
| CLEARING | (varies) | Drying | 0.2–0.5 | 0.7–0.9 |
| NEUTRAL | (varies) | Neutral | 0 | 1.0 |
| SNOW | 0xefb6eff6 | Snow/ice | 1.0 | 0.3–0.5 |
| BLIZZARD | (varies) | Heavy snow | 1.0 | 0.25–0.4 |
| FOGGY | 0xAE737644 | Damp/fog | ~0.1 | 0.95 |
| XMAS | 0xAAC9C895 | Snow variant | 1.0 | 0.3–0.5 |
| HALLOWEEN | (varies) | Dry | 0 | 1.0 |

**Natives:**
- `GetPrevWeatherTypeHashName()` → current weather
- `GetNextWeatherTypeHashName()` → target during transition
- `SetWeatherTypeNow(hash)` – instant
- `SetWeatherTypeOverTime(hash, timeInSec)` – smooth (max 15s)

### 2.3 Road Wetness Decay

```lua
-- After rain stops, wetness decays
wetnessDecayRate = 0.001  -- per second
minWetness = 0.0
maxWetness = 1.0

-- Per frame (dt in seconds):
if isRaining then
    roadWetness = min(maxWetness, roadWetness + 0.02 * dt)
else
    roadWetness = max(minWetness, roadWetness - wetnessDecayRate * dt)
end
```

---

## 3. Complete Surface & Material Reference

GTA V exposes material via `GetShapeTestResultIncludingMaterial()`. Full list from [DurtyFree Gist](https://gist.github.com/DurtyFree/b37463ea9bfd3089fab696f554509977):

### 3.1 Road Surfaces (with Grip μ dry / wet)

| Material | Hash | μ Dry | μ Wet | Category |
|----------|------|-------|-------|----------|
| Tarmac | 0x10DD5498 | 0.95 | 0.60 | Road |
| TarmacPainted | 0xB26EEFB0 | 0.92 | 0.58 | Road |
| TarmacPothole | 0x70726A55 | 0.88 | 0.55 | Road |
| RumbleStrip | 0xF116BC2D | 0.70 | 0.55 | Road |
| Concrete | 0x46CA81E8 | 0.92 | 0.58 | Road |
| ConcretePothole | 0x1567BF52 | 0.85 | 0.52 | Road |
| ConcreteDusty | 0xBF59B491 | 0.80 | 0.48 | Road |
| ConcretePavement | 0x78239B1A | 0.90 | 0.55 | Road |
| Stone | 0x2D9C1E0D | 0.80 | 0.45 | Road |
| Cobblestone | 0x2257A573 | 0.75 | 0.42 | Road |
| Brick | 0x61B1F936 | 0.78 | 0.44 | Road |
| BrickPavement | 0xBB9CA6D8 | 0.76 | 0.43 | Road |
| BreezeBlock | 0xC72165D6 | 0.72 | 0.40 | Road |
| MetalSolidRoadSurface | 0xD48AA0F2 | 0.65 | 0.38 | Road |
| StuntRampSurface | 0x8388FA6C | 0.90 | 0.55 | Road |

### 3.2 Loose / Off-Road Surfaces

| Material | Hash | μ Dry | μ Wet | Category |
|----------|------|-------|-------|----------|
| SandLoose | 0xA0EBF7E4 | 0.50 | 0.32 | Loose |
| SandCompact | 0x1E6D775E | 0.58 | 0.36 | Loose |
| SandWet | 0x363CBCD5 | 0.40 | 0.35 | Loose |
| SandTrack | 0x8E4D8AFF | 0.55 | 0.34 | Loose |
| SandDryDeep | 0x1E5E7A48 | 0.45 | 0.30 | Loose |
| SandWetDeep | 0x4CCC2AFF | 0.38 | 0.32 | Loose |
| SandstoneSolid | 0x23500534 | 0.70 | 0.42 | Loose |
| SandstoneBrittle | 0x7209440E | 0.62 | 0.38 | Loose |
| GravelSmall | 0x38BBD00C | 0.60 | 0.40 | Loose |
| GravelLarge | 0x7EDC5571 | 0.55 | 0.38 | Loose |
| GravelDeep | 0xEABD174E | 0.48 | 0.35 | Loose |
| GravelTrainTrack | 0x72C668B6 | 0.52 | 0.36 | Loose |
| DirtTrack | 0x8F9CD58F | 0.62 | 0.38 | Loose |
| MudHard | 0x8C31B7EA | 0.55 | 0.32 | Loose |
| MudPothole | 0x129ECA2A | 0.48 | 0.28 | Loose |
| MudSoft | 0x61826E7A | 0.42 | 0.25 | Loose |
| MudDeep | 0x42251DC0 | 0.35 | 0.22 | Loose |
| Marsh | 0xD4C07E2 | 0.32 | 0.20 | Loose |
| MarshDeep | 0x5E73A22E | 0.28 | 0.18 | Loose |
| Soil | 0xD63CCDDB | 0.58 | 0.35 | Loose |
| ClayHard | 0x4434DFE7 | 0.55 | 0.30 | Loose |
| ClaySoft | 0x216FF3F0 | 0.45 | 0.25 | Loose |
| Rock | 0xCDEB5023 | 0.70 | 0.42 | Loose |
| RockMossy | 0xF8902AC8 | 0.55 | 0.35 | Loose |
| Grass | 0x4F747B87 | 0.52 | 0.38 | Loose |
| GrassShort | 0xB34E900D | 0.48 | 0.36 | Loose |
| GrassLong | 0xE47A3E41 | 0.42 | 0.32 | Loose |
| Hay | 0x92B69883 | 0.40 | 0.30 | Loose |
| Bushes | 0x22AD7B72 | 0.35 | 0.28 | Loose |
| Leaves | 0x8653C6CD | 0.30 | 0.22 | Loose |
| Woodchips | 0xED932E53 | 0.45 | 0.28 | Loose |

### 3.3 Ice & Snow

| Material | Hash | μ Dry | μ Wet | Category |
|----------|------|-------|-------|----------|
| Ice | 0xD125AA55 | 0.18 | 0.12 | Ice |
| IceTarmac | 0x8CE6E7D9 | 0.20 | 0.14 | Ice |
| SnowLoose | 0x8C8308CA | 0.35 | 0.25 | Snow |
| SnowCompact | 0xCBA23987 | 0.40 | 0.28 | Snow |
| SnowDeep | 0x608ABC80 | 0.30 | 0.22 | Snow |
| SnowTarmac | 0x5C67C62A | 0.38 | 0.26 | Snow |

### 3.4 Fluids & Hazards

| Material | Hash | μ | Category |
|----------|------|---|----------|
| Water | 0x19F81600 | 0.08 | Fluid |
| Puddle | 0x3B982E13 | 0.15 | Fluid |
| Oil | 0xDA2E9567 | 0.12 | Hazard |
| Petrol | 0x9E98536C | 0.12 | Hazard |
| Blood | 0x4FE54A | 0.20 | Hazard |

### 3.5 Metal, Wood, Other

| Material | Hash | μ Dry | μ Wet |
|----------|------|-------|-------|
| MetalSolidMedium | 0xEA34E8F8 | 0.60 | 0.35 |
| MetalGrille | 0xE699F485 | 0.55 | 0.32 |
| MetalManhole | 0xD2FFA63D | 0.50 | 0.28 |
| WoodSolidSmall | 0xE82A6F1C | 0.62 | 0.38 |
| WoodFloorDusty | 0xD35443DE | 0.55 | 0.32 |
| Rubber | 0xF7503F13 | 0.75 | 0.55 |
| Default | 0x962C3F7B | 0.75 | 0.50 |

### 3.6 Fallback / Unknown

For any material hash not in the table, use:
- **Default grip:** μ_dry = 0.75, μ_wet = 0.50
- **Or** map to nearest category (e.g. Temp01–Temp30 → 0.70)

---

## 4. Tire & Grip Model

### 4.1 Tire Temperature (Simulated)

**Ranges:**
- **Cold (<60 °C):** μ × 0.85
- **Optimal (80–120 °C):** μ × 1.0
- **Overheated (>140 °C):** μ × 0.90

**Pseudocode:**
```lua
local ambientTemp = 20  -- from API or estimate
local heatRate = 0.5
local coolRate = 0.3
local dt = 0.05  -- 50ms

local speed = #GetEntityVelocity(veh)
local rpm = GetVehicleCurrentRpm(veh)
local isBraking = GetControlNormal(0, 72) > 0.1  -- brake

local heat = (speed/50 * 0.5 + rpm * 0.3 + (isBraking and 0.4 or 0)) * heatRate * dt
local cool = (tireTemp - ambientTemp) * coolRate * dt * 0.01

tireTemp = clamp(tireTemp + heat - cool, ambientTemp, 150)
```

### 4.2 Tire Wear (Optional)

- Simulate wear as a function of slip, braking, and distance
- **Wear 0%:** μ × 1.0
- **Wear 50%:** μ × 0.95
- **Wear 100%:** μ × 0.85

### 4.3 Effective Grip Formula

```
EffectiveGrip = BaseSurfaceGrip(materialHash)
              × lerp(μ_dry, μ_wet, roadWetness)
              × TireTempModifier(tireTemp)
              × TireWearModifier(wear)
              × WeatherGripModifier(weatherHash)
```

---

## 5. Suspension – Forza-Level Simulation

### 5.1 Main handling.meta Suspension Parameters

| Param | Role | Typical | Sim Target |
|-------|------|---------|------------|
| fSuspensionForce | Spring rate | 1.0–4.0 | Per-vehicle |
| fSuspensionCompDamp | Compression damping | 0.5–2.0 | Bump absorption |
| fSuspensionReboundDamp | Rebound damping | 0.5–2.0 | Pitch/roll control |
| fSuspensionUpperLimit | Bump travel (m) | 0.05–0.15 | Realistic |
| fSuspensionLowerLimit | Droop (m) | -0.1 – -0.2 | Realistic |
| fSuspensionRaise | Ride height offset | -0.05–0.05 | Fine tune |
| fSuspensionBiasFront | F/R balance | 0.5 | 0.45–0.55 |
| fAntiRollBarForce | Anti-roll | 0.2–1.5 | Body roll |
| fAntiRollBarBiasFront | F/R anti-roll | 0.5 | Balance |
| fRollCentreHeightFront | Roll center F (m) | 0.1–0.3 | Handling |
| fRollCentreHeightRear | Roll center R (m) | 0.1–0.3 | Handling |
| fCamberStiffnesss | Camber effect | 0–1.0 | Tire load |

### 5.2 CCarHandlingData (SubHandlingData)

| Param | Role | Notes |
|-------|------|-------|
| fToeFront | Toe angle front | value = degrees/45 |
| fToeRear | Toe angle rear | value = degrees/45 |
| fCamberFront | Camber front | value ≈ degrees/22.5 |
| fCamberRear | Camber rear | value ≈ degrees/22.5 |
| fCastor | Caster angle | 0.01 ≈ 1° |
| fMaxDriveBiasTransfer | Diff / slip | 0.5 = limited-slip feel |

### 5.3 What GTA V Can / Cannot Do

| Capability | Status |
|------------|--------|
| Static handling.meta | ✅ Full control |
| Per-vehicle tuning | ✅ |
| Runtime per-frame suspension | ❌ |
| Per-wheel load / deflection | ❌ |
| Surface grip via fTractionLossMult | ✅ Global modifier |

---

## 6. Road Conditions System

### 6.1 Wetness Model

```
roadWetness: 0 (dry) → 1 (fully wet)
GripInterpolation = lerp(μ_dry, μ_wet, roadWetness)
```

### 6.2 Hazard Detection

- **Oil / Petrol / Puddle / Water:** Use material hash directly; apply hazard μ
- **Blend:** If raycast hits multiple materials (e.g. tarmac + puddle), use minimum μ

### 6.3 Wheel-Raycast Strategy

- Raycast from each wheel position (or simplified: vehicle center + offsets)
- Use `GetVehicleWheelPosition` or bone positions
- Ray length: ~1.0 m down
- Flags: `1` (world) or `-1` (all)

---

## 7. Implementation Architecture

```
jds-resources/
├── config/
│   ├── physics.lua
│   ├── surfaces.lua       -- materialHash → μ_dry, μ_wet
│   └── weather.lua        -- weatherHash → wetness, grip mod
├── client/
│   ├── physics.lua
│   ├── surface_detection.lua
│   ├── tire_state.lua
│   ├── road_conditions.lua
│   └── grip_application.lua
├── data/
│   └── surface_grip.json
└── docs/
    └── ADVANCED_PHYSICS_ENGINE.md
```

### 7.1 Frame Loop

```
1. Get weather hash → road wetness + weather grip modifier
2. Raycast ground (4 wheels or center) → materialHash[]
3. Update tire temp (F(RPM, speed, braking))
4. For each wheel: EffectiveGrip = lookup(material) × wetMod × tempMod × wearMod
5. MinGrip = min(wheel grips)
6. Apply grip modifier (see 6.3 / 8.2)
```

---

## 8. Code Sketches

### 8.1 Surface Raycast (Lua)

```lua
function GetGroundMaterialAtPosition(x, y, z)
    local handle = StartShapeTestRay(x, y, z, x, y, z - 2.0, 1, 0, 0)
    local _, hit, _, _, materialHash, _ = GetShapeTestResultIncludingMaterial(handle)
    return hit and materialHash or nil
end
```

### 8.2 Grip Application (Workaround)

GTA V has no per-frame traction override. Options:

1. **SetVehicleHandlingFloat** (if available): Adjust `fTractionCurveMax` or `fTractionLossMult` periodically based on average surface grip.
2. **Control scaling:** Scale `SetControlNormal` for throttle/brake when grip &lt; threshold to reduce input and simulate slip.
3. **ApplyForceToEntity:** Apply corrective forces; can feel artificial.

**Recommended:** Use `SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionLossMult", baseValue * effectiveGripMod)` every 200–500 ms when surface changes significantly.

---

## 9. Configuration Schema

```lua
-- config/physics_advanced.lua
Config.PhysicsAdvanced = {
    gravityMs2 = 9.8,
    useEarthGravity = true,
    gravityLevel = 0,

    tireTemp = {
        enabled = true,
        heatRate = 0.5,
        coolRate = 0.3,
        optimalMin = 80,
        optimalMax = 120,
        coldModifier = 0.85,
        hotModifier = 0.90,
    },
    roadWetness = {
        rainAccumRate = 0.02,
        decayRate = 0.001,
    },
    surfaceDetection = {
        rayLength = 2.0,
        updateIntervalMs = 50,
    },
    gripApplication = {
        useHandlingOverride = true,
        updateIntervalMs = 200,
    },
}
```

---

## 10. Natives Reference

### 10.1 Physics & Handling

| Native | Purpose |
|--------|---------|
| SetGravityLevel(int) | 0=heaviest, 3=moon |
| SetVehicleGravityAmount(vehicle, float) | e.g. 9.8 |
| GetVehicleHandlingFloat(vehicle, "CHandlingData", field) | Read |
| SetVehicleHandlingFloat(vehicle, "CHandlingData", field, value) | Override |

### 10.2 Surface Detection

| Native | Purpose |
|--------|---------|
| StartShapeTestRay(x1,y1,z1, x2,y2,z2, flags, entity, p8) | Raycast |
| GetShapeTestResultIncludingMaterial(handle) | hit, endCoords, surfaceNormal, materialHash, entityHit |
| GetVehicleWheelPosition(vehicle, wheelIndex, bool) | Wheel world pos |

### 10.3 Vehicle State

| Native | Purpose |
|--------|---------|
| GetEntityVelocity(entity) | Velocity vector |
| GetVehicleCurrentRpm(vehicle) | 0–1 |
| GetVehicleWheelSpeed(vehicle, wheelIndex) | Per-wheel |
| IsVehicleOnAllWheels(vehicle) | Ground contact |
| GetVehicleWheelHealth(vehicle, wheelIndex) | 0–1000 (integrity proxy) |
| GetVehicleHandbrake(vehicle) | Brake state |

### 10.4 Weather

| Native | Purpose |
|--------|---------|
| GetPrevWeatherTypeHashName() | Current weather |
| GetNextWeatherTypeHashName() | Target during transition |
| SetWeatherTypeNow(hash) | Instant |
| SetWeatherTypeOverTime(hash, time) | Smooth (max 15s) |

### 10.5 Controls

| Native | Purpose |
|--------|---------|
| GetControlNormal(inputGroup, control) | Throttle 71, Brake 72, etc. |
| DisableControlAction / EnableControlAction | Override inputs (for assist) |

---

## 11. Phase Plan

| Phase | Scope | Effort |
|-------|-------|--------|
| 1 | Surface detection + full materialHash lookup table | 1–2 days |
| 2 | Weather → road wetness + grip modifiers | 0.5–1 day |
| 3 | Tire temperature simulation | 1 day |
| 4 | Handling.meta tuning for sim feel (per-vehicle) | 2–3 days |
| 5 | Integration + grip application (SetVehicleHandlingFloat / control scaling) | 1–2 days |
| 6 | Real weather API + ambient temp sync | ✅ jds-advanceenvironment ([Renewed-Weathersync](https://github.com/Renewed-Scripts/Renewed-Weathersync)) |
| 7 | Optional: Tire wear, pressure simulation | 1 day |
| 8 | Optional: Handling flags (CF_ASSIST_TRACTION_CONTROL, CF_FIX_OLD_BUGS) | 0.5 day |

---

## 12. Limitations & Workarounds

| Limitation | Workaround |
|------------|------------|
| No native tire temp | Simulate client-side |
| No per-wheel grip | Use minimum of 4-wheel grip; apply globally |
| No runtime suspension | Pre-tune handling.meta |
| HandlingFloat may not exist | Fallback to control scaling |
| Surface hash may be 0 | Use default μ = 0.75 |
| Weather hash varies by build | Use string comparison or hash fallbacks |

---

## Appendix A: Handling.meta Traction

| Param | Role |
|-------|------|
| fTractionCurveMax | Peak grip before slip |
| fTractionCurveMin | Grip when sliding |
| fTractionCurveLateral | Slip angle / responsiveness |
| fTractionSpringDeltaMax | Sidewall lateral travel |
| fLowSpeedTractionLossMult | Burnout / launch |
| fTractionBiasFront | F/R grip split |
| fTractionLossMult | Sensitivity to surface grip differences (key for our system) |

---

## Appendix B: Handling Flags

### strHandlingFlags (relevant)

| HEX | Name | Effect |
|-----|------|--------|
| 0x8 | HF_HAS_RALLY_TYRES | Inverts grip behaviour (better off-road) |
| 0x20000000 | HF_TYRES_CAN_CLIP | Tire clip for bumps |
| 0x10000 | HF_LESS_SNOW_SINK | Less sink in snow |

### strAdvancedFlags (CCarHandlingData)

| HEX | Name | Effect |
|-----|------|--------|
| 0x2000 | CF_ASSIST_TRACTION_CONTROL | Drift / TC behaviour |
| 0x4000 | CF_ASSIST_STABILITY_CONTROL | Stability |
| 0x8000 | CF_ALLOW_REDUCED_SUSPENSION_FORCE | Stance / lowered |
| 0x4000000 | CF_FIX_OLD_BUGS | Bug fixes, tyre clip limits |

---

## 15. References

- [Renewed-Weathersync](https://github.com/Renewed-Scripts/Renewed-Weathersync) – weather + time sync (Phase 6, jds-advanceenvironment)
- [GTA V Collision Material Hashes](https://gist.github.com/DurtyFree/b37463ea9bfd3089fab696f554509977)
- [handling.meta – GTAMods Wiki](https://gtamods.com/wiki/Handling.meta)
- [FiveM Natives](https://docs.fivem.net/natives/)
- ox_target / ox_lib raycast: `GetShapeTestResultIncludingMaterial`
- Time cycle / Weather types: [GTAMods](https://gtamods.com/wiki/Time_cycle)
