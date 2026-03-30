--[[
    jds-resources :: custom traction control
    Detects wheelspin (driven wheel speed > vehicle speed) and scales throttle to reduce slip.
    Replaces GTA's native CF_ASSIST_TRACTION_CONTROL when enabled.
]]
local cfg = (Config.PhysicsAdvanced or {}).customTractionControl or {}
local enabled = cfg.enabled
local CTRL_THROTTLE = 71

local function getSpeedMps(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    local vx, vy, vz = GetEntityVelocity(vehicle)
    if vx and vy and vz then
        return math.sqrt(vx * vx + vy * vy + vz * vz)
    end
    return 0
end

--- Which wheels are driven (fDriveBiasFront: 1=FWD, 0=RWD, 0.5=AWD)
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
        if rear then return { false, true } end
        if front then return { true, false } end
        return { true, true } end
    if front then return { true, true, false, false }
    elseif rear then return { false, false, true, true }
    else return { true, true, true, true }
    end
end

--- Get max speed of driven wheels (m/s)
local function getMaxDrivenWheelSpeed(vehicle)
    local driven = getDrivenWheels(vehicle)
    local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
    local maxSpeed = 0
    for i = 0, numWheels - 1 do
        if driven[i + 1] then
            local ok, spd = pcall(GetVehicleWheelSpeed, vehicle, i)
            if ok and spd and spd > maxSpeed then
                maxSpeed = spd
            end
        end
    end
    return maxSpeed
end

CreateThread(function()
    if not enabled then return end
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then goto continue end
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) ~= ped then goto continue end

        local rawThrottle = GetControlNormal(0, CTRL_THROTTLE) or 0
        if rawThrottle < 0.05 then goto continue end

        local vehicleSpeed = getSpeedMps(veh)
        local minSpeed = cfg.minSpeedMps or 1.0
        if vehicleSpeed < minSpeed then goto continue end

        local wheelSpeed = getMaxDrivenWheelSpeed(veh)
        local slip = wheelSpeed - vehicleSpeed
        if slip <= 0 then goto continue end

        local refSpeed = math.max(vehicleSpeed, 0.5)
        local slipRatio = slip / refSpeed
        local threshold = cfg.slipThreshold or 0.12
        if slipRatio < threshold then goto continue end

        -- TC intervention: cut throttle proportionally to slip
        local strength = cfg.interventionStrength or 2.0
        local retain = cfg.maxThrottleRetain or 0.25
        local cut = math.min(1.0, (slipRatio - threshold) * strength)
        local scaledThrottle = math.max(retain, rawThrottle * (1.0 - cut))

        DisableControlAction(0, CTRL_THROTTLE, true)
        SetControlNormal(0, CTRL_THROTTLE, scaledThrottle)
        ::continue::
    end
end)
