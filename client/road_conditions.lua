--[[
    jds-resources :: road wetness from weather
    GetPrevWeatherTypeHashName returns string e.g. "RAIN"
]]
local cfg = (Config.PhysicsAdvanced or {}).roadWetness or {}
local wcfg = Config.Weather or {}
local RainAccum = cfg.rainAccumRate or 0.02
local DecayRate = cfg.decayRate or 0.001
local MaxWetness = wcfg.MaxWetness or 1.0
local MinWetness = wcfg.MinWetness or 0.0

local roadWetness = 0.0
local lastUpdate = GetGameTimer() / 1000.0

local WetWeatherNames = { RAIN = true, THUNDER = true, SNOW = true, XMAS = true, SNOWLIGHT = true, BLIZZARD = true }

function GetRoadWetness()
    return roadWetness
end

local function getWeatherEntry()
    -- Prefer Renewed-Weathersync GlobalState (server authoritative, instant sync)
    local gs = GlobalState.weather
    if gs and gs.weather then
        local byName = wcfg[gs.weather]
        if byName then return byName end
    end
    -- Fallback: native applied weather
    local name = GetPrevWeatherTypeHashName()
    if not name or name == "" then return wcfg.Default end
    local byName = (type(name) == "string" and wcfg[name])
    if byName then return byName end
    local hash = type(name) == "number" and name or GetHashKey(name)
    return wcfg[hash] or wcfg.Default
end

function GetWeatherGripModifier()
    local w = getWeatherEntry()
    return (w and w.gripMod) or 1.0
end

function UpdateRoadWetness()
    local now = GetGameTimer() / 1000.0
    local dt = math.min(1.0, now - lastUpdate)
    lastUpdate = now

    local name = (GlobalState.weather and GlobalState.weather.weather) or GetPrevWeatherTypeHashName()
    if WetWeatherNames[name or ""] then
        roadWetness = math.min(MaxWetness, roadWetness + RainAccum * dt)
    else
        roadWetness = math.max(MinWetness, roadWetness - DecayRate * dt)
    end
    return roadWetness
end
