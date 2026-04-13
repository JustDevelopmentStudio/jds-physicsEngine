--[[
    jds-resources :: weather -> road wetness & grip modifier
    Synced with jds-advanceenvironment (Renewed). Hash from GetPrevWeatherTypeHashName()
    or string key when using GlobalState.weather.weather
]]
Config = Config or {}
Config.Weather = {
    -- By hash (GetPrevWeatherTypeHashName)
    [0x97AA0A79] = { wetness = 0.0,   gripMod = 1.0  },  -- EXTRASUNNY
    [0x36A83D84] = { wetness = 0.0,   gripMod = 1.0  },  -- CLEAR
    [0x30FDAF5C] = { wetness = 0.0,   gripMod = 1.0  },  -- CLOUDS
    [0xBB898D2D] = { wetness = 0.05,  gripMod = 0.95 },  -- OVERCAST
    [0x54A69840] = { wetness = 0.65,  gripMod = 0.62 },  -- RAIN
    [0xB677829F] = { wetness = 0.9,   gripMod = 0.50 },  -- THUNDER
    [0xefb6eff6] = { wetness = 1.0,   gripMod = 0.35 },  -- SNOW
    [0xAE737644] = { wetness = 0.1,   gripMod = 0.92 },  -- FOGGY
    [0xAAC9C895] = { wetness = 1.0,   gripMod = 0.35 },  -- XMAS
    [0x6DB1A50D] = { wetness = 0.4,   gripMod = 0.75 },  -- CLEARING (rain ending)
    [0x23FB812B] = { wetness = 0.8,   gripMod = 0.40 },  -- SNOWLIGHT
    [0x27EA2814] = { wetness = 1.0,   gripMod = 0.28 },  -- BLIZZARD
    [0x10DCF4B5] = { wetness = 0.0,   gripMod = 0.98 },  -- SMOG
    -- By string (jds-advanceenvironment GlobalState.weather.weather)
    EXTRASUNNY = { wetness = 0.0, gripMod = 1.0 },
    CLEAR = { wetness = 0.0, gripMod = 1.0 },
    CLOUDS = { wetness = 0.0, gripMod = 1.0 },
    OVERCAST = { wetness = 0.05, gripMod = 0.95 },
    RAIN = { wetness = 0.65, gripMod = 0.62 },
    THUNDER = { wetness = 0.9, gripMod = 0.50 },
    SNOW = { wetness = 1.0, gripMod = 0.35 },
    FOGGY = { wetness = 0.1, gripMod = 0.92 },
    XMAS = { wetness = 1.0, gripMod = 0.35 },
    CLEARING = { wetness = 0.4, gripMod = 0.75 },
    SNOWLIGHT = { wetness = 0.8, gripMod = 0.40 },
    BLIZZARD = { wetness = 1.0, gripMod = 0.28 },
    SMOG = { wetness = 0.0, gripMod = 0.98 },
    NEUTRAL = { wetness = 0.0, gripMod = 1.0 },
}
Config.Weather.Default = { wetness = 0.0, gripMod = 1.0 }
Config.Weather.RainAccumRate = 0.02   -- per second when raining
Config.Weather.WetnessDecayRate = 0.001
Config.Weather.MaxWetness = 1.0
Config.Weather.MinWetness = 0.0
