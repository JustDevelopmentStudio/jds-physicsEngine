--[[
    jds-resources :: advanced physics (surface, tire, grip)
]]
Config = Config or {}
Config.PhysicsAdvanced = {
    enabled = true,

    tireTemp = {
        enabled = true,
        heatRate = 0.85,       -- faster warmup for realistic feel (tires reach grip quickly)
        coolRate = 0.25,
        ambientFallback = 20,
        optimalMin = 65,       -- lower = full grip sooner (real tires grip well from ~60°C)
        optimalMax = 115,
        coldModifier = 0.98,   -- minimal cold penalty (real tires still grip when cold)
        hotModifier = 0.75,    -- grip when overheated (greasy tires)
        -- Advanced: braking, burnouts, cornering (per-wheel, tach independent)
        heatFromBraking = 1.2,      -- brake heat; front tires get more (brake bias)
        heatFromBurnout = 2.5,      -- burnout heat: driven wheels ONLY (FWD/RWD/AWD)
        burnoutRpmThreshold = 0.75,  -- higher = must rev more to count as burnout
        burnoutSpeedMax = 8,         -- lower = burnout only when nearly stationary
        heatFromCornering = 0.8,    -- lateral slip heat (× steer × speed)
        heatFromAccel = 0.4,        -- driven wheels warm during launch (reduces cold-spin)
    },
    tireWear = {
        enabled = true,
        wearFromSlip = 0.0008,      -- per slip event (wheelspin/lock)
        wearFromBraking = 0.0003,   -- per heavy brake
        wearFromDistance = 0.00002, -- per meter traveled
        maxWear = 1.0,              -- 0=new, 1=bald
        wearGripAtMax = 0.88,       -- grip modifier at 100% wear
    },
    roadWetness = {
        rainAccumRate = 0.02,
        decayRate = 0.001,
    },
    surfaceDetection = {
        rayLength = 2.0,
        updateIntervalMs = 50,
        useAllWheels = true,   -- raycast 4 wheels so mud/sand detected when any wheel on it
    },
    gripApplication = {
        useHandlingOverride = true,
        tractionField = "fTractionCurveMax",
        applyToCurveMin = true,
        applyToLateral = true,
        updateIntervalMs = 50,
        
        -- Core grip tuning (ONLY knobs you need to touch)
        minGripModifier = 0.20,          -- absolute floor for any surface
        surfaceGripReference = 0.33,     -- dry tarmac baseline (surfaces.lua value)
        baseGripMult = 0.55,              -- 15% below stock for loose, slidey feel
        pavedThreshold = 0.25,           -- surface grip above this = "paved road"
        pavementLowSpeedLossMult = 0.65, -- allow some wheelspin at launch for realism
        
        -- Aero downforce (speed-based grip bonus on pavement)
        aeroDownforce = {
            enabled = true,
            speedMpsMin = 15,
            speedMpsMax = 55,
            gripBoostMax = 0.15,
        },
        
        -- Bikes
        bikeGripModifier = 1.85,
        skipBikeTireTemp = true,
        
        -- Road cars on dirt/gravel/grass — severe penalty
        roadVehicleOffroad = {
            enabled = true,
            surfaceGripPaved = 0.30,
            gripMultMin = 0.18,
            gripMultMax = 0.45,
            hillPitchDeg = 4,
            hillGripMult = 0.35,
            lowSpeedTractionMult = 3.5,
        },
        
        -- Mud/marsh/sand stuck simulation
        mudStuck = {
            enabled = true,
            surfaceGripMax = 0.20,
            buildRate = 0.07,
            decayRate = 0.015,
            maxGripMult = 0.92,
            maxExtraMassKg = 200,
            minGripWhenStuck = 0.04,
            applyToOffroad = true,
            offroadMult = 0.6,
        },
        
        -- Off-road vehicle class handling
        offroad = {
            enabled = true,
            vehicleClasses = { 9 },
            surfaceGripMod = {
                paved = 0.92, gravel = 0.70, dirt = 0.55,
                mud = 0.35, grass = 0.50,
            },
            hillPenalty = {
                enabled = true,
                pitchDeg = 5,
                gripMult = 0.60,
            },
        },

        -- Custom traction control (manages wheelspin via torque_simulator.lua)
        customTractionControl = {
            enabled = true,
            slipThreshold = 0.38,
            interventionStrength = 0.6,
            minSpeedMps = 1.5,
            maxThrottleRetain = 0.35,
        },

        -- Handling flags
        handlingFlags = {
            applyTractionControl = false,
            applyStabilityControl = true,
            fixOldBugs = true,
            rallyTyres = false,
        },
    },
}
