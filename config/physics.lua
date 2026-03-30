--[[
    jds-resources :: advanced physics config
    True Earth gravity 9.8 m/s² + realistic movement
    GTA V engine limitations: world gravity uses discrete levels; vehicles accept m/s²
]]
Config = Config or {}
Config.Physics = {
    --- TRUE EARTH GRAVITY (9.8 m/s²)
    -- Scientific standard; vehicles use this when useEarthGravity = true
    gravityMs2 = 9.8,

    --- Gravity mode
    useEarthGravity = true,     -- true = apply 9.8 m/s² to vehicles; world uses gravityLevel
    gravityLevel = 0,           -- SetGravityLevel: 0 = heaviest (closest to Earth), 1–3 = lighter

    --- Vehicle gravity fallback (when useEarthGravity = false)
    -- SetVehicleGravityAmount: 1.0 = game default; 9.8 = m/s² if engine accepts SI units
    vehicleGravityMultiplier = 1.0,

    --- Player movement
    runSprintMultiplier = 1.0,  -- 1.0 = default; <1 = slower
    swimMultiplier = 1.0,
    moveRateOverride = nil,     -- nil = default; 0.0–1.0+ to override

    --- Stamina
    useStaminaTweaks = true,
    maxStamina = 100.0,

    --- Advanced options
    pedGravityOverride = false, -- Experimental: per-frame velocity correction for peds (heavy)
}
