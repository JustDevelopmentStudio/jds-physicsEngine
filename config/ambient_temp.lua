--[[
    jds-physicsEngine :: ambient + road temperature
    Climate (air) temp and local road surface temp. Used by tire temp, telemetry, etc.
]]
Config = Config or {}
Config.AmbientTemp = {

    --- Derive climate temp from jds-advanceenvironment (GlobalState.weather + currentTime)
    fallbackFromWeather = true,
    fallbackBase = 18,         -- Base temp (°C) at noon
    fallbackSwing = 10,        -- Day/night swing (±°C from base)

    --- Per-weather temp modifier (°C) - matches jds-advanceenvironment weather types
    weatherTempMod = {
        EXTRASUNNY = 4,        -- Hot, clear sun
        CLEAR = 3,
        CLOUDS = 1,
        OVERCAST = -1,
        RAIN = -3,
        THUNDER = -4,
        CLEARING = 0,
        FOGGY = -2,
        SMOG = 2,              -- Trapped heat
        SNOW = -8,
        SNOWLIGHT = -6,
        BLIZZARD = -12,
        XMAS = -8,
        NEUTRAL = 0,
    },

    --- Local road surface temp (tarmac absorbs heat, differs from air)
    roadTemp = {
        enabled = true,
        sunHeatMax = 18,       -- Max °C above climate when tarmac in full sun at noon
        nightCooling = -4,     -- Road cools below climate at night (radiative cooling)
        wetRoadMult = 0.3,     -- Wet roads stay closer to climate (less heat absorption)
    },
}
