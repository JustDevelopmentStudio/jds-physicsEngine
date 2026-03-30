--[[
    jds-physicsEngine :: exports (client)
    Unified physics + weather + time API for other resources
    Use with: exports['jds-physicsEngine']:ExportName(args)
]]

local res = GetCurrentResourceName()
local WetWeatherNames = { RAIN = true, THUNDER = true, SNOW = true, XMAS = true, BLIZZARD = true }

--- Get server weather from Renewed-Weathersync (GlobalState)
---@return string? weather name (e.g. "RAIN", "CLEAR")
local function getServerWeather()
    local weather = GlobalState.weather
    if type(weather) == 'table' and weather.weather then
        return weather.weather
    end
    return nil
end

--- Get server time from Renewed-Weathersync (GlobalState)
---@return number hour, number minute
local function getServerTime()
    local t = GlobalState.currentTime
    if type(t) == 'table' then
        return t.hour or 12, t.minute or 0
    end
    return GetClockHours(), GetClockMinutes()
end

--- Is current weather considered wet (rain/snow)?
---@return boolean
local function isWeatherWet()
    local w = getServerWeather() or GetPrevWeatherTypeHashName()
    return WetWeatherNames[w or ""] == true
end

-- ============================================================================
-- RAW PHYSICS STATE (from client modules)
-- ============================================================================

exports('GetRoadWetness', function()
    return GetRoadWetness and GetRoadWetness() or 0.0
end)

exports('GetWeatherGripModifier', function()
    return GetWeatherGripModifier and GetWeatherGripModifier() or 1.0
end)

exports('GetTireTemp', function(wheelIndex)
    if wheelIndex ~= nil then
        return GetTireTemp and GetTireTemp(wheelIndex) or 20
    end
    return GetTireTemp and GetTireTemp() or 20
end)

exports('GetTireTempPerWheel', function()
    return GetTireTempPerWheel and GetTireTempPerWheel() or { [0] = 20, 20, 20, 20 }
end)

exports('GetTireWear', function()
    return GetTireWear and GetTireWear() or 0
end)

exports('GetAmbientTemp', function()
    return GetAmbientTemp and GetAmbientTemp() or 20
end)

exports('GetClimateTemp', function()
    return GetClimateTemp and GetClimateTemp() or 20
end)

exports('GetRoadTemp', function()
    return GetRoadTemp and GetRoadTemp() or 20
end)

exports('GetTireGripModifier', function()
    return GetTireGripModifier and GetTireGripModifier() or 1.0
end)

exports('GetDamageGripModifier', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 1.0 end
    return GetDamageGripModifier and GetDamageGripModifier(vehicle) or 1.0
end)

exports('GetVehicleDamageSnapshot', function(vehicle)
    if not vehicle and IsPedInAnyVehicle(PlayerPedId(), false) then
        vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    end
    return GetVehicleDamageSnapshot and GetVehicleDamageSnapshot(vehicle) or {
        engineHealth = 1000, bodyHealth = 1000, burstTires = 0, gripModifier = 1.0
    }
end)

exports('GetVehicleGroundGrip', function(vehicle, roadWetness)
    if not vehicle or not DoesEntityExist(vehicle) then
        return 0.75 -- default dry surface
    end
    local wet = roadWetness
    if wet == nil then
        wet = GetRoadWetness and GetRoadWetness() or 0.0
    end
    local grip = GetVehicleGroundGrip and GetVehicleGroundGrip(vehicle, wet)
    return type(grip) == 'number' and grip or 0.75
end)

exports('GetGroundGripAtPosition', function(x, y, z, roadWetness)
    if not x or not y or not z then return 0.75 end
    local wet = roadWetness or (GetRoadWetness and GetRoadWetness() or 0.0)
    local grip = GetGroundGripAtPosition and GetGroundGripAtPosition(x, y, z, wet)
    return type(grip) == 'number' and grip or 0.75
end)

-- ============================================================================
-- WEATHER + TIME (from Renewed-Weathersync GlobalState)
-- ============================================================================

exports('GetServerWeather', getServerWeather)

exports('GetServerTime', function()
    return getServerTime()
end)

exports('IsWeatherWet', isWeatherWet)

--- Combined weather + time snapshot (for HUDs, stamina, etc.)
---@return table { weather, hour, minute, isWet }
exports('GetWeatherTimeSnapshot', function()
    local w = getServerWeather()
    local h, m = getServerTime()
    return {
        weather = w or GetPrevWeatherTypeHashName() or 'CLEAR',
        hour = h,
        minute = m,
        isWet = isWeatherWet(),
        blackout = GlobalState.blackOut == true,
        timeFrozen = GlobalState.freezeTime == true,
    }
end)

-- ============================================================================
-- UNIFIED PHYSICS SNAPSHOT (physics + weather + time)
-- ============================================================================

--- Full physics snapshot for a vehicle (or local player's vehicle if nil)
--- Use for HUDs, tire wear scripts, grip displays, team-based modifiers, etc.
---@param vehicle number? vehicle handle (nil = current vehicle)
---@param options table? { playerId, teamId } for future per-player/team overrides
---@return table
exports('GetPhysicsSnapshot', function(vehicle, options)
    options = options or {}
    local ped = PlayerPedId()
    local veh = vehicle
    if not veh and IsPedInAnyVehicle(ped, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) == ped then
        veh = GetVehiclePedIsIn(ped, false)
    end

    local roadWetness = GetRoadWetness and GetRoadWetness() or 0.0
    local weatherMod = GetWeatherGripModifier and GetWeatherGripModifier() or 1.0
    local tireMod = GetTireGripModifier and GetTireGripModifier() or 1.0
    local tireTemp = GetTireTemp and GetTireTemp() or 20
    local tireTempPerWheel = GetTireTempPerWheel and GetTireTempPerWheel() or { [0] = 20, 20, 20, 20 }
    local surfaceGrip = 0.75
    local materialHash = nil
    if veh and DoesEntityExist(veh) and GetVehicleGroundGrip then
        local sg, mh = GetVehicleGroundGrip(veh, roadWetness)
        if type(sg) == 'number' then surfaceGrip = sg end
        materialHash = mh
    end

    local damageMod = GetDamageGripModifier and veh and GetDamageGripModifier(veh) or 1.0
    local effectiveGrip = surfaceGrip * weatherMod * tireMod * damageMod
    local weather, hour, minute = getServerWeather(), getServerTime()

    local climateTemp = GetClimateTemp and GetClimateTemp() or 20
    local roadTemp = GetRoadTemp and GetRoadTemp() or climateTemp

    local tireCfg = (Config.PhysicsAdvanced or {}).tireTemp or {}
    local tireOptimalMin = tireCfg.optimalMin or 65
    local tireOptimalMax = tireCfg.optimalMax or 115

    local snap = {
        -- Raw values
        roadWetness = roadWetness,
        surfaceGrip = surfaceGrip,
        materialHash = materialHash,
        weatherGripMod = weatherMod,
        tireGripMod = tireMod,
        tireTemp = tireTemp,
        tireTempPerWheel = tireTempPerWheel,
        climateTemp = climateTemp,
        roadTemp = roadTemp,
        tireOptimalMin = tireOptimalMin,
        tireOptimalMax = tireOptimalMax,
        damageGripMod = damageMod,
        effectiveGrip = effectiveGrip,

        -- Damage (if vehicle_damage enabled)
        damage = veh and GetVehicleDamageSnapshot and GetVehicleDamageSnapshot(veh) or nil,

        -- Weather + time (from Renewed-Weathersync)
        weather = weather,
        hour = hour,
        minute = minute,
        isWet = isWeatherWet(),

        -- Vehicle context
        inVehicle = veh ~= nil,
        vehicle = veh,

        -- Extensibility for team/player overrides (future)
        playerId = options.playerId or GetPlayerServerId(PlayerId()),
        teamId = options.teamId,
    }
    return snap
end)

--- Effective grip for a vehicle (surface × weather × tire)
---@param vehicle number? vehicle handle (nil = current)
---@return number 0..1
exports('GetEffectiveGrip', function(vehicle)
    local snap = exports[res]:GetPhysicsSnapshot(vehicle)
    return snap.effectiveGrip or 0.75
end)

-- ============================================================================
-- INTEGRATION HOOKS (for other scripts)
-- ============================================================================

--- Manual road wetness update (normally called by grip loop; export for external tick)
exports('UpdateRoadWetness', function()
    return UpdateRoadWetness and UpdateRoadWetness()
end)

--- Manual tire temp update (normally called by grip loop)
---@param vehicle number
---@return number? tire temp
exports('UpdateTireTemp', function(vehicle)
    return UpdateTireTemp and vehicle and UpdateTireTemp(vehicle)
end)

--- Reset tire temp to ambient (e.g. after respawn or pit stop)
exports('ResetTireTemp', function()
    if ResetTireTemp then ResetTireTemp() end
end)
