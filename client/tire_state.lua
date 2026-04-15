--[[
    jds-physicsEngine :: Tire Temperature & Wear v2
    =================================================
    COMPLETE REWRITE — True per-wheel physics.
    
    Each tire has its own independent temperature driven by:
    - Wheel slip (burnout/wheelspin) — ONLY the spinning wheel heats up
    - Braking — front tires get more heat (brake bias)
    - Cornering — outside tires load more and heat faster
    - Rolling friction — all tires warm gently from driving
    - Airflow cooling — faster speed = more cooling
    - Ambient radiation — tires always cool toward road temp
    
    A RWD burnout will ONLY heat the rear tires.
    A FWD burnout will ONLY heat the front tires.
]]

local cfg = (Config.PhysicsAdvanced or {}).tireTemp or {}
local wearCfg = (Config.PhysicsAdvanced or {}).tireWear or {}
local enabled = cfg.enabled ~= false
local wearEnabled = wearCfg.enabled

-- Config values with sane defaults
local HEAT_RATE       = cfg.heatRate or 0.85
local COOL_RATE       = cfg.coolRate or 0.25
local AMBIENT_TEMP    = cfg.ambientFallback or 20
local OPTIMAL_MIN     = cfg.optimalMin or 65
local OPTIMAL_MAX     = cfg.optimalMax or 115
local COLD_MOD        = cfg.coldModifier or 0.98
local HOT_MOD         = cfg.hotModifier or 0.75
local BLOWOUT_TEMP    = 150.0
local MAX_TEMP        = 155.0

-- Per-wheel state: 0=FL, 1=FR, 2=RL, 3=RR
local tireTemp = { [0] = AMBIENT_TEMP, AMBIENT_TEMP, AMBIENT_TEMP, AMBIENT_TEMP }
local tireWear = 0.0
local lastUpdate = GetGameTimer() / 1000.0
local lastPos = nil
local _lastEngineHealth = nil

---------------------------------------------------------------------------
-- Drivetrain detection (cached per vehicle)
---------------------------------------------------------------------------
local driveCache = {}

local function getDrivenWheels(veh)
    if driveCache[veh] then return driveCache[veh] end
    
    local numWheels = GetVehicleNumberOfWheels(veh) or 4
    local ok, bias = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fDriveBiasFront")
    if not ok or not bias then bias = 0.5 end
    
    local result
    if numWheels <= 2 then
        -- Bike
        if bias <= 0.15 then result = { [0] = false, true }       -- RWD
        elseif bias >= 0.85 then result = { [0] = true, false }   -- FWD
        else result = { [0] = true, true }                         -- AWD
        end
    else
        if bias >= 0.85 then result = { [0] = true, true, false, false }       -- FWD
        elseif bias <= 0.15 then result = { [0] = false, false, true, true }   -- RWD
        else result = { [0] = true, true, true, true }                         -- AWD
        end
    end
    
    driveCache[veh] = result
    return result
end

local function getBrakeBias(veh)
    local ok, bias = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fBrakeBiasFront")
    if not ok or not bias then return 0.65 end
    return math.max(0.3, math.min(0.9, bias))
end

---------------------------------------------------------------------------
-- Ambient / Road temperature
---------------------------------------------------------------------------
function GetAmbientTemp()
    local ambCfg = Config.AmbientTemp or {}
    if ambCfg.fallbackFromWeather == false then
        return ambCfg.fallbackBase or AMBIENT_TEMP
    end
    local base = ambCfg.fallbackBase or 18
    local swing = ambCfg.fallbackSwing or 10
    local h = GetClockHours() + GetClockMinutes() / 60
    local t = GlobalState and GlobalState.currentTime
    if t and t.hour ~= nil then h = t.hour + (t.minute or 0) / 60 end
    local temp = base + swing * math.sin((h - 6) * math.pi / 12)
    local weather = (GlobalState and GlobalState.weather and GlobalState.weather.weather) or "CLEAR"
    local mod = ambCfg.weatherTempMod and ambCfg.weatherTempMod[weather]
    if type(mod) == "number" then temp = temp + mod end
    return temp
end

function GetClimateTemp() return GetAmbientTemp() end

function GetRoadTemp()
    local ambCfg = Config.AmbientTemp or {}
    local roadCfg = ambCfg.roadTemp or {}
    if roadCfg.enabled == false then return GetAmbientTemp() end
    local climate = GetAmbientTemp()
    local h = GetClockHours() + GetClockMinutes() / 60
    local t = GlobalState and GlobalState.currentTime
    if t and t.hour ~= nil then h = t.hour + (t.minute or 0) / 60 end
    local sunHeat = (roadCfg.sunHeatMax or 18) * math.max(0, math.sin((h - 6) * math.pi / 12))
    local nightCool = (h >= 21 or h < 5) and (roadCfg.nightCooling or -4) or 0
    local roadTemp = climate + sunHeat + nightCool
    if GetRoadWetness and GetRoadWetness() > 0.1 then
        roadTemp = climate + (roadTemp - climate) * (roadCfg.wetRoadMult or 0.3)
    end
    return roadTemp
end

---------------------------------------------------------------------------
-- Per-wheel slip detection
-- Uses GetVehicleWheelSpeed vs GetEntitySpeed to detect ACTUAL slip per tire
---------------------------------------------------------------------------
local function getPerWheelSlip(veh, groundSpeed)
    local slips = { [0] = 0, 0, 0, 0 }
    local numWheels = math.min(4, GetVehicleNumberOfWheels(veh) or 4)
    
    for i = 0, numWheels - 1 do
        local ok, ws = pcall(GetVehicleWheelSpeed, veh, i)
        if ok and ws then
            -- Convert rotational speed to linear (tire radius ~0.34m)
            local wheelLinearSpeed = math.abs(ws) * 0.34
            local slip = 0
            if groundSpeed > 0.5 then
                slip = (wheelLinearSpeed - groundSpeed) / groundSpeed
            elseif wheelLinearSpeed > 1.0 then
                -- Stationary burnout: pure slip
                slip = wheelLinearSpeed
            end
            slips[i] = math.max(0, slip)
        end
    end
    
    return slips
end

---------------------------------------------------------------------------
-- Public API: Per-wheel temp access
---------------------------------------------------------------------------
function GetTireTemp(wheelIndex)
    if type(wheelIndex) == "number" and wheelIndex >= 0 and wheelIndex <= 3 then
        return tireTemp[wheelIndex] or AMBIENT_TEMP
    end
    -- Average of all 4
    local sum = 0
    for i = 0, 3 do sum = sum + (tireTemp[i] or AMBIENT_TEMP) end
    return sum / 4
end

function GetTireTempPerWheel()
    return {
        [0] = tireTemp[0] or AMBIENT_TEMP,
        tireTemp[1] or AMBIENT_TEMP,
        tireTemp[2] or AMBIENT_TEMP,
        tireTemp[3] or AMBIENT_TEMP,
    }
end

function GetTireWear() return tireWear end

---------------------------------------------------------------------------
-- Grip modifier: uses the COLDEST tire (weakest link)
---------------------------------------------------------------------------
function GetTireGripModifier()
    if not enabled then return 1.0 end
    local coldest = 999
    for i = 0, 3 do
        local t = tireTemp[i] or AMBIENT_TEMP
        if t < coldest then coldest = t end
    end
    
    local tempMod = 1.0
    if coldest < 60 then
        tempMod = COLD_MOD
    elseif coldest >= OPTIMAL_MIN and coldest <= OPTIMAL_MAX then
        tempMod = 1.0
    elseif coldest > 140 then
        tempMod = HOT_MOD
    elseif coldest < OPTIMAL_MIN then
        local pct = (coldest - 60) / math.max(1, OPTIMAL_MIN - 60)
        tempMod = COLD_MOD + (1.0 - COLD_MOD) * pct
    else
        local pct = (coldest - OPTIMAL_MAX) / 20
        tempMod = 1.0 - (1.0 - HOT_MOD) * pct
    end
    
    local wearMod = 1.0
    if wearEnabled and wearCfg.wearGripAtMax then
        wearMod = 1.0 - (1.0 - wearCfg.wearGripAtMax) * tireWear
    end
    
    return tempMod * wearMod
end

---------------------------------------------------------------------------
-- MAIN UPDATE: Called every physics tick from grip_application.lua
---------------------------------------------------------------------------
function UpdateTireTemp(veh)
    if not enabled or not veh or not DoesEntityExist(veh) then return end
    
    local now = GetGameTimer() / 1000.0
    local dt = math.min(0.15, now - lastUpdate)
    lastUpdate = now
    if dt <= 0 then return end
    
    -- Repair detection: if engine health jumps, tires were repaired
    local engineHealth = GetVehicleEngineHealth(veh) or 1000
    if _lastEngineHealth and engineHealth > _lastEngineHealth + 200 then
        ResetTireTemp()
        ResetTireWear()
    end
    _lastEngineHealth = engineHealth
    
    -- Gather vehicle state
    local v = GetEntityVelocity(veh)
    local speed = 0
    if v and v.x then speed = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) end
    
    local throttle = GetControlNormal(0, 71)
    local brakeInput = GetControlNormal(0, 72)
    local handbrake = GetVehicleHandbrake(veh) and 1.0 or 0.0
    local brake = math.max(brakeInput, handbrake)
    local steer = math.abs(GetControlNormal(0, 59))
    
    local driven = getDrivenWheels(veh)
    local brakeBias = getBrakeBias(veh)
    local numWheels = math.min(4, GetVehicleNumberOfWheels(veh) or 4)
    
    -- Cooling target: blend of air temp and road surface temp
    local ambient = GetAmbientTemp()
    local roadTemp = GetRoadTemp and GetRoadTemp() or ambient
    local coolTarget = ambient * 0.35 + roadTemp * 0.65
    
    -- Per-wheel slip detection
    local slips = getPerWheelSlip(veh, speed)
    
    -----------------------------------------------------------------------
    -- Per-wheel temperature simulation
    -----------------------------------------------------------------------
    for i = 0, numWheels - 1 do
        local t = tireTemp[i] or AMBIENT_TEMP
        local isDriven = driven[i] or false
        local isFront = (i == 0 or i == 1)
        local slip = slips[i] or 0
        
        -- === HEAT SOURCES (per wheel) ===
        
        -- 1. Wheel slip heat: ONLY the wheel that is actually spinning heats up
        --    More slip = more heat. This is the PRIMARY heat source during burnouts.
        local heatSlip = 0
        if isDriven and slip > 0.05 then
            local slipIntensity = math.min(3.0, slip) -- Cap at 3x ground speed
            heatSlip = slipIntensity * (cfg.heatFromBurnout or 2.5) * HEAT_RATE * dt
        end
        
        -- 2. Braking heat: distributed by brake bias (front gets more)
        local brakeMult = isFront and brakeBias or (1.0 - brakeBias)
        local heatBrake = 0
        if brake > 0.1 and speed > 2.0 then
            heatBrake = (cfg.heatFromBraking or 1.2) * brake * (speed / 30) * brakeMult * HEAT_RATE * dt
        end
        
        -- 3. Cornering heat: outside tires load more and get hotter
        --    When turning right, left tires (0, 2) are loaded more
        local steerDir = GetControlNormal(0, 59) -- negative = left, positive = right
        local isOutside = false
        if steerDir > 0.1 then isOutside = (i == 0 or i == 2)    -- turning right, left tires loaded
        elseif steerDir < -0.1 then isOutside = (i == 1 or i == 3) -- turning left, right tires loaded
        end
        local cornerMult = isOutside and 1.5 or 0.6
        local heatCorner = 0
        if steer > 0.05 and speed > 5.0 then
            heatCorner = steer * (speed / 40) * cornerMult * (cfg.heatFromCornering or 0.8) * HEAT_RATE * dt
        end
        
        -- 4. Rolling friction heat: gentle warmup from just driving
        local heatRoll = 0
        if speed > 2.0 then
            heatRoll = (speed / 60) * 0.3 * HEAT_RATE * dt
        end
        
        -- 5. Acceleration heat: driven wheels warm when putting power down
        local heatAccel = 0
        if isDriven and throttle > 0.3 and speed > 2.0 and speed < 30 then
            heatAccel = (cfg.heatFromAccel or 0.4) * throttle * HEAT_RATE * dt
        end
        
        -- === COOLING ===
        
        -- Ambient radiation: always cools toward target
        local coolAmbient = (t - coolTarget) * COOL_RATE * dt * 0.5
        
        -- Airflow cooling: faster = more cooling (wind over tires)
        local airflowCool = 0
        if speed > 3.0 and t > coolTarget then
            local airflowFactor = math.min(2.0, speed / 25.0) -- Caps at ~56mph
            airflowCool = (t - coolTarget) * COOL_RATE * dt * airflowFactor * 0.3
        end
        
        local totalCool = coolAmbient + airflowCool
        
        -- === COMBINE ===
        local totalHeat = heatSlip + heatBrake + heatCorner + heatRoll + heatAccel
        local newTemp = t + totalHeat - totalCool
        
        -- Clamp to sane range
        tireTemp[i] = math.max(ambient - 5, math.min(MAX_TEMP, newTemp))
        
        -- Overheat blowout
        if tireTemp[i] >= BLOWOUT_TEMP and not IsVehicleTyreBurst(veh, i, false) then
            SetVehicleTyreBurst(veh, i, false, 1000.0)
        end
    end
    
    ---------------------------------------------------------------------------
    -- Tire wear (accumulated globally for simplicity)
    ---------------------------------------------------------------------------
    if wearEnabled and DoesEntityExist(veh) then
        local c = GetEntityCoords(veh)
        if c and c.x then
            if lastPos then
                local dx, dy, dz = c.x - lastPos.x, c.y - lastPos.y, c.z - lastPos.z
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                if dist < 100.0 then -- Anti-teleport check
                    tireWear = math.min(wearCfg.maxWear or 1.0,
                        tireWear + (wearCfg.wearFromDistance or 0.00002) * dist)
                end
            end
            lastPos = { x = c.x, y = c.y, z = c.z }
        end
        
        -- Brake wear
        if brake > 0.5 and speed > 5 then
            tireWear = math.min(wearCfg.maxWear or 1.0,
                tireWear + (wearCfg.wearFromBraking or 0.00005))
        end
        
        -- Slip wear (any wheel spinning hard)
        local maxSlip = 0
        for i = 0, 3 do
            if (slips[i] or 0) > maxSlip then maxSlip = slips[i] end
        end
        if maxSlip > 0.3 then
            tireWear = math.min(wearCfg.maxWear or 1.0,
                tireWear + (wearCfg.wearFromSlip or 0.0008) * maxSlip)
        end
        
        -- Total tread death blowout
        if tireWear >= 0.99 then
            for i = 0, numWheels - 1 do
                if not IsVehicleTyreBurst(veh, i, false) then
                    SetVehicleTyreBurst(veh, i, true, 1000.0)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Reset functions
---------------------------------------------------------------------------
function ResetTireTemp()
    local base = GetAmbientTemp()
    for i = 0, 3 do tireTemp[i] = base end
end

function ResetTireWear()
    tireWear = 0.0
    lastPos = nil
end
