# 🏎️ JDS Advanced Physics Engine (V1.2)

![Just Development Studios Header](https://raw.githubusercontent.com/JustDevelopmentStudio/.github/main/profile/jds-banner.png)

> **The ultimate realistic physics simulation for FiveM.** Layering real-world thermal models, surface-specific grip, and structural damage on top of the GTA V engine for a "Sim-Racing" experience.

---

## 🌟 Key Features

### ⚙️ Core Physics (Foundation)
- **True Earth Gravity**: SI-unit based gravity (9.8 m/s²) for realistic vehicle movement and player kinematics.
- **Advanced SI Calculations**: Mass and force logic converted to real-world metric standards.

### 🛣️ Dynamic Surface Detection
- **60+ Material Support**: Distinct grip coefficients (μ) for tarmac, gravel, mud, grass, ice, and more.
- **Independent 4-Wheel Sensing**: Each wheel detects the surface individually (configurable) for high-fidelity off-road response.
- **Road Wetness**: Accumulation and decay synced with `Renewed-Weathersync`.

### 🌡️ Thermal & Wear Simulation
- **Tire Heat Model**: Dynamic temperature curves based on RPM, speed, and braking load.
- **Grip Performance**: Tires perform optimally between 80°C - 120°C; penalty for cold or overheated rubber.
- **Tire Wear**: Long-term degradation from friction and slides affecting baseline grip.

### 🛠️ structural Damage-to-Performance
- **Alignment Geometry**: Frame impacts cause visual and functional camber/toe bends.
- **Performance Mapping**: Engine and body damage realistically degrade acceleration, top speed, and braking.
- **Structural Failure**: Chance of tire blowouts and steering lock based on impact severity.

---

## 📦 Installation

1. **Clone the repository** into your server's `resources` folder:
   ```bash
   git clone https://github.com/JustDevelopmentStudio/jds-physicsEngine.git [jds]/jds-physicsEngine
   ```
2. **Ensure Dependencies**:
   - [Renewed-Weathersync](https://github.com/Renewed-Scripts/Renewed-Weathersync) (Required for weather/time sync)
3. **Configure**:
   - Edit `config/physics_advanced.lua` to tune grip and thermal constants.
   - Edit `config/vehicle_damage.lua` for impact thresholds.
4. **Add to server.cfg**:
   ```cfg
   ensure Renewed-Weathersync
   ensure jds-physicsEngine
   ```

---

## 📚 Documentation & API

Detailed guides and implementation details are available in the **[`docs/`](./docs/)** directory:

- **[Advanced Physics Engine Guide](./docs/ADVANCED_PHYSICS_ENGINE.md)**: Deep dive into the math and logic.
- **[Exports API Reference](./docs/EXPORTS.md)**: Integration guide for HUDs, mechanics, and racing scripts.
- **[Development Roadmap](./docs/TODO_PHYSICS_ENGINE.md)**: Current Phase 1 status and upcoming Phase 2 (Telemetry) plans.

---

## 🚀 Future Roadmap (Phase 2+)

- [ ] **NUI Telemetry Dashboard**: Real-time G-force and thermal visualization.
- [ ] **Dynamic Surface SFX**: Gravel and dirt rolling sound integration.
- [ ] **Brake Fade Simulation**: Heat-based stopping power degradation.

---

## 🛡️ License

© 2026 **Just Development Studios**. All rights reserved. 
Developed by **JDS Core Team**. Not for unauthorized redistribution.
