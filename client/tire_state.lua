--[[
    jds-resources :: tire temperature + wear simulation
    Per-wheel temps. Burnout heat only on driven wheels. Tach/RPM independent of tire.
]]
local cfg = (Config.PhysicsAdvanced or {}).tireTemp or {}
local wearCfg = (Config.PhysicsAdvanced or {}).tireWear or {}
local ambCfg = Config.AmbientTemp or {}
local enabled = cfg.enabled
local wearEnabled = wearCfg.enabled
local heatRate = cfg.heatRate or 0.5
local coolRate = cfg.coolRate or 0.3
local ambientFallback = cfg.ambientFallback or 20
local optimalMin = cfg.optimalMin or 80
local optimalMax = cfg.optimalMax or 120
local coldMod = cfg.coldModifier or 0.85
local hotMod = cfg.hotModifier or 0.90

-- Per-wheel temps: 0=LF, 1=RF, 2=LR, 3=RR
local tireTemp = { [0] = ambientFallback, ambientFallback, ambientFallback, ambientFallback }
local tireWear = 0.0
local lastUpdate = GetGameTimer() / 1000.0
local lastPos = nil

local function getSpeedMps(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    local vx, vy, vz = GetEntityVelocity(vehicle)
    if vx and vy and vz then
        return math.sqrt(vx * vx + vy * vy + vz * vz)
    end
    return 0
end

--- Which wheels are driven (fDriveBiasFront: 1=FWD, 0=RWD, 0.5=AWD)
--- 4-wheel: 0=LF, 1=RF, 2=LR, 3=RR. Bike: 0=front, 1=rear.
local function getDrivenWheels(vehicle)
    local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
    local ok, bias = pcall(GetVehicleHandlingFloat, vehicle, "CHandlingData", "fDriveBiasFront")
    if not ok or not bias then
        if numWheels <= 2 then return { false, true } end
        return { true, true, true, true }
    end
    local front = bias >= 0.85
    local rear = bias <= 0.15
    if numWheels <= 2 then
        -- Bike: 0=front, 1=rear. RWD=rear driven, FWD=front (rare)
        if rear then return { false, true } end   -- RWD bike
        if front then return { true, false } end -- FWD bike
        return { true, true }                    -- AWD bike (scooter)
    end
    if front then return { true, true, false, false }
    elseif rear then return { false, false, true, true }
    else return { true, true, true, true }
    end
end

--- Brake bias: front gets more heat
local function getBrakeBias(vehicle)
    local ok, bias = pcall(GetVehicleHandlingFloat, vehicle, "CHandlingData", "fBrakeBiasFront")
    if not ok or not bias then return 0.6 end
    return math.max(0.3, math.min(0.9, bias or 0.6))
end

function GetAmbientTemp()
    local ambCfg = Config.AmbientTemp or {}
    if ambCfg.fallbackFromWeather == false then
        return ambCfg.fallbackBase or ambientFallback
    end
    local weather = (GlobalState.weather and GlobalState.weather.weather) or GetPrevWeatherTypeHashName() or "CLEAR"
    local base = ambCfg.fallbackBase or 18
    local swing = ambCfg.fallbackSwing or 10
    local h = 12
    local t = GlobalState.currentTime
    if t and t.hour ~= nil then
        h = t.hour + (t.minute or 0) / 60
    else
        h = GetClockHours() + GetClockMinutes() / 60
    end
    local temp = base + swing * math.sin((h - 6) * math.pi / 12)
    local mod = ambCfg.weatherTempMod and ambCfg.weatherTempMod[weather]
    if type(mod) == "number" then temp = temp + mod end
    return temp
end

function GetClimateTemp()
    return GetAmbientTemp()
end

function GetRoadTemp()
    local roadCfg = (ambCfg.roadTemp or {})
    if roadCfg.enabled == false then return GetAmbientTemp() end
    local climate = GetAmbientTemp()
    local h = 12
    local t = GlobalState.currentTime
    if t and t.hour ~= nil then
        h = t.hour + (t.minute or 0) / 60
    else
        h = GetClockHours() + GetClockMinutes() / 60
    end
    local sunHeat = (roadCfg.sunHeatMax or 18) * math.max(0, math.sin((h - 6) * math.pi / 12))
    local nightCool = (h >= 21 or h < 5) and (roadCfg.nightCooling or -4) or 0
    local wetMult = roadCfg.wetRoadMult or 0.3
    local roadTemp = climate + sunHeat + nightCool
    if GetRoadWetness and GetRoadWetness() > 0.1 then
        roadTemp = climate + (roadTemp - climate) * wetMult
    end
    return roadTemp
end

--- Avg tire temp (backward compat)
function GetTireTemp(wheelIndex)
    if type(wheelIndex) == "number" and wheelIndex >= 0 and wheelIndex <= 3 then
        return tireTemp[wheelIndex] or ambientFallback
    end
    local sum, n = 0, 0
    for i = 0, 3 do
        if tireTemp[i] then sum = sum + tireTemp[i]; n = n + 1 end
    end
    return n > 0 and (sum / n) or ambientFallback
end

--- Per-wheel temps for telemetry
function GetTireTempPerWheel()
    return {
        [0] = tireTemp[0] or ambientFallback,
        tireTemp[1] or ambientFallback,
        tireTemp[2] or ambientFallback,
        tireTemp[3] or ambientFallback,
    }
end

function GetTireWear()
    return tireWear
end

--- Grip modifier from tire temp (uses coldest tire - limits grip)
function GetTireGripModifier()
    if not enabled then return 1.0 end
    local coldest = 200
    for i = 0, 3 do
        local t = tireTemp[i]
        if t and t < coldest then coldest = t end
    end
    if coldest >= 200 then coldest = ambientFallback end
    local tempMod = 1.0
    if coldest < 60 then
        tempMod = coldMod
    elseif coldest >= optimalMin and coldest <= optimalMax then
        tempMod = 1.0
    elseif coldest > 140 then
        tempMod = hotMod
    elseif coldest < optimalMin then
        tempMod = coldMod + (1.0 - coldMod) * (coldest - 60) / (optimalMin - 60)
    else
        tempMod = 1.0 - (1.0 - hotMod) * (coldest - optimalMax) / 20
    end
    local wearMod = 1.0
    if wearEnabled and wearCfg.wearGripAtMax then
        wearMod = 1.0 - (1.0 - wearCfg.wearGripAtMax) * tireWear
    end
    return tempMod * wearMod
end

function UpdateTireTemp(vehicle)
    if not enabled or not vehicle then return GetTireTemp() end
    local now = GetGameTimer() / 1000.0
    local dt = math.min(0.1, now - lastUpdate)
    lastUpdate = now

    local climate = GetClimateTemp()
    local roadTemp = GetRoadTemp and GetRoadTemp() or climate
    local speed = getSpeedMps(vehicle)
    local rpm = GetVehicleCurrentRpm(vehicle) or 0
    local throttle = GetControlNormal(0, 71)
    local brakeInput = GetControlNormal(0, 72)
    local brake = GetVehicleHandbrake(vehicle) and 1 or 0
    if brakeInput > 0.1 then brake = math.max(brake, brakeInput) end
    local steer = math.abs(GetControlNormal(0, 59))

    local driven = getDrivenWheels(vehicle)
    local brakeBias = getBrakeBias(vehicle)
    local coolTarget = (climate * 0.35 + roadTemp * 0.65)

    -- Tire slip = burnout (high RPM, low speed). ONLY driven wheels heat from this.
    local isBurnout = rpm > (cfg.burnoutRpmThreshold or 0.65) and speed < (cfg.burnoutSpeedMax or 10)
    local heatBurnout = isBurnout and ((cfg.heatFromBurnout or 2.5) * rpm * heatRate * dt) or 0

    local numWheels = math.min(4, GetVehicleNumberOfWheels(vehicle) or 4)

    for i = 0, numWheels - 1 do
        local t = tireTemp[i] or ambientFallback
        local isDriven = driven[i + 1]  -- Lua 1-based: wheel 0 -> driven[1]

        -- Cooling: all tires cool to ambient/road blend
        local cool = (t - coolTarget) * coolRate * dt * 0.012

        -- Rolling heat: speed + load (throttle on driven wheels warms during launch)
        local heatRoll = (speed / 50 * 0.5) * heatRate * dt
        if isDriven and throttle > 0.3 and speed < 20 then
            heatRoll = heatRoll + (cfg.heatFromAccel or 0.4) * throttle * (speed + 4) / 24 * heatRate * dt
        end

        -- Braking: front tires get more (brake bias). Wheels 0,1 = front
        local isFront = (i == 0 or i == 1)
        local brakeMult = isFront and brakeBias or (1 - brakeBias)
        local heatBrake = (cfg.heatFromBraking or 1.2) * brake * (speed / 30) * brakeMult * heatRate * dt

        -- Burnout: ONLY driven wheels (real tire slip)
        local heatB = isDriven and heatBurnout or 0

        -- Cornering: all tires, lateral slip
        local heatCorner = steer * (speed / 40) * (cfg.heatFromCornering or 0.8) * heatRate * dt

        local totalHeat = heatRoll + heatBrake + heatB + heatCorner
        tireTemp[i] = math.max(climate - 5, math.min(155, t + totalHeat - cool))
    end

    -- Tire wear
    if wearEnabled and DoesEntityExist(vehicle) then
        local c = GetEntityCoords(vehicle)
        local x, y, z
        if type(c) == "table" and (c.x or c[1]) then
            x, y, z = c.x or c[1], c.y or c[2], c.z or c[3]
        else
            x, y, z = c, select(2, GetEntityCoords(vehicle)), select(3, GetEntityCoords(vehicle))
        end
        if x and y and z then
            if lastPos then
                local dx, dy, dz = x - lastPos.x, y - lastPos.y, z - lastPos.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                tireWear = math.min(wearCfg.maxWear or 1.0, tireWear + (wearCfg.wearFromDistance or 0.00002) * dist)
            end
            lastPos = { x = x, y = y, z = z }
        end
        if brake > 0.5 and speed > 5 then
            tireWear = math.min(wearCfg.maxWear or 1.0, tireWear + (wearCfg.wearFromBraking or 0.0003))
        end
        if rpm > 0.7 and speed < 8 and speed > 0.5 then
            tireWear = math.min(wearCfg.maxWear or 1.0, tireWear + (wearCfg.wearFromSlip or 0.0008))
        end
    end

    return GetTireTemp()
end

function ResetTireTemp()
    local base = GetAmbientTemp()
    for i = 0, 3 do tireTemp[i] = base end
end

function ResetTireWear()
    tireWear = 0.0
    lastPos = nil
end
