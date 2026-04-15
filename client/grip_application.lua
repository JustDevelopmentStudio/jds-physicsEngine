--[[
    jds-physicsEngine :: Grip Application v2
    ==========================================
    COMPLETE REWRITE — Clean, predictable, linear pipeline.
    
    Philosophy:
    -----------
    1. On DRY PAVEMENT, road cars get STOCK or BETTER grip. Always. No exceptions.
    2. Grip reductions ONLY happen from: weather, off-road surfaces, damage, mud.
    3. The traction control in torque_simulator.lua handles wheelspin — NOT this file.
    4. This file handles the TIRE'S ability to grip the road surface. Period.
    
    Pipeline (executed in order, no compounding):
    -----------------------------------------------
    Step 1: Calculate surface ratio (surface grip / reference = how good is this road?)
    Step 2: Apply weather penalty (rain/snow reducing mu)
    Step 3: Apply tire condition (temp + wear)
    Step 4: Apply damage penalty
    Step 5: Apply base grip multiplier (user tunable global knob)
    Step 6: Road floor — on pavement, grip is NEVER below 1.0 (stock)
    Step 7: Off-road / mud penalties (only for dirt/grass/sand surfaces)
    Step 8: Write final value to vehicle handling
]]

local cfg = (Config.PhysicsAdvanced or {}).gripApplication or {}
local enabled = (Config.PhysicsAdvanced or {}).enabled
local useHandlingOverride = cfg.useHandlingOverride ~= false
local updateInterval = cfg.updateIntervalMs or 50
local tractionField = "fTractionCurveMax"
local flagsCfg = cfg.handlingFlags or {}
local customTC = cfg.customTractionControl or {}

local vehicleCache = {}

---------------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------------
local function lerp(a, b, t)
    return a + (b - a) * math.max(0, math.min(1, t))
end

local function clamp(val, lo, hi)
    return math.max(lo, math.min(hi, val))
end

local function getSpeed(veh)
    local v = GetEntityVelocity(veh)
    if not v or not v.x then return 0 end
    return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
end

---------------------------------------------------------------------------
-- Vehicle class helpers
---------------------------------------------------------------------------
local function isBikeClass(vc)
    return vc == 8 or vc == 13
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

local function isHeavyClass(vc)
    return vc == 10 or vc == 11 or vc == 17 or vc == 20
end

local function isPavedSurface(surfaceGrip)
    return surfaceGrip >= (cfg.pavedThreshold or 0.25)
end

---------------------------------------------------------------------------
-- Original handling cache (stores stock values ONCE per vehicle entity)
---------------------------------------------------------------------------
local function cacheOriginals(veh)
    if vehicleCache[veh] and vehicleCache[veh].origTraction then return end
    vehicleCache[veh] = vehicleCache[veh] or {}
    local c = vehicleCache[veh]
    
    local ok1, v1 = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveMax")
    if ok1 and v1 and v1 > 0 then c.origTraction = v1 end
    
    local ok2, v2 = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveMin")
    if ok2 and v2 and v2 > 0 then c.origTractionMin = v2 end
    
    local ok3, v3 = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveLateral")
    if ok3 and v3 and v3 > 0 then c.origLateral = v3 end
    
    local ok4, v4 = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fLowSpeedTractionLossMult")
    if ok4 and v4 ~= nil then c.origLowSpeedLoss = v4 end
    
    local ok5, v5 = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fMass")
    if ok5 and v5 and v5 > 0 then c.origMass = v5 end
end

---------------------------------------------------------------------------
-- Apply final grip modifier to vehicle handling data
---------------------------------------------------------------------------
local function applyGrip(veh, gripMod)
    local c = vehicleCache[veh]
    if not c or not c.origTraction then return end
    
    local minFloor = cfg.minGripModifier or 0.20
    gripMod = clamp(gripMod, minFloor, 5.0)
    
    pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveMax",
        c.origTraction * gripMod)
    
    if cfg.applyToCurveMin and c.origTractionMin then
        pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveMin",
            c.origTractionMin * gripMod)
    end
    
    if cfg.applyToLateral and c.origLateral then
        pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveLateral",
            c.origLateral * gripMod)
    end
end

local function setLowSpeedLoss(veh, mult)
    local c = vehicleCache[veh]
    if not c or c.origLowSpeedLoss == nil then return end
    pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fLowSpeedTractionLossMult",
        c.origLowSpeedLoss * mult)
end

local function setMass(veh, extraKg)
    local c = vehicleCache[veh]
    if not c or not c.origMass then return end
    pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fMass", c.origMass + extraKg)
end

---------------------------------------------------------------------------
-- Reset vehicle to stock handling
---------------------------------------------------------------------------
local function resetHandling(veh)
    local c = vehicleCache[veh]
    if not c or not DoesEntityExist(veh) then
        vehicleCache[veh] = nil
        return
    end
    if c.origTraction then
        pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveMax", c.origTraction)
    end
    if c.origTractionMin then
        pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveMin", c.origTractionMin)
    end
    if c.origLateral then
        pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fTractionCurveLateral", c.origLateral)
    end
    if c.origLowSpeedLoss ~= nil then
        pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fLowSpeedTractionLossMult", c.origLowSpeedLoss)
    end
    if c.origMass then
        pcall(SetVehicleHandlingFloat, veh, "CHandlingData", "fMass", c.origMass)
    end
    if c.origHandlingFlags ~= nil then
        pcall(SetVehicleHandlingInt, veh, "CHandlingData", "strHandlingFlags", c.origHandlingFlags)
    end
    vehicleCache[veh] = nil
end

---------------------------------------------------------------------------
-- Network ownership check
---------------------------------------------------------------------------
local function isNetworkOwner(veh)
    if not veh or not DoesEntityExist(veh) then return false end
    if not NetworkGetEntityIsNetworked or not NetworkGetEntityIsNetworked(veh) then return true end
    return NetworkGetEntityOwner(veh) == PlayerId()
end

---------------------------------------------------------------------------
-- Handling flags (one-time apply)
---------------------------------------------------------------------------
local function applyHandlingFlags(veh)
    if not flagsCfg then return end
    local ok, h = pcall(GetVehicleHandlingInt, veh, "CHandlingData", "strHandlingFlags")
    local ok2, a = pcall(GetVehicleHandlingInt, veh, "CCarHandlingData", "strAdvancedFlags")
    if not ok or not ok2 then return end
    local handling = h or 0
    local adv = a or 0
    if flagsCfg.rallyTyres then handling = handling | 0x8 end
    if flagsCfg.applyTractionControl and not customTC.enabled then adv = adv | 0x2000 end
    if flagsCfg.applyStabilityControl then adv = adv | 0x4000 end
    if flagsCfg.fixOldBugs then adv = adv | 0x4000000 end
    pcall(SetVehicleHandlingInt, veh, "CHandlingData", "strHandlingFlags", handling)
    pcall(SetVehicleHandlingInt, veh, "CCarHandlingData", "strAdvancedFlags", adv)
end

---------------------------------------------------------------------------
-- Off-road surface classification
---------------------------------------------------------------------------
local function getOffroadCategory(surfaceGrip)
    if surfaceGrip > 0.30 then return "paved" end
    if surfaceGrip > 0.22 then return "gravel" end
    if surfaceGrip > 0.16 then return "dirt" end
    if surfaceGrip > 0.13 then return "grass" end
    return "mud"
end

---------------------------------------------------------------------------
-- Mud stuck accumulator
---------------------------------------------------------------------------
local function updateMudLevel(veh, isMud)
    local mCfg = cfg.mudStuck or {}
    if not mCfg.enabled then return 0 end
    vehicleCache[veh] = vehicleCache[veh] or {}
    local c = vehicleCache[veh]
    local level = c.mudLevel or 0
    if isMud then
        level = math.min(1.0, level + (mCfg.buildRate or 0.07))
    else
        level = math.max(0.0, level - (mCfg.decayRate or 0.015))
    end
    c.mudLevel = level
    return level
end

---------------------------------------------------------------------------
-- MAIN GRIP LOOP
---------------------------------------------------------------------------
CreateThread(function()
    if not enabled then return end
    local lastVeh = 0
    
    while true do
        Wait(updateInterval)
        local ped = PlayerPedId()
        
        -- Not in vehicle: reset everything
        if not IsPedInAnyVehicle(ped, false) then
            if lastVeh ~= 0 then
                resetHandling(lastVeh)
                if RestoreDamagePerformance then RestoreDamagePerformance(lastVeh) end
                lastVeh = 0
            end
            if ResetTireTemp then ResetTireTemp() end
            if ResetTireWear then ResetTireWear() end
            goto continue
        end
        
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then goto continue end
        
        -- Lost network ownership: bail
        if lastVeh == veh and not isNetworkOwner(veh) then
            resetHandling(veh)
            if RestoreDamagePerformance then RestoreDamagePerformance(veh) end
            lastVeh = 0
            goto continue
        end
        lastVeh = veh
        
        -- Cache stock handling values (only runs once per entity)
        cacheOriginals(veh)
        
        -- Update systems
        UpdateRoadWetness()
        UpdateTireTemp(veh)
        
        -- Gather data
        local vc = GetVehicleClass(veh)
        local surfaceGrip = GetVehicleGroundGrip(veh, GetRoadWetness())
        local weatherMod = GetWeatherGripModifier()
        local isBike = isBikeClass(vc)
        local isOffroad = isOffroadClass(vc)
        local speedMps = getSpeed(veh)
        local paved = isPavedSurface(surfaceGrip)
        
        ---------------------------------------------------------------
        -- STEP 1: Surface ratio
        -- On dry tarmac (0.33), with reference 0.33, this = 1.0
        -- Anything above tarmac > 1.0, anything below < 1.0
        ---------------------------------------------------------------
        local surfRef = cfg.surfaceGripReference or 0.33
        local surfaceMod = surfaceGrip / surfRef
        
        ---------------------------------------------------------------
        -- STEP 2: Weather
        ---------------------------------------------------------------
        -- weatherMod is already 0.0-1.0 from weather system
        
        ---------------------------------------------------------------
        -- STEP 3: Tire condition
        -- On pavement, skip cold penalty entirely (cars should grip cold)
        ---------------------------------------------------------------
        local tireMod = 1.0
        if isBike and cfg.skipBikeTireTemp then
            tireMod = 1.0
        elseif paved and speedMps < 20 then
            tireMod = 1.0  -- No cold penalty on roads
        else
            tireMod = GetTireGripModifier and GetTireGripModifier() or 1.0
        end
        
        ---------------------------------------------------------------
        -- STEP 4: Damage
        ---------------------------------------------------------------
        local damageMod = GetDamageGripModifier and GetDamageGripModifier(veh) or 1.0
        
        ---------------------------------------------------------------
        -- STEP 5: Combine + base multiplier
        ---------------------------------------------------------------
        local baseMult = cfg.baseGripMult or 1.25
        local effectiveMod = surfaceMod * weatherMod * tireMod * damageMod * baseMult
        
        ---------------------------------------------------------------
        -- STEP 6: ROAD FLOOR — prevent compounding bugs
        -- On paved road, grip never drops below baseGripMult.
        -- This prevents weather/tire/damage from accidentally zeroing grip,
        -- but still respects the user's chosen baseGripMult tuning.
        ---------------------------------------------------------------
        if paved and not isOffroad then
            effectiveMod = math.max(baseMult, effectiveMod)
        end
        
        ---------------------------------------------------------------
        -- STEP 7: Aero downforce (speed-based grip bonus)
        ---------------------------------------------------------------
        local aero = cfg.aeroDownforce or {}
        if not isOffroad and not isBike and aero.enabled then
            if speedMps >= (aero.speedMpsMin or 15) and paved then
                local spdMin = aero.speedMpsMin or 15
                local spdMax = aero.speedMpsMax or 55
                local t = clamp((speedMps - spdMin) / math.max(1, spdMax - spdMin), 0, 1)
                local boost = (aero.gripBoostMax or 0.15) * t
                effectiveMod = effectiveMod + boost
            end
        end
        
        ---------------------------------------------------------------
        -- STEP 8: Bikes get a flat grip boost
        ---------------------------------------------------------------
        if isBike and cfg.bikeGripModifier and cfg.bikeGripModifier > 1.0 then
            effectiveMod = effectiveMod * cfg.bikeGripModifier
        end
        
        ---------------------------------------------------------------
        -- STEP 9: Off-road surface penalties
        -- Only kicks in when driving on actual dirt/grass/mud
        ---------------------------------------------------------------
        if not paved then
            if isOffroad then
                -- Off-road vehicles: moderate penalty
                local oCfg = cfg.offroad or {}
                local surfMod = oCfg.surfaceGripMod or {}
                local cat = getOffroadCategory(surfaceGrip)
                effectiveMod = effectiveMod * (surfMod[cat] or 1.0)
                
                -- Hill penalty on loose surfaces
                local hillCfg = oCfg.hillPenalty or {}
                if hillCfg.enabled ~= false then
                    local ok, pitch = pcall(GetEntityPitch, veh)
                    if ok and pitch and pitch > (hillCfg.pitchDeg or 5) then
                        effectiveMod = effectiveMod * (hillCfg.gripMult or 0.60)
                    end
                end
            elseif not isBike then
                -- Road cars on dirt: severe penalty
                local rCfg = cfg.roadVehicleOffroad or {}
                if rCfg.enabled then
                    local pavedThresh = rCfg.surfaceGripPaved or 0.30
                    local minMult = rCfg.gripMultMin or 0.18
                    local maxMult = rCfg.gripMultMax or 0.45
                    local t = clamp((surfaceGrip - 0.10) / (pavedThresh - 0.10), 0, 1)
                    local offMult = minMult + (maxMult - minMult) * t
                    effectiveMod = effectiveMod * offMult
                    
                    -- Hill penalty
                    local ok, pitch = pcall(GetEntityPitch, veh)
                    if ok and pitch and pitch > (rCfg.hillPitchDeg or 4) then
                        effectiveMod = effectiveMod * (rCfg.hillGripMult or 0.35)
                    end
                end
            end
        end
        
        ---------------------------------------------------------------
        -- STEP 10: Mud stuck simulation
        ---------------------------------------------------------------
        local mCfg = cfg.mudStuck or {}
        local isMud = mCfg.enabled and surfaceGrip < (mCfg.surfaceGripMax or 0.20)
        local mudLevel = updateMudLevel(veh, isMud)
        
        if mudLevel > 0 and mCfg.enabled and isNetworkOwner(veh) then
            local mudScale = isOffroad and (mCfg.offroadMult or 0.6) or 1.0
            local gripLoss = mudLevel * (mCfg.maxGripMult or 0.92) * mudScale
            effectiveMod = effectiveMod * math.max(0.04, 1.0 - gripLoss)
            setMass(veh, mudLevel * (mCfg.maxExtraMassKg or 200) * mudScale)
        elseif isNetworkOwner(veh) then
            setMass(veh, 0)
        end
        
        ---------------------------------------------------------------
        -- STEP 11: Low-speed traction loss management
        -- On pavement: REDUCE fLowSpeedTractionLossMult to help launch
        -- Off road: INCREASE it to simulate slippery surfaces
        ---------------------------------------------------------------
        if isNetworkOwner(veh) then
            if paved and not isOffroad and not isBike then
                -- On pavement, reduce traction loss so the car hooks up
                local lossReduction = cfg.pavementLowSpeedLossMult or 0.40
                setLowSpeedLoss(veh, lossReduction)
            elseif not paved and not isOffroad then
                -- Road car on dirt: increase loss
                local rCfg = cfg.roadVehicleOffroad or {}
                setLowSpeedLoss(veh, rCfg.lowSpeedTractionMult or 3.5)
            else
                setLowSpeedLoss(veh, 1.0)
            end
        end
        
        ---------------------------------------------------------------
        -- STEP 12: Hydroplaning (wet road, high speed = random grip loss)
        ---------------------------------------------------------------
        local wetLevel = GetRoadWetness and GetRoadWetness() or 0
        if wetLevel > 0.35 and speedMps > 38.0 then
            local riskFactor = (speedMps - 38.0) * wetLevel * 0.015
            if math.random() < riskFactor then
                effectiveMod = 0.08
            end
        end
        
        ---------------------------------------------------------------
        -- FINAL: Write to vehicle
        ---------------------------------------------------------------
        if useHandlingOverride and isNetworkOwner(veh) then
            applyGrip(veh, effectiveMod)
        end
        
        if ApplyDamagePerformance and isNetworkOwner(veh) then
            ApplyDamagePerformance(veh)
        end
        
        -- One-time handling flags
        vehicleCache[veh] = vehicleCache[veh] or {}
        if not vehicleCache[veh].flagsApplied then
            applyHandlingFlags(veh)
            vehicleCache[veh].flagsApplied = true
        end
        
        ::continue::
    end
end)

---------------------------------------------------------------------------
-- Cleanup on resource stop
---------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(name)
    if GetCurrentResourceName() ~= name then return end
    for veh, _ in pairs(vehicleCache) do
        if DoesEntityExist(veh) then
            resetHandling(veh)
            if RestoreDamagePerformance then RestoreDamagePerformance(veh) end
        end
    end
end)
