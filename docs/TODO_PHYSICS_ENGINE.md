# jds-physicsEngine – TODO & Roadmap

**Goal:** Make this the best realistic physics engine for FiveM.  
**Last updated:** 2025

---

## ✅ DONE (Implemented)

### Core Physics
- [x] **True Earth gravity** (9.8 m/s²) for world and vehicles
- [x] **Player movement** – sprint/swim multipliers, stamina tweaks
- [x] **Vehicle gravity** – proper SI units for player-driven vehicles

### Surface & Traction
- [x] **Surface detection** – raycast ground → material hash lookup
- [x] **60+ surfaces** – tarmac, gravel, mud, grass, ice, snow, oil, etc.
- [x] **Dry/wet grip** (μ) per material
- [x] **Road wetness** – rain/snow accumulation, decay when dry
- [x] **Weather grip modifier** – per-weather (RAIN, SNOW, THUNDER, etc.)
- [x] **fTractionCurveMax** handling override based on effective grip

### Tire Model
- [x] **Tire temperature** – heat from speed/RPM/braking, cool from ambient
- [x] **Cold tire penalty** (<60°C) – reduced grip
- [x] **Hot tire penalty** (>140°C) – greasy, reduced grip
- [x] **Optimal band** 80–120°C
- [x] **Ambient from time of day** – 6h cold, 14h warm

### Vehicle Class Rules
- [x] **Bikes** – extra grip, skip cold-tire penalty
- [x] **Heavy/offroad** – grip caps, mass damping
- [x] **Launch smoothing** – avoid burnout → instant snap-grip

### Vehicle Damage Model (NEW)
- [x] **Impact detection** – velocity-delta based collision detection
- [x] **Engine damage** – scales with impact severity and speed
- [x] **Body damage** – scales with impact
- [x] **Tire blowouts** – chance at high speed + damage
- [x] **Performance degradation** – grip penalty from engine/body/tire damage
- [x] **Class multipliers** – bikes/trains/planes tuned differently
- [x] **SetVehicleEngineCanDegrade** – realistic engine wear
- [x] **SetVehicleUndriveable** – when engine critically damaged

### Phase 6: Per-Wheel & Tire Wear
- [x] **Per-wheel surface detection** – `useAllWheels` config, raycast 4 wheels, min grip
- [x] **Config: rayLength** – from `surfaceDetection.rayLength`
- [x] **Tire wear** – from slip, braking, distance; grip drop at high wear
- [x] **GetTireWear**, **ResetTireWear**

### Phase 7: Damage Polish
- [x] **SetVehicleDamage** – localized damage at impact point (front/rear)
- [x] **Per-wheel health** – GetVehicleWheelHealth, SetVehicleWheelHealth, affects grip
- [x] **Visual deformation** – enabled by default (no SetVehicleDeformationFixed)

### Phase 8: Ambient & Sync
- [x] **Real ambient temp** – OpenWeatherMap API (optional), fallback from weather+time
- [x] **GetAmbientTemp** – from GlobalState or weather-based
- [x] **Multiplayer damage sync** – server broadcasts, other clients apply

### Phase 9: Polish
- [x] **Restore handling on ownership change** – isNetworkOwner check, reset when another player takes over

### Phase 10: Damage-to-Performance (Vehicle Performs Like It Looks)
- [x] **Engine damage** → reduced power (fInitialDriveForce), top speed, rev response
- [x] **Body damage** → suspension degradation (softer springs, bouncy damping)
- [x] **Body damage** → geometry (camber/toe bend from bent frame)
- [x] **Body damage** → steering lock reduction, brake force/bias
- [x] **Tire damage** → slide grip (fTractionCurveMin), F/R bias shift (pulls to one side)
- [x] **Active camber/toe** → dynamic from steering, brake, throttle, speed
- [x] **Cornering camber** → load transfer simulation, affects grip in turns
- [x] **Brake dive / accel squat** → toe + camber change under braking/throttle
- [x] **Speed-based steering reduction** → stability at high speed

### Heavy Off-Road / Trophy Trucks Fix
- [x] **Grip floor on loose surfaces** – min 0.55 effectiveMod on dirt/sand
- [x] **Skip cold tire penalty** – launch like bikes
- [x] **fLowSpeedTractionLossMult** – reduced burnout at launch
- [x] **Rally tyres flag** – HF_HAS_RALLY_TYRES for better loose-surface grip
- [x] **Aggressive mass boost** – scale 0.45 (was 0.9) for heavy off-road
- [x] **Skip launch smoothing** – full grip immediately
- [x] **Class 9 + mass > 2000kg** – only affects trophy trucks, not light off-road
- [x] **fTractionLossMult option** – config `tractionField` for surface-grip method
- [x] **Handling flags** – optional CF_ASSIST_*, CF_FIX_OLD_BUGS, HF_HAS_RALLY_TYRES
- [x] **Water ingress** – engine damage when submerged (boats excluded)
- [x] **Engine overheating** – damage from sustained redline

### Exports & Integration
- [x] **GetPhysicsSnapshot** – unified physics + weather + time
- [x] **GetEffectiveGrip** – surface × weather × tire × damage
- [x] **GetVehicleGroundGrip**, **GetRoadWetness**, **GetTireTemp**, etc.
- [x] **GetVehicleDamageSnapshot** – engine/body/tire health, grip modifier
- [x] **jds-advanceenvironment** – weather + time from GlobalState

---

## 🔲 TODO (Needs to be done)

### High Priority

| # | Task | Description | Effort |
|---|------|-------------|--------|
| 1 | ~~Per-wheel surface detection~~ | ✅ Done | - |
| 2 | ~~Tire wear simulation~~ | ✅ Done | - |
| 3 | **Fix raycast async** | `Wait(0)` used; acceptable for 200ms grip loop. Full async = complex | - |
| 4 | ~~fTractionLossMult vs fTractionCurveMax~~ | ✅ Config `tractionField` option | - |
| 5 | ~~GetEntitySpeed fallback~~ | ✅ Uses GetEntityVelocity magnitude | - |

### Medium Priority

| # | Task | Description | Effort |
|---|------|-------------|--------|
| 6 | ~~Damage: SetVehicleDamage~~ | ✅ Done | - |
| 7 | ~~Damage: deformation~~ | ✅ Done | - |
| 8 | ~~Damage: wheel health~~ | ✅ Done | - |
| 9 | ~~Config: useAllWheels~~ | ✅ Done | - |
| 10 | ~~Config: surfaceDetection.rayLength~~ | ✅ Done | - |
| 11 | ~~Restore handling on ownership change~~ | ✅ Done (isNetworkOwner check) | - |
| 12 | ~~Real ambient temp from weather API~~ | ✅ Done (Config.AmbientTemp, OpenWeatherMap) | - |

### Lower Priority / Polish

| # | Task | Description | Effort |
|---|------|-------------|--------|
| 13 | **Suspension simulation** | Pre-tune handling.meta; no runtime per-wheel (GTA limit) | 2–3 days |
| 14 | ~~Handling flags~~ | ✅ Config gripApplication.handlingFlags | - |
| 15 | **Control scaling fallback** | Scale SetControlNormal when handling override unavailable | 1 day |
| 16 | ~~Damage: oil/water ingress~~ | ✅ Config environmental.waterIngress | - |
| 17 | ~~Damage: overheating~~ | ✅ Config environmental.overheating | - |
| 18 | **Damage: visual feedback** | Smoke, steam, dashboard warnings | 1 day |
| 19 | ~~Multiplayer sync~~ ✅ | Damage state sync for other players’ vehicles | 2 days |
| 20 | **Unit tests / validation** | Automated checks for surface lookup, grip math | 1 day |

---

## 📋 Phase Plan (Suggested Order)

| Phase | Scope | Status |
|-------|-------|--------|
| **Phase 1** | Surface + material lookup | ✅ Done |
| **Phase 2** | Weather → road wetness + grip | ✅ Done |
| **Phase 3** | Tire temperature | ✅ Done |
| **Phase 4** | Grip application (handling override) | ✅ Done |
| **Phase 5** | Vehicle damage model | ✅ Done |
| **Phase 6** | Per-wheel detection, tire wear | ✅ Done |
| **Phase 7** | Damage polish (localized, deformation, visuals) | ✅ Done |
| **Phase 8** | Real weather API ambient, multiplayer damage sync | ✅ Done |
| **Phase 9** | Polish: ownership, traction field, flags, water, overheating | ✅ Done |
| **Phase 10** | Damage-to-performance: engine, suspension, camber, brakes, tires | ✅ Done |

---

## 🏆 “Best Physics Engine” Checklist

To be **the best** FiveM physics engine:

1. ✅ Realistic gravity & movement
2. ✅ Surface-specific grip (60+ materials)
3. ✅ Dynamic road conditions (wetness, weather)
4. ✅ Tire temperature simulation
5. ✅ **Realistic vehicle damage** (engine, body, tires, performance)
6. ✅ Per-wheel surface detection
7. ✅ Tire wear over time
8. ✅ Localized damage & deformation
9. ⚠️ Raycast uses Wait(0) (acceptable; full async = complex)
10. ✅ Multiplayer damage sync
11. ✅ Full docs + exports for HUDs, mechanics, racing scripts

---

## 📁 File Overview

| File | Purpose |
|------|---------|
| `config/physics.lua` | Gravity, movement, stamina |
| `config/physics_advanced.lua` | Tire temp, grip, surfaces, class rules |
| `config/vehicle_damage.lua` | Damage thresholds, localized, wheel health |
| `config/vehicle_performance.lua` | Damage→engine/suspension/camber/brakes mapping |
| `config/ambient_temp.lua` | OpenWeatherMap API, fallback |
| `config/surfaces.lua` | Material hash → μ dry/wet |
| `config/weather.lua` | Weather → wetness, grip mod |
| `client/physics.lua` | Gravity + movement setup |
| `client/surface_detection.lua` | Raycast, GetVehicleGroundGrip |
| `client/road_conditions.lua` | Road wetness from weather |
| `client/tire_state.lua` | Tire temp simulation |
| `client/vehicle_damage.lua` | Impact detection, damage, sync, localized, wheel health |
| `client/vehicle_performance.lua` | Damage→handling (engine, suspension, camber, brakes, tires) |
| `client/grip_application.lua` | Apply grip to handling |
| `exports/client.lua` | Public API |
| `server/main.lua` | Damage sync events |
| `server/ambient_temp.lua` | OpenWeatherMap fetch (optional) |
