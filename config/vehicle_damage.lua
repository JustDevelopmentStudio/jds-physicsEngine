--[[
    jds-physicsEngine :: vehicle damage config
    Realistic damage model: engine, body, tires, performance degradation
]]
Config = Config or {}
Config.VehicleDamage = {
    enabled = true,

    --- Impact detection (velocity delta method)
    impactDetection = {
        updateIntervalMs = 50,
        speedDeltaThreshold = 8.0,      -- m/s drop to count as impact
        minSpeedForDamage = 5.0,        -- min speed before impact to deal damage
        cooldownMs = 300,               -- min time between impact calculations
    },

    --- Engine damage (0-1000 scale; <0 = burning)
    engine = {
        damagePerImpact = 15,           -- base engine damage per moderate impact
        speedDamageMultiplier = 2.5,    -- higher speed = more damage
        criticalSpeed = 25.0,           -- m/s above which damage scales heavily
        minEngineHealth = -4000,        -- engine dies before explosion
        enableEngineDegrade = true,     -- SetVehicleEngineCanDegrade
        undriveableThreshold = 100,     -- SetVehicleUndriveable below this
    },

    --- Body damage (0-1000 scale)
    body = {
        damagePerImpact = 20,
        speedDamageMultiplier = 2.0,
        minBodyHealth = 0,
    },

    --- Tire damage (blowouts, wear, wheel health)
    tires = {
        allowBlowouts = true,
        blowoutSpeedThreshold = 35.0,   -- m/s - speed + damage can cause blowout
        blowoutDamageThreshold = 0.4,   -- body health fraction (0.4 = 400/1000)
        blowoutChancePerImpact = 0.15,  -- chance per high-impact event
        wheelHealthDamage = 50,         -- per-wheel health damage per impact (0-1000)
        wheelHealthAffectsSteering = true,
    },

    --- Localized body damage (SetVehicleDamage)
    localizedDamage = {
        enabled = true,
        damageAmount = 0.5,             -- 0-1 multiplier
        radius = 0.5,
        focusOnModel = true,
    },

    --- Visual deformation (don't fix deformation = let it show)
    deformation = {
        allowDeformation = true,        -- false = call SetVehicleDeformationFixed (resets dents)
    },

    --- Performance degradation (grip/ handling penalty from damage)
    performance = {
        enabled = true,
        engineGripPenalty = true,       -- reduce grip when engine damaged
        bodyGripPenalty = true,         -- reduce grip when body damaged
        tireGripPenalty = true,         -- reduce grip when tires damaged
        engineHealthThreshold = 700,    -- below this, start applying penalty
        bodyHealthThreshold = 700,
        maxGripPenalty = 0.35,          -- max 35% grip loss from damage
    },

    --- Water / overheating (environmental damage)
    environmental = {
        waterIngress = true,           -- engine damage when submerged
        submergedThreshold = 0.5,      -- GetEntitySubmergedLevel > this = damage
        waterDamagePerSecond = 25,
        overheating = true,            -- engine damage from sustained redline
        redlineRpm = 0.9,              -- above this = redline
        overheatDamagePerSecond = 8,
        overheatCooldownSec = 2,       -- seconds at redline before damage starts
    },

    --- Vehicle class overrides (some vehicles more/less fragile)
    classMultipliers = {
        [8] = 0.6,   -- motorcycles: less body, more tire/engine
        [13] = 0.6,  -- cycles
        [14] = 1.3,  -- boats (ignore or lower)
        [15] = 1.3,  -- helicopters
        [16] = 1.3,  -- planes
        [20] = 0.85, -- commercial: tougher
        [21] = 0.5,  -- trains: ignore
    },
}
