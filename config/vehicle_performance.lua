--[[
    jds-physicsEngine :: damage-to-performance mapping
    Vehicle performs like it looks: engine, suspension, camber, tires
]]
Config = Config or {}
Config.VehiclePerformance = {
    enabled = true,

    --- Engine damage → power, top speed, rev response
    engine = {
        enabled = true,
        healthThreshold = 800,      -- below this, start degrading
        minHealth = -4000,
        -- Modifiers at worst engine health
        powerMultiplierAtDead = 0.15,   -- fInitialDriveForce (stumbling, not dead)
        topSpeedMultiplierAtDead = 0.3, -- fInitialDriveMaxFlatVel
        revMultiplierAtDead = 0.5,      -- fDriveInertia (sluggish)
    },

    --- Body damage → suspension (worn/bent geometry)
    suspension = {
        enabled = true,
        bodyHealthThreshold = 800,
        minBodyHealth = 0,
        -- At max body damage: suspension degradation
        springMultiplierAtWorst = 0.7,   -- fSuspensionForce (softer/worn)
        compDampMultiplierAtWorst = 0.75,-- fSuspensionCompDamp (bouncy)
        reboundDampMultiplierAtWorst = 0.75,
    },

    --- Body damage → camber/toe (bent frame, misaligned wheels)
    geometry = {
        enabled = true,
        bodyHealthThreshold = 700,
        -- Add degrees of "bent" camber at max damage (value ≈ deg/22.5 for camber)
        camberBendAtWorst = 0.15,   -- ~3.4° extra camber (positive = tire leans out)
        toeBendAtWorst = 0.05,      -- toe misalignment
    },

    --- Active camber/toe: dynamic based on steering, brake, throttle, speed
    --- Simulates load transfer, body roll, dive/squat → affects grip & steering
    activeGeometry = {
        enabled = true,
        -- Cornering: steering input + speed → camber change (load transfer)
        corneringCamberFront = -0.08,   -- negative = more grip when turning
        corneringCamberRear = -0.06,
        corneringSpeedFactor = 0.4,     -- scale by speed (m/s) for effect
        corneringSteerThreshold = 0.25, -- min steer to trigger

        -- Brake dive: front toe/camber under braking (weight transfers forward)
        brakeToeFront = 0.05,           -- Stronger dynamic dive feel
        brakeCamberFront = -0.06,
        brakeThreshold = 0.25,          -- lower threshold so dive happens on trail braking

        -- Brake weight transfer: shift grip to front when braking (rear gets light)
        brakeTractionBiasShift = 0.15,  -- up to 15% more front grip when braking hard (drifting initiator)
        brakeAndSteerExtra = 0.06,      -- extra shift when trail braking (brake + turn)

        -- Acceleration squat: rear toe/camber under throttle
        accelToeRear = 0.015,
        accelCamberRear = -0.02,
        accelThreshold = 0.5,

        -- Steering: dynamic lock based on speed (lerp, no flat base)
        speedSteerReduction = true,
        steerAtLowSpeed = 1.0,         -- full lock at 0 m/s for sharp parking
        steerAtHighSpeed = 0.48,       -- increased from 0.28 to allow for sharp high-speed racing lines
        speedForMaxReduction = 55,     -- m/s (~123 mph) - speed where min steering reached
    },

    --- Body damage → steering (bent steering linkage)
    steering = {
        enabled = true,
        bodyHealthThreshold = 750,
        lockMultiplierAtWorst = 0.85, -- reduced steering lock
    },

    --- Body damage → brakes (warped rotors, fluid loss)
    brakes = {
        enabled = true,
        bodyHealthThreshold = 700,
        forceMultiplierAtWorst = 0.8,
        biasShiftAtWorst = 0.05,
        baseBrakeForceMult = 0.38,  -- way slower braking (very aggressive)
    },

    --- Tire damage → traction curve shape + balance
    tires = {
        enabled = true,
        -- Affects fTractionCurveMin (slide grip), fTractionBiasFront (balance)
        wheelHealthThreshold = 800,
        slideGripMultiplierAtWorst = 0.7,  -- fTractionCurveMin (slides more when damaged)
        biasShiftAtWorst = 0.08,           -- F/R traction bias shift (pulls to one side)
    },
}
