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
        updateIntervalMs = 50,   -- apply handling more often (steering/brakes feel)
        minGripModifier = 0.15,
        surfaceGripReference = 0.36,
        baseGripMult = 0.55,         -- low grip feel, less slidey (was 0.36)

        -- Realistic road grip: full stock handling on dry pavement (no artificial reduction)
        realisticRoadGrip = {
            enabled = true,
            speedMps = 45,           -- full grip up to ~100 mph (extended for stability)
            surfaceGripMin = 0.28,
            weatherGripMin = 0.92,
        },
        -- Aero / high-speed stability: cars in motion stay in motion, less spinout when steering
        aeroDownforce = {
            enabled = true,
            speedMpsMin = 15,        -- start effect above ~34 mph
            speedMpsMax = 55,        -- full effect at ~123 mph
            gripBoostMax = 0.12,     -- up to 12% extra grip at speed (simulates downforce)
            surfaceGripMin = 0.28,   -- paved only
        },

        -- Road cars: full grip at launch + low speed
        roadLaunchGrip = {
            enabled = true,
            speedMps = 22,           -- extended launch phase
            surfaceGripMin = 0.26,
            gripFloor = 1.0,         -- full grip at low speed on pavement
            lowSpeedTractionMult = 0.2,  -- minimal artificial wheelspin (real: static μ > kinetic)
            keyboardLaunchCompensation = {
                enabled = true,
                throttleThreshold = 0.82,
                lowSpeedTractionMult = 0.15,-- very low wheelspin for keyboard (can't modulate)
                gripFloor = 1.0,
            },
        },
        -- Bikes
        bikeGripModifier = 1.85,
        skipBikeTireTemp = true,

        -- Per-vehicle-class grip caps (heavy rigs; road cars unaffected)
        classGripCap = {
            [9]  = 0.88, -- off-road
            [10] = 0.85, -- industrial
            [11] = 0.85, -- utility
            [17] = 0.85, -- service
            [18] = 0.95, -- emergency (responsive for pursuits)
            [20] = 0.85, -- commercial
        },

        -- Extra damping for very heavy vehicles
        heavyMass = {
            threshold = 2200.0, -- kg; above this we soften the effect of high grip
            scale     = 0.90,   -- 0.0–1.0: 1.0 = no change, lower = more damping towards 1.0
        },

        -- Smooth traction on launch to avoid long burnouts then instant snap-grip
        launchSmoothing = {
            speedMps = 5.0,  -- apply below this speed (m/s, ~11 mph)
            lerp     = 0.35, -- how fast we move towards new grip each tick
        },

        --- Road vehicles (non-off-road) on dirt/mud: SnowRunner-level struggle
        roadVehicleOffroad = {
            enabled = true,
            surfaceGripPaved = 0.32,   -- below = off-road surface, penalty applies
            gripMultMin = 0.18,        -- on worst surfaces (mud): brutal penalty
            gripMultMax = 0.45,        -- on gravel: still poor (road tires useless)
            hillPitchDeg = 4,          -- pitch (deg) above this = climbing
            hillGripMult = 0.35,       -- hills destroy road cars off-road
            lowSpeedTractionMult = 3.5,-- massive wheelspin on dirt
        },
        --- Mud / Marsh / Sand: SnowRunner sink + weight buildup
        mudStuck = {
            enabled = true,
            surfaceGripMax = 0.20,    -- below = mud, marsh, sand (broader trigger)
            buildRate = 0.07,         -- faster sink
            decayRate = 0.015,        -- slower recovery (hard to escape)
            maxGripMult = 0.92,       -- at full stuck: grip *= 0.08 (near immobilised)
            maxExtraMassKg = 1500,    -- +1500 kg when buried (heavy drag)
            minGripWhenStuck = 0.04,  -- can barely move when stuck
            applyToOffroad = true,    -- off-road trucks also sink in deep mud
            offroadMult = 0.6,        -- off-road mud penalty scaled down (better tires)
        },

        --- Off-road (class 9): SnowRunner/MudRunner difficulty - deliberate, heavy, slippy
        offroad = {
            enabled = true,
            vehicleClasses = { 9 },
            massThresholdLight = 1200.0,
            massThresholdHeavy = 2000.0,
            surfaces = {
                paved = { maxGrip = 0.32 },
                gravel = { maxGrip = 0.24 },
                dirt = { maxGrip = 0.18 },
                soft = { maxGrip = 0.12 },
                grass = { maxGrip = 0.16 },
            },
            -- Grip *multipliers*: < 1 = harder (SnowRunner style)
            surfaceGripMod = {
                paved = 0.92, gravel = 0.70, dirt = 0.55,
                soft = 0.35, grass = 0.50, rock = 0.65,
            },
            lightOffroad = {
                gripFloorOnLoose = 0.22, gripCap = 0.62, massScale = 0.45,
                skipTireTempPenalty = true, lowSpeedTractionMult = 1.8, rallyTyres = true,
                launchSmoothing = { speedMps = 6.0, lerp = 0.25 },
            },
            heavyOffroad = {
                gripFloorOnLoose = 0.20, gripCap = 0.58, massScale = 0.40,
                skipTireTempPenalty = true, lowSpeedTractionMult = 2.0, rallyTyres = true,
                launchSmoothing = { speedMps = 10.0, lerp = 0.22 },
            },
            hillPenalty = {
                enabled = true,
                pitchDeg = 5,
                gripMult = 0.60,   -- 40% grip loss when climbing loose surfaces
            },
        },

        -- Custom traction control (overrides native GTA TC when enabled)
        customTractionControl = {
            enabled = true,
            slipThreshold = 0.15,       -- 15% slip before intervention (less intrusive with improved grip)
            interventionStrength = 1.5,
            minSpeedMps = 1.5,
            maxThrottleRetain = 0.35,   -- more drive retained (natural with realistic base grip)
        },

        -- Handling flags; applyTractionControl ignored when customTractionControl.enabled
        handlingFlags = {
            applyTractionControl = false,
            applyStabilityControl = true,  -- reduces spinout when steering at speed
            fixOldBugs = true,              -- CF_FIX_OLD_BUGS: improves handling stability
            rallyTyres = false,
        },
    },
}
