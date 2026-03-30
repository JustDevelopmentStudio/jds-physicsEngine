# jds-physicsEngine – TODO & Roadmap

**Goal:** Make this the best realistic physics engine for FiveM.  
**Version:** 1.2 (Foundation)  
**Last updated:** 2026

---

## ✅ Phase 1: Foundation (V1.2) - COMPLETED

The foundation phase established a realistic, SI-unit-based physics model with deep surface and damage integration.

### Core Physics & Gravity
- [x] **True Earth gravity** (9.8 m/s²) for world and vehicles
- [x] **SI Unit Conversion** – Proper mass and force calculations
- [x] **Player movement** – sprint/swim multipliers, stamina tweaks

### Surface & Traction System
- [x] **Material Detection** – Raycast ground → material hash lookup
- [x] **60+ Material Table** – Tarmac, gravel, mud, grass, ice, snow, oil, etc.
- [x] **Grip Model (μ)** – Dry/wet grip coefficients per material
- [x] **Weather Integration** – Synced with `Renewed-Weathersync`
- [x] **Road Wetness** – Dynamic accumulation and decay
- [x] **Multi-Wheel Detection** – Support for 4-wheel independent surface sensing

### Tire & Thermal Simulation
- [x] **Thermal Model** – heat from speed, RPM, and braking
- [x] **Temperature Curves** – Cold penalty (<60°C), Optimal (80-120°C), Overheat (>140°C)
- [x] **Ambient Sync** – Derived from time of day and weather data
- [x] **Tire Wear** – Friction-based degradation affecting grip over time

### Advanced Damage Model
- [x] **Impact Detection** – Velocity-delta based collision sensing
- [x] **Engine & Body Damage** – Realistic health scaling
- [x] **Damage-to-Performance** – Engine HP, suspension, and steering affected by damage
- [x] **Alignment Geometry** – Camber/toe bend simulation from frame damage
- [x] **Tire Blowouts** – Chance based on speed and structural integrity
- [x] **Multiplayer Sync** – Damage states synced across all clients

### Optimization & Integration
- [x] **Unified Exports** – `GetPhysicsSnapshot` for HUDs and 3rd-party scripts
- [x] **Ownership Handling** – Smooth transitions when network ownership changes
- [x] **Highly Configurable** – Extensive config files for all modules

---

## 🔲 Phase 2: UI & Telemetry (Planned)

Focus on providing visual feedback to the player and developers.

- [ ] **NUI Telemetry Dashboard** – Real-time G-force meter, tire temps, and grip levels
- [ ] **On-Screen Alerts** – Subtle HUD notifications for "Low Grip", "Cold Tires", or "Alignment Issues"
- [ ] **Development Overlay** – Toggleable debug info showing material hashes and current μ
- [ ] **Tire Pressure HUD** – Visualizing PSI and impact on top speed

## 🔲 Phase 3: Environmental FX (Planned)

Focus on immersion through sound and visual effects.

- [ ] **Dynamic Surface SFX** – Custom tire-rolling sounds for gravel, dirt, and water
- [ ] **Advanced Particle FX** – Dynamic dust, mud, and water spray scaled by slip and surface
- [ ] **Audio Feedback** – Screeching/scrubbing sounds when alignment is bent
- [ ] **Tire Smoke** – Burnout smoke colored by surface (e.g., dust for dirt roads)

## 🔲 Phase 4: Advanced Tuning (Planned)

Adding more systemic depth to the simulation.

- [ ] **Tire Pressure Simulation** – Real impact of PSI on grip footprint and top speed
- [ ] **Slow Leaks** – Chance of losing pressure after minor impacts or sharp debris
- [ ] **Brake Fade** – Reduced stopping power as brake temps rise (linked to Thermal Model)
- [ ] **Advanced Suspension Overrides** – Visual camber/toe sync with NUI/damage states

---

## 📋 File Overview

| File | Purpose |
|------|---------|
| `config/` | All modular configuration files |
| `client/` | Core logic for surface, grip, and damage |
| `server/` | Multiplayer sync and weather bridges |
| `exports/client.lua` | Public API for JDS suite |
