--[[
    jds-resources :: grip application
    Applies surface + weather + tire grip modifier to vehicle handling
]]
local cfg = (Config.PhysicsAdvanced or {}).gripApplication or {}
local enabled = (Config.PhysicsAdvanced or {}).enabled
local useHandlingOverride = cfg.useHandlingOverride ~= false
local updateInterval = cfg.updateIntervalMs or 200
local minMod = math.max(0.15, cfg.minGripModifier or 0.15)
local tractionField = (cfg.tractionField == "fTractionLossMult") and "fTractionLossMult" or "fTractionCurveMax"
local flagsCfg = cfg.handlingFlags or {}
local customTC = (Config.PhysicsAdvanced or {}).customTractionControl or {}

local vehicleCache = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function isHeavyOffroadClass(vc)
    return vc == 10 or vc == 11 or vc == 17 or vc == 20
end

local function isOffroadClass(vc)
    local oCfg = cfg.offroad or {}
    if not oCfg.enabled then return false end
    local classes = oCfg.vehicleClasses or { 9 }
    for _, c in ipairs(classes) do
        if c == vc then return true end
    end
    return false
end

local function getOffroadSurfaceCategory(surfaceGrip)
    local s = (cfg.offroad or {}).surfaces or {}
    local p = s.paved and s.paved.maxGrip or 0.32
    local g = s.gravel and s.gravel.maxGrip or 0.25
    local d = s.dirt and s.dirt.maxGrip or 0.20
    local gr = s.grass and s.grass.maxGrip or 0.19
    if surfaceGrip > p then return "paved" end
    if surfaceGrip > g then return "gravel" end
    if surfaceGrip > d then return "dirt" end
    if surfaceGrip > gr then return "grass" end
    return "soft"
end

local function getOffroadPreset(vehicle)
    local oCfg = cfg.offroad or {}
    local massHeavy = oCfg.massThresholdHeavy or 2000.0
    local mass = GetEntityMass and GetEntityMass(vehicle)
    if not mass then return oCfg.lightOffroad or {} end
    return (mass >= massHeavy) and (oCfg.heavyOffroad or {}) or (oCfg.lightOffroad or {})
end

local function isOnLooseSurface(surfaceGrip)
    local s = (cfg.offroad or {}).surfaces or {}
    local looseThresh = s.gravel and s.gravel.maxGrip or 0.28
    return surfaceGrip < looseThresh
end

local function isOnMudSurface(surfaceGrip)
    local mCfg = cfg.mudStuck or {}
    if not mCfg.enabled then return false end
    return surfaceGrip < (mCfg.surfaceGripMax or 0.17)
end

local function isOnOffroadSurface(surfaceGrip)
    local rCfg = cfg.roadVehicleOffroad or {}
    if not rCfg.enabled then return false end
    return surfaceGrip < (rCfg.surfaceGripPaved or 0.30)
end

local function getRoadVehicleOffroadGripMult(surfaceGrip)
    local rCfg = cfg.roadVehicleOffroad or {}
    if not rCfg.enabled then return 1.0 end
    local paved = rCfg.surfaceGripPaved or 0.30
    if surfaceGrip >= paved then return 1.0 end
    local minMult = rCfg.gripMultMin or 0.35
    local maxMult = rCfg.gripMultMax or 0.70
    local minGrip = 0.10
    local t = (surfaceGrip - minGrip) / (paved - minGrip)
    t = math.max(0, math.min(1, t))
    return minMult + (maxMult - minMult) * t
end

local function getVehiclePitchDeg(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    local ok, pitch = pcall(GetEntityPitch, vehicle)
    return (ok and pitch) and pitch or 0
end

local function updateMudStuckLevel(vehicle, onMud)
    local mCfg = cfg.mudStuck or {}
    if not mCfg.enabled then return 0 end
    vehicleCache[vehicle] = vehicleCache[vehicle] or {}
    local cache = vehicleCache[vehicle]
    local level = cache.mudStuckLevel or 0
    if onMud then
        level = math.min(1.0, level + (mCfg.buildRate or 0.015))
    else
        level = math.max(0.0, level - (mCfg.decayRate or 0.03))
    end
    cache.mudStuckLevel = level
    return level
end

local function getOriginalMass(vehicle)
    if vehicleCache[vehicle] and vehicleCache[vehicle].origMass ~= nil then
        return vehicleCache[vehicle].origMass
    end
    local ok, val = pcall(GetVehicleHandlingFloat, vehicle, "CHandlingData", "fMass")
    if ok and val and val > 0 then
        vehicleCache[vehicle] = vehicleCache[vehicle] or {}
        vehicleCache[vehicle].origMass = val
        return val
    end
    return nil
end

local function applyExtraMass(vehicle, extraKg)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local orig = getOriginalMass(vehicle)
    if not orig then return end
    pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fMass", orig + extraKg)
end

local function getOriginalLowSpeedTraction(vehicle)
    if vehicleCache[vehicle] and vehicleCache[vehicle].origLowSpeedTraction ~= nil then
        return vehicleCache[vehicle].origLowSpeedTraction
    end
    local ok, val = pcall(GetVehicleHandlingFloat, vehicle, "CHandlingData", "fLowSpeedTractionLossMult")
    if ok and val ~= nil then
        vehicleCache[vehicle] = vehicleCache[vehicle] or {}
        vehicleCache[vehicle].origLowSpeedTraction = val
        return val
    end
    return nil
end

local function applyLowSpeedTractionMod(vehicle, mult)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local orig = getOriginalLowSpeedTraction(vehicle)
    if not orig then return end
    pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fLowSpeedTractionLossMult", orig * mult)
end

local function getOriginalTraction(vehicle)
    if vehicleCache[vehicle] and vehicleCache[vehicle].origTraction then
        return vehicleCache[vehicle].origTraction
    end
    local ok, val = pcall(function()
        return GetVehicleHandlingFloat(vehicle, "CHandlingData", tractionField)
    end)
    if ok and val and val > 0 then
        vehicleCache[vehicle] = vehicleCache[vehicle] or {}
        vehicleCache[vehicle].origTraction = val
        vehicleCache[vehicle].tractionField = tractionField
        return val
    end
    return nil
end

local function getOriginalTractionCurveMin(vehicle)
    if vehicleCache[vehicle] and vehicleCache[vehicle].origTractionCurveMin ~= nil then
        return vehicleCache[vehicle].origTractionCurveMin
    end
    local ok, val = pcall(GetVehicleHandlingFloat, vehicle, "CHandlingData", "fTractionCurveMin")
    if ok and val and val > 0 then
        vehicleCache[vehicle] = vehicleCache[vehicle] or {}
        vehicleCache[vehicle].origTractionCurveMin = val
        return val
    end
    return nil
end

local function getOriginalTractionCurveLateral(vehicle)
    if vehicleCache[vehicle] and vehicleCache[vehicle].origTractionCurveLateral ~= nil then
        return vehicleCache[vehicle].origTractionCurveLateral
    end
    local ok, val = pcall(GetVehicleHandlingFloat, vehicle, "CHandlingData", "fTractionCurveLateral")
    if ok and val and val > 0 then
        vehicleCache[vehicle] = vehicleCache[vehicle] or {}
        vehicleCache[vehicle].origTractionCurveLateral = val
        return val
    end
    return nil
end

local function applyGripModifier(vehicle, effectiveGripMod, minOverride)
    if not DoesEntityExist(vehicle) then
        vehicleCache[vehicle] = nil
        return
    end
    local floor = (minOverride ~= nil and minOverride >= 0) and minOverride or minMod
    effectiveGripMod = math.max(floor, math.min(1.0, effectiveGripMod))
    local orig = getOriginalTraction(vehicle)
    if not orig then return end
    local newVal = orig * effectiveGripMod
    pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", tractionField, newVal)
    if cfg.applyToCurveMin then
        local origMin = getOriginalTractionCurveMin(vehicle)
        if origMin then
            pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fTractionCurveMin", origMin * effectiveGripMod)
        end
    end
    -- Lateral (cornering) grip: reduces spinout when steering at speed
    if cfg.applyToLateral then
        local origLat = getOriginalTractionCurveLateral(vehicle)
        if origLat then
            pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fTractionCurveLateral", origLat * effectiveGripMod)
        end
    end
end

local function resetVehicleHandling(vehicle)
    local c = vehicleCache[vehicle]
    if c and DoesEntityExist(vehicle) then
        if c.origTraction then
            pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", c.tractionField or tractionField, c.origTraction)
        end
        if c.origTractionCurveMin and cfg.applyToCurveMin then
            pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fTractionCurveMin", c.origTractionCurveMin)
        end
        if c.origTractionCurveLateral and cfg.applyToLateral then
            pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fTractionCurveLateral", c.origTractionCurveLateral)
        end
        if c.origLowSpeedTraction ~= nil then
            pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fLowSpeedTractionLossMult", c.origLowSpeedTraction)
        end
        if c.origHandlingFlags ~= nil then
            pcall(SetVehicleHandlingInt, vehicle, "CHandlingData", "strHandlingFlags", c.origHandlingFlags)
        end
        if c.origMass ~= nil then
            pcall(SetVehicleHandlingFloat, vehicle, "CHandlingData", "fMass", c.origMass)
        end
    end
    vehicleCache[vehicle] = nil
end

local function isNetworkOwner(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if not NetworkGetEntityIsNetworked or not NetworkGetEntityIsNetworked(vehicle) then return true end
    return NetworkGetEntityOwner(vehicle) == PlayerId()
end

local function applyHandlingFlags(vehicle)
    if not flagsCfg or not DoesEntityExist(vehicle) then return end
    local ok, intHandling = pcall(GetVehicleHandlingInt, vehicle, "CHandlingData", "strHandlingFlags")
    local okAdv, intAdv = pcall(GetVehicleHandlingInt, vehicle, "CCarHandlingData", "strAdvancedFlags")
    if not ok or not okAdv then return end
    local handling = intHandling or 0
    local adv = intAdv or 0
    if flagsCfg.rallyTyres then handling = handling | 0x8 end
    if flagsCfg.applyTractionControl and not (customTC.enabled) then adv = adv | 0x2000 end
    if flagsCfg.applyStabilityControl then adv = adv | 0x4000 end
    if flagsCfg.fixOldBugs then adv = adv | 0x4000000 end
    pcall(SetVehicleHandlingInt, vehicle, "CHandlingData", "strHandlingFlags", handling)
    pcall(SetVehicleHandlingInt, vehicle, "CCarHandlingData", "strAdvancedFlags", adv)
end

CreateThread(function()
    if not enabled then return end
    local lastVeh = 0
    while true do
        Wait(updateInterval)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            if lastVeh ~= 0 then
                resetVehicleHandling(lastVeh)
                if RestoreDamagePerformance then RestoreDamagePerformance(lastVeh) end
                lastVeh = 0
            end
            if ResetTireTemp then ResetTireTemp() end
            if ResetTireWear then ResetTireWear() end
        else
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) ~= ped then goto continue end

            -- Restore handling if we lost network ownership (e.g. another player took over)
            if lastVeh == veh and not isNetworkOwner(veh) then
                resetVehicleHandling(veh)
                if RestoreDamagePerformance then RestoreDamagePerformance(veh) end
                lastVeh = 0
                goto continue
            end
            lastVeh = veh

            UpdateRoadWetness()
            UpdateTireTemp(veh)

            local vc = GetVehicleClass(veh)
            local surfaceGrip = GetVehicleGroundGrip(veh, GetRoadWetness())
            local weatherMod = GetWeatherGripModifier()
            local isBike = (vc == 8 or vc == 13)
            local isOffroad = isOffroadClass(vc)

            -- Tire modifier: skip cold penalty for bikes, off-road, and road cars at launch
            local tireMod
            if isBike and cfg.skipBikeTireTemp then
                tireMod = 1.0
            elseif not isOffroad then
                local launchCfg = cfg.roadLaunchGrip or {}
                local rrg = cfg.realisticRoadGrip or {}
                local vx, vy, vz = GetEntityVelocity(veh)
                local speedMps = (vx and vy and vz) and math.sqrt(vx*vx + vy*vy + vz*vz) or 0
                local tireSkipSpeed = math.max(launchCfg.speedMps or 18, rrg.speedMps or 0)
                if (launchCfg.enabled or rrg.enabled) and speedMps < tireSkipSpeed
                    and surfaceGrip >= (launchCfg.surfaceGripMin or rrg.surfaceGripMin or 0.26) then
                    tireMod = 1.0  -- full grip on pavement (skip cold penalty in realistic zone)
                else
                    tireMod = GetTireGripModifier and GetTireGripModifier() or 1.0
                end
            elseif isOffroad then
                local preset = getOffroadPreset(veh)
                tireMod = (preset and preset.skipTireTempPenalty) and 1.0 or (GetTireGripModifier and GetTireGripModifier() or 1.0)
            else
                tireMod = GetTireGripModifier and GetTireGripModifier() or 1.0
            end
            local damageMod = GetDamageGripModifier and GetDamageGripModifier(veh) or 1.0

            -- Scale surface grip to 0-1: dry tarmac (0.36) = 1.0, wet/ice = lower
            local surfaceRef = cfg.surfaceGripReference or 0.36
            local surfaceMod = math.min(1.0, surfaceGrip / surfaceRef)
            local effectiveMod = surfaceMod * weatherMod * tireMod * damageMod

            -- Realistic road grip: full stock handling on dry pavement at normal driving speeds
            local rrg = cfg.realisticRoadGrip or {}
            if not isOffroad and not isBike and rrg.enabled then
                local vx, vy, vz = GetEntityVelocity(veh)
                local speedMps = (vx and vy and vz) and math.sqrt(vx*vx + vy*vy + vz*vz) or 0
                if speedMps < (rrg.speedMps or 45) and surfaceGrip >= (rrg.surfaceGripMin or 0.28)
                    and weatherMod >= (rrg.weatherGripMin or 0.92) and (not damageMod or damageMod >= 0.98) then
                    effectiveMod = 1.0  -- full grip, no reduction (realistic dry pavement)
                end
            end

            -- Aero downforce: cars in motion stay in motion, less spinout when steering at speed
            local aero = cfg.aeroDownforce or {}
            if not isOffroad and not isBike and aero.enabled then
                local vx, vy, vz = GetEntityVelocity(veh)
                local speedMps = (vx and vy and vz) and math.sqrt(vx*vx + vy*vy + vz*vz) or 0
                if speedMps >= (aero.speedMpsMin or 15) and surfaceGrip >= (aero.surfaceGripMin or 0.28) then
                    local spdMin, spdMax = aero.speedMpsMin or 15, aero.speedMpsMax or 55
                    local t = math.min(1.0, (speedMps - spdMin) / math.max(1, spdMax - spdMin))
                    local boost = (aero.gripBoostMax or 0.12) * t
                    effectiveMod = math.min(1.0, effectiveMod + boost)
                end
            end

            -- Road cars at low speed on pavement: grip floor + keyboard compensation
            if not isOffroad and not isBike then
                local vx, vy, vz = GetEntityVelocity(veh)
                local speedMps = (vx and vy and vz) and math.sqrt(vx*vx + vy*vy + vz*vz) or 0
                local lc = cfg.roadLaunchGrip or {}
                if lc.enabled and speedMps < (lc.speedMps or 15) and surfaceGrip >= (lc.surfaceGripMin or 0.25) then
                    local gripFloor = lc.gripFloor or 0.95
                    local tractionMult = lc.lowSpeedTractionMult or 0.5
                    -- Keyboard compensation: high throttle at launch = can't modulate (binary 0/100%)
                    local kc = lc.keyboardLaunchCompensation or {}
                    if kc.enabled then
                        local throttle = GetControlNormal(0, 71) or 0
                        if throttle >= (kc.throttleThreshold or 0.82) then
                            gripFloor = kc.gripFloor or 1.0
                            tractionMult = kc.lowSpeedTractionMult or 0.35
                        end
                    end
                    effectiveMod = math.max(effectiveMod, gripFloor)
                    -- Apply low-speed traction in the road-on-pavement block below (we pass via cache for this tick)
                    vehicleCache[veh] = vehicleCache[veh] or {}
                    vehicleCache[veh]._keyboardLaunchTractionMult = tractionMult
                else
                    if vehicleCache[veh] then vehicleCache[veh]._keyboardLaunchTractionMult = nil end
                end
                if vehicleCache[veh] then vehicleCache[veh].lastEffectiveGrip = nil end
            end

            -- Off-road (class 9): SnowRunner difficulty
            if isOffroad then
                local oCfg = cfg.offroad or {}
                local surfMod = oCfg.surfaceGripMod or {}
                local category = getOffroadSurfaceCategory(surfaceGrip)
                effectiveMod = effectiveMod * (surfMod[category] or 1.0)
                local preset = getOffroadPreset(veh)
                if preset.gripFloorOnLoose and isOnLooseSurface(surfaceGrip) then
                    effectiveMod = math.max(effectiveMod, preset.gripFloorOnLoose)
                end
                if preset.gripCap then
                    effectiveMod = math.min(effectiveMod, preset.gripCap)
                end
                if preset.massScale then
                    effectiveMod = lerp(1.0, effectiveMod, preset.massScale)
                end
                -- Hill penalty: climbing on loose surfaces (SnowRunner style)
                local hillCfg = oCfg.hillPenalty or {}
                if hillCfg.enabled ~= false and isOnLooseSurface(surfaceGrip) then
                    local pitch = getVehiclePitchDeg(veh)
                    if pitch > (hillCfg.pitchDeg or 5) then
                        effectiveMod = effectiveMod * (hillCfg.gripMult or 0.60)
                    end
                end
                if preset.lowSpeedTractionMult then
                    local mult = (category == "paved") and 1.0 or preset.lowSpeedTractionMult
                    applyLowSpeedTractionMod(veh, mult)
                end
                if preset.rallyTyres then
                    vehicleCache[veh] = vehicleCache[veh] or {}
                    if not vehicleCache[veh].rallyApplied then
                        local ok, h = pcall(GetVehicleHandlingInt, veh, "CHandlingData", "strHandlingFlags")
                        if ok and h then
                            vehicleCache[veh].origHandlingFlags = h
                            pcall(SetVehicleHandlingInt, veh, "CHandlingData", "strHandlingFlags", h | 0x8)
                            vehicleCache[veh].rallyApplied = true
                        end
                    end
                end
                local ls = preset.launchSmoothing
                if ls then
                    local v = GetEntityVelocity(veh)
                    local speedMps = (v and v.x) and math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) or 0
                    if speedMps < (ls.speedMps or 5.0) then
                        local cache = vehicleCache[veh] or {}
                        effectiveMod = lerp(cache.lastEffectiveGrip or effectiveMod, effectiveMod, ls.lerp or 0.35)
                        cache.lastEffectiveGrip = effectiveMod
                        vehicleCache[veh] = cache
                    end
                end
            -- Bikes get extra grip boost
            elseif isBike and cfg.bikeGripModifier and cfg.bikeGripModifier > 1.0 then
                effectiveMod = math.min(1.0, effectiveMod * cfg.bikeGripModifier)
            -- Heavy vehicles (industrial, utility, service, commercial)
            elseif isHeavyOffroadClass(vc) then
                local classCaps = cfg.classGripCap
                if classCaps and classCaps[vc] then
                    effectiveMod = math.min(effectiveMod, classCaps[vc])
                end
                if cfg.heavyMass then
                    local mass = GetEntityMass and GetEntityMass(veh) or nil
                    if mass and mass > (cfg.heavyMass.threshold or 2200.0) then
                        local scale = cfg.heavyMass.scale or 0.9
                        effectiveMod = lerp(1.0, effectiveMod, scale)
                    end
                end
                local ls = cfg.launchSmoothing
                if ls then
                    local v = GetEntityVelocity(veh)
                    local speedMps = (v and v.x) and math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) or 0
                    local cache = vehicleCache[veh] or {}
                    if speedMps < (ls.speedMps or 5.0) then
                        effectiveMod = lerp(cache.lastEffectiveGrip or effectiveMod, effectiveMod, ls.lerp or 0.35)
                    end
                    cache.lastEffectiveGrip = effectiveMod
                    vehicleCache[veh] = cache
                end
            end

            -- Road vehicles off-road: SnowRunner struggle on dirt, gravel, hills, mud
            local mudMinGrip = nil
            if not isOffroad then
                local rCfg = cfg.roadVehicleOffroad or {}
                local onOffroad = isOnOffroadSurface(surfaceGrip)
                if onOffroad and rCfg.enabled then
                    local gripMult = getRoadVehicleOffroadGripMult(surfaceGrip)
                    effectiveMod = effectiveMod * gripMult
                    local pitch = getVehiclePitchDeg(veh)
                    if pitch > (rCfg.hillPitchDeg or 6) then
                        effectiveMod = effectiveMod * (rCfg.hillGripMult or 0.55)
                    end
                    applyLowSpeedTractionMod(veh, rCfg.lowSpeedTractionMult or 2.2)
                else
                    -- On pavement: reduce low-speed wheelspin at launch
                    local lc = cfg.roadLaunchGrip or {}
                    local vx, vy, vz = GetEntityVelocity(veh)
                    local spd = (vx and vy and vz) and math.sqrt(vx*vx + vy*vy + vz*vz) or 0
                    if lc.enabled and spd < (lc.speedMps or 22) and surfaceGrip >= (lc.surfaceGripMin or 0.26) then
                        local mult = lc.lowSpeedTractionMult or 0.5
                        -- Use keyboard compensation value if set (high throttle at launch)
                        local cache = vehicleCache[veh]
                        if cache and cache._keyboardLaunchTractionMult then
                            mult = cache._keyboardLaunchTractionMult
                        end
                        applyLowSpeedTractionMod(veh, mult)
                    else
                        applyLowSpeedTractionMod(veh, 1.0)
                    end
                end
            end

            -- Mud/Marsh/Sand: SnowRunner sink (road + off-road when enabled)
            local mCfg = cfg.mudStuck or {}
            local onMud = isOnMudSurface(surfaceGrip)
            local mudLevel = updateMudStuckLevel(veh, onMud)
            if mudLevel > 0 and mCfg.enabled then
                local mudScale = 1.0
                if isOffroad then
                    mudScale = mCfg.applyToOffroad and (mCfg.offroadMult or 0.6) or 0
                end
                if mudScale > 0 then
                    local mult = 1.0 - (mudLevel * (mCfg.maxGripMult or 0.75) * mudScale)
                    effectiveMod = effectiveMod * math.max(0.04, mult)
                    mudMinGrip = mCfg.minGripWhenStuck or 0.08
                    if isNetworkOwner(veh) then
                        local extraKg = mudLevel * (mCfg.maxExtraMassKg or 600) * mudScale
                        applyExtraMass(veh, extraKg)
                    end
                elseif isNetworkOwner(veh) then
                    applyExtraMass(veh, 0)
                end
            elseif isNetworkOwner(veh) then
                applyExtraMass(veh, 0)
            end

            -- Base grip mult: slightly lower for realism (weight/mass feels more)
            local baseMult = cfg.baseGripMult or 1.0
            effectiveMod = effectiveMod * baseMult

            if useHandlingOverride and isNetworkOwner(veh) then
                applyGripModifier(veh, effectiveMod, mudMinGrip)
            end
            if ApplyDamagePerformance and isNetworkOwner(veh) then
                ApplyDamagePerformance(veh)
            end
            local wantFlags = flagsCfg and (flagsCfg.applyTractionControl or flagsCfg.applyStabilityControl or flagsCfg.fixOldBugs or flagsCfg.rallyTyres)
            if wantFlags then
                vehicleCache[veh] = vehicleCache[veh] or {}
                if not vehicleCache[veh].flagsApplied then
                    applyHandlingFlags(veh)
                    vehicleCache[veh].flagsApplied = true
                end
            end
            ::continue::
        end
    end
end)

AddEventHandler("onResourceStop", function(name)
    if GetCurrentResourceName() ~= name then return end
    for veh, _ in pairs(vehicleCache) do
        if DoesEntityExist(veh) then
            resetVehicleHandling(veh)
            if RestoreDamagePerformance then RestoreDamagePerformance(veh) end
        end
    end
end)
