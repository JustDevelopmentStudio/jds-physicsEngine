--[[
    jds-physicsEngine :: damage-to-performance
    Engine, suspension, camber, toe, steering, brakes degrade with damage
    Vehicle performs like it looks.
]]
local cfg = Config.VehiclePerformance or {}
local enabled = cfg.enabled
local engCfg = cfg.engine or {}
local suspCfg = cfg.suspension or {}
local geomCfg = cfg.geometry or {}
local activeCfg = cfg.activeGeometry or {}
local steerCfg = cfg.steering or {}
local brakeCfg = cfg.brakes or {}
local tireCfg = cfg.tires or {}

-- Control indices: 59=steer, 71=throttle, 72=brake
local CTRL_STEER, CTRL_THROTTLE, CTRL_BRAKE = 59, 71, 72

local vehicleCache = {}

local HANDLING_FIELDS = {
    -- CHandlingData
    engine = { "fInitialDriveForce", "fInitialDriveMaxFlatVel", "fDriveInertia" },
    suspension = { "fSuspensionForce", "fSuspensionCompDamp", "fSuspensionReboundDamp" },
    steering = { "fSteeringLock" },
    brakes = { "fBrakeForce", "fBrakeBiasFront" },
    tires = { "fTractionCurveMin", "fTractionBiasFront" },
}

local function lerp(a, b, t)
    return a + (b - a) * math.max(0, math.min(1, t))
end

local function getHealthFactor(health, threshold, minHealth)
    if not health or health >= threshold then return 0 end
    local range = threshold - (minHealth or 0)
    return 1 - (health - (minHealth or 0)) / range
end

local function readHandling(vehicle, class, field)
    local ok, val = pcall(GetVehicleHandlingFloat, vehicle, class, field)
    return ok and val and val
end

local function setHandling(vehicle, class, field, value)
    pcall(SetVehicleHandlingFloat, vehicle, class, field, value)
end

local function getSpeedMps(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    local v = GetEntityVelocity(vehicle)
    if type(v) == "table" and v.x then
        return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    end
    local vx, vy, vz = GetEntityVelocity(vehicle)
    return (vx and vy and vz) and math.sqrt(vx*vx + vy*vy + vz*vz) or 0
end

local function cacheOriginals(vehicle)
    if vehicleCache[vehicle] then return vehicleCache[vehicle].orig end
    local orig = {}
    for _, fields in pairs(HANDLING_FIELDS) do
        for _, f in ipairs(fields) do
            local v = readHandling(vehicle, "CHandlingData", f)
            if v then orig[f] = v end
        end
    end
    -- CCarHandlingData (camber, toe)
    local camberF = readHandling(vehicle, "CCarHandlingData", "fCamberFront")
    local camberR = readHandling(vehicle, "CCarHandlingData", "fCamberRear")
    local toeF = readHandling(vehicle, "CCarHandlingData", "fToeFront")
    local toeR = readHandling(vehicle, "CCarHandlingData", "fToeRear")
    if camberF then orig.fCamberFront = camberF end
    if camberR then orig.fCamberRear = camberR end
    if toeF then orig.fToeFront = toeF end
    if toeR then orig.fToeRear = toeR end

    vehicleCache[vehicle] = vehicleCache[vehicle] or {}
    vehicleCache[vehicle].orig = orig
    return orig
end

local function applyPerformanceModifiers(vehicle)
    if not enabled or not vehicle or not DoesEntityExist(vehicle) then return end

    local vc = GetVehicleClass(vehicle)
    local isCar = (vc ~= 8 and vc ~= 13 and vc ~= 14 and vc ~= 15 and vc ~= 16 and vc ~= 21)

    local okE, engineHealth = pcall(GetVehicleEngineHealth, vehicle)
    local okB, bodyHealth = pcall(GetVehicleBodyHealth, vehicle)
    if not okE or not okB then return end
    engineHealth = engineHealth or 1000
    bodyHealth = bodyHealth or 1000

    local orig = cacheOriginals(vehicle)
    if not orig or not next(orig) then return end

    -- Engine
    if engCfg.enabled and orig.fInitialDriveForce then
        local f = getHealthFactor(engineHealth, engCfg.healthThreshold or 800, engCfg.minHealth or -4000)
        local powerMult = lerp(1, engCfg.powerMultiplierAtDead or 0, f)
        local topMult = lerp(1, engCfg.topSpeedMultiplierAtDead or 0.3, f)
        local revMult = lerp(1, engCfg.revMultiplierAtDead or 0.5, f)
        setHandling(vehicle, "CHandlingData", "fInitialDriveForce", orig.fInitialDriveForce * powerMult)
        if orig.fInitialDriveMaxFlatVel then
            setHandling(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel", orig.fInitialDriveMaxFlatVel * topMult)
        end
        if orig.fDriveInertia then
            setHandling(vehicle, "CHandlingData", "fDriveInertia", orig.fDriveInertia * revMult)
        end
    end

    -- Suspension
    if suspCfg.enabled and orig.fSuspensionForce then
        local f = getHealthFactor(bodyHealth, suspCfg.bodyHealthThreshold or 800, suspCfg.minBodyHealth or 0)
        local spr = lerp(1, suspCfg.springMultiplierAtWorst or 0.7, f)
        local comp = lerp(1, suspCfg.compDampMultiplierAtWorst or 0.75, f)
        local reb = lerp(1, suspCfg.reboundDampMultiplierAtWorst or 0.75, f)
        setHandling(vehicle, "CHandlingData", "fSuspensionForce", orig.fSuspensionForce * spr)
        if orig.fSuspensionCompDamp then
            setHandling(vehicle, "CHandlingData", "fSuspensionCompDamp", orig.fSuspensionCompDamp * comp)
        end
        if orig.fSuspensionReboundDamp then
            setHandling(vehicle, "CHandlingData", "fSuspensionReboundDamp", orig.fSuspensionReboundDamp * reb)
        end
    end

    -- Geometry (camber, toe) - cars only: damage + active dynamic
    if isCar and (geomCfg.enabled or activeCfg.enabled) and (orig.fCamberFront or orig.fCamberRear) then
        local camberF, camberR = orig.fCamberFront or 0, orig.fCamberRear or 0
        local toeF, toeR = orig.fToeFront or 0, orig.fToeRear or 0

        -- Damage offset (bent frame)
        if geomCfg.enabled then
            local f = getHealthFactor(bodyHealth, geomCfg.bodyHealthThreshold or 700, 0)
            local bend = (geomCfg.camberBendAtWorst or 0.15) * f
            local toeBend = (geomCfg.toeBendAtWorst or 0.05) * f
            camberF = camberF + bend
            camberR = camberR + bend * 0.8
            toeF = toeF + toeBend
            toeR = toeR + toeBend * 0.8
        end

        -- Active dynamic: steering, brake, throttle, speed
        if activeCfg.enabled then
            local steer = GetControlNormal(0, CTRL_STEER) or 0
            local brake = GetControlNormal(0, CTRL_BRAKE) or 0
            local throttle = GetControlNormal(0, CTRL_THROTTLE) or 0
            local speed = getSpeedMps(vehicle)

            -- Cornering camber (load transfer)
            local steerMag = math.abs(steer)
            if steerMag >= (activeCfg.corneringSteerThreshold or 0.25) then
                local speedFac = math.min(1, speed / 40) * (activeCfg.corneringSpeedFactor or 0.4)
                local cornerCamber = steerMag * speedFac
                camberF = camberF + (activeCfg.corneringCamberFront or -0.08) * cornerCamber
                camberR = camberR + (activeCfg.corneringCamberRear or -0.06) * cornerCamber
            end

            -- Brake dive (front toe/camber)
            if brake >= (activeCfg.brakeThreshold or 0.4) then
                toeF = toeF + (activeCfg.brakeToeFront or 0.02) * brake
                camberF = camberF + (activeCfg.brakeCamberFront or -0.03) * brake
            end

            -- Acceleration squat (rear toe/camber)
            if throttle >= (activeCfg.accelThreshold or 0.5) then
                toeR = toeR + (activeCfg.accelToeRear or 0.015) * throttle
                camberR = camberR + (activeCfg.accelCamberRear or -0.02) * throttle
            end
        end

        if orig.fCamberFront then setHandling(vehicle, "CCarHandlingData", "fCamberFront", camberF) end
        if orig.fCamberRear then setHandling(vehicle, "CCarHandlingData", "fCamberRear", camberR) end
        if orig.fToeFront then setHandling(vehicle, "CCarHandlingData", "fToeFront", toeF) end
        if orig.fToeRear then setHandling(vehicle, "CCarHandlingData", "fToeRear", toeR) end
    end

    -- Steering: dynamic lock lerp by speed (full at standstill, heavy at high speed)
    if (steerCfg.enabled or activeCfg.speedSteerReduction) and orig.fSteeringLock then
        local speed = getSpeedMps(vehicle)
        local lowMult = activeCfg.steerAtLowSpeed or 0.88
        local highMult = activeCfg.steerAtHighSpeed or 0.28
        local speedMax = activeCfg.speedForMaxReduction or 38
        local t = math.min(1, speed / speedMax)
        local mult = lerp(lowMult, highMult, t)
        if steerCfg.enabled then
            local f = getHealthFactor(bodyHealth, steerCfg.bodyHealthThreshold or 750, 0)
            mult = mult * lerp(1, steerCfg.lockMultiplierAtWorst or 0.85, f)
        end
        setHandling(vehicle, "CHandlingData", "fSteeringLock", orig.fSteeringLock * mult)
    end

    -- Brakes
    if (brakeCfg.enabled or brakeCfg.baseBrakeForceMult) and orig.fBrakeForce then
        local baseMult = brakeCfg.baseBrakeForceMult or 1.0
        local f = brakeCfg.enabled and getHealthFactor(bodyHealth, brakeCfg.bodyHealthThreshold or 700, 0) or 0
        local forceMult = baseMult * lerp(1, brakeCfg.forceMultiplierAtWorst or 0.8, f)
        setHandling(vehicle, "CHandlingData", "fBrakeForce", orig.fBrakeForce * forceMult)
        if orig.fBrakeBiasFront and brakeCfg.biasShiftAtWorst then
            local bias = orig.fBrakeBiasFront + (brakeCfg.biasShiftAtWorst or 0) * f
            setHandling(vehicle, "CHandlingData", "fBrakeBiasFront", math.max(0.3, math.min(0.7, bias)))
        end
    end

    -- Tire (slide grip + balance)
    if tireCfg.enabled then
        local wheelF = 0
        if GetVehicleWheelHealth then
            local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
            local total = 0
            local sum = 0
            for i = 0, numWheels - 1 do
                local ok, wh = pcall(GetVehicleWheelHealth, vehicle, i)
                if ok and wh then sum = sum + wh; total = total + 1 end
            end
            if total > 0 then
                local avgHealth = sum / total
                wheelF = getHealthFactor(avgHealth, tireCfg.wheelHealthThreshold or 800, 0)
            end
        end
        if orig.fTractionCurveMin then
            local mult = lerp(1, tireCfg.slideGripMultiplierAtWorst or 0.7, wheelF)
            setHandling(vehicle, "CHandlingData", "fTractionCurveMin", orig.fTractionCurveMin * mult)
        end
        if orig.fTractionBiasFront and tireCfg.biasShiftAtWorst then
            vehicleCache[vehicle].pullDirection = vehicleCache[vehicle].pullDirection or (vehicle % 2 == 0 and 1 or -1)
            local shift = (tireCfg.biasShiftAtWorst or 0) * wheelF * vehicleCache[vehicle].pullDirection
            local bias = orig.fTractionBiasFront + shift
            setHandling(vehicle, "CHandlingData", "fTractionBiasFront", math.max(0.3, math.min(0.7, bias)))
        end
    end

    -- Brake weight transfer: when braking, grip shifts to front (rear gets light, full car mass effect)
    if isCar and activeCfg.enabled and activeCfg.brakeTractionBiasShift and orig.fTractionBiasFront then
        local brake = GetControlNormal(0, CTRL_BRAKE) or 0
        local steer = math.abs(GetControlNormal(0, CTRL_STEER) or 0)
        local speed = getSpeedMps(vehicle)
        if brake >= (activeCfg.brakeThreshold or 0.35) and speed > 2 then
            local ok, curBias = pcall(GetVehicleHandlingFloat, vehicle, "CHandlingData", "fTractionBiasFront")
            local baseBias = (ok and curBias) and curBias or orig.fTractionBiasFront
            local shift = (activeCfg.brakeTractionBiasShift or 0.10) * brake
            if steer >= 0.2 then
                shift = shift + (activeCfg.brakeAndSteerExtra or 0.04) * steer
            end
            local speedFac = math.min(1, speed / 25)
            shift = shift * speedFac
            local bias = math.max(0.35, math.min(0.72, baseBias + shift))
            setHandling(vehicle, "CHandlingData", "fTractionBiasFront", bias)
        end
    end
end

local function restoreOriginals(vehicle)
    local c = vehicleCache[vehicle]
    if not c or not c.orig or not DoesEntityExist(vehicle) then
        vehicleCache[vehicle] = nil
        return
    end
    for f, val in pairs(c.orig) do
        local class = (f == "fCamberFront" or f == "fCamberRear" or f == "fToeFront" or f == "fToeRear")
            and "CCarHandlingData" or "CHandlingData"
        setHandling(vehicle, class, f, val)
    end
    vehicleCache[vehicle] = nil
end

--- Called from grip_application loop
function ApplyDamagePerformance(vehicle)
    if not enabled then return end
    applyPerformanceModifiers(vehicle)
end

--- Restore when exiting vehicle
function RestoreDamagePerformance(vehicle)
    restoreOriginals(vehicle)
end

AddEventHandler("onResourceStop", function(name)
    if GetCurrentResourceName() ~= name then return end
    for veh, _ in pairs(vehicleCache) do
        if DoesEntityExist(veh) then
            restoreOriginals(veh)
        end
    end
end)
