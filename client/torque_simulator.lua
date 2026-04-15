--[[
    jds-physicsEngine :: dynamic torque simulator
    Reads vehicle RPM and applies realistic torque curves based on the engine class.
]]
local cache = {}

local function lerp(a, b, t)
    return a + (b - a) * math.max(0, math.min(1, t))
end

-- Get interpolated torque multiple from a curve array
local function getTorqueMultiplier(curve, rpm)
    if not curve or #curve == 0 then return 1.0 end
    if rpm <= curve[1][1] then return curve[1][2] end
    if rpm >= curve[#curve][1] then return curve[#curve][2] end

    for i = 1, #curve - 1 do
        local r1, t1 = curve[i][1], curve[i][2]
        local r2, t2 = curve[i+1][1], curve[i+1][2]
        if rpm >= r1 and rpm <= r2 then
            local range = r2 - r1
            local pct = (rpm - r1) / range
            return lerp(t1, t2, pct)
        end
    end
    return 1.0
end

local function applyEngineHandlingOverrides(veh, profile)
    if not cache[veh] then cache[veh] = {} end
    if not cache[veh].appliedHandling then
        if profile.driveInertiaMult then
            local okI, origInertia = pcall(GetVehicleHandlingFloat, veh, "CHandlingData", "fDriveInertia")
            if okI and origInertia then
                SetVehicleHandlingFloat(veh, "CHandlingData", "fDriveInertia", origInertia * profile.driveInertiaMult)
            end
        end
        if profile.topSpeedMult then
            -- Uncap the strict native entity speed physics wall
            pcall(SetEntityMaxSpeed, veh, 999.9)
            -- Apply the true native top speed modifier to the vehicle
            pcall(ModifyVehicleTopSpeed, veh, profile.topSpeedMult)
        end
        cache[veh].appliedHandling = true
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local inVehicle = false

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                inVehicle = true
                
                -- Initialize profile for vehicle
                if not cache[veh] then
                    local model = GetEntityModel(veh)
                    local class = GetVehicleClass(veh)
                    local modelName = string.lower(GetDisplayNameFromVehicleModel(model) or "")
                    
                    local engineType = Config.VehicleEngines[modelName] or Config.ClassEngines[class] or "Generic"
                    local profile = Config.Engines[engineType] or Config.Engines["Generic"]
                    
                    cache[veh] = {
                        profile = profile,
                        appliedHandling = false
                    }
                    applyEngineHandlingOverrides(veh, profile)
                end

                local profile = cache[veh].profile
                if profile and profile.curve then
                    local rpm = GetVehicleCurrentRpm(veh)
                    local torqueMult = getTorqueMultiplier(profile.curve, rpm)
                    
                    -- Extract the Gear-based Torque Multiplier
                    local currentGear = GetVehicleCurrentGear(veh) or 1
                    local gearMult = 1.0
                    if profile.gearMultipliers then
                        -- fallback to highest defined gear if the current gear exceeds definitions
                        gearMult = profile.gearMultipliers[currentGear] or profile.gearMultipliers[#profile.gearMultipliers] or 1.0
                    end
                    
                    -- CUSTOM TRACTION CONTROL: Manage massive torque slips
                    local interventionFactor = 1.0
                    local advConfig = Config.PhysicsAdvanced or {}
                    local tcCfg = advConfig.gripApplication and advConfig.gripApplication.customTractionControl or {}
                    
                    if tcCfg.enabled then
                        local absSpd = math.abs(GetEntitySpeed(veh))
                        local maxWheelSpd = 0
                        for i=0, 3 do
                            -- GetVehicleWheelSpeed returns rotation speed (rad/s), NOT linear m/s.
                            -- Multiply by approx tire radius (0.34m) to get accurate linear surface speed of the tire.
                            local ok, ws = pcall(GetVehicleWheelSpeed, veh, i)
                            if ok and ws then
                                ws = math.abs(ws) * 0.34
                                if ws > maxWheelSpd then maxWheelSpd = ws end
                            end
                        end
                        
                        local minSpeed = tcCfg.minSpeedMps or 1.5
                        local threshold = tcCfg.slipThreshold or 0.38
                        local retention = tcCfg.maxThrottleRetain or 0.35
                        local strength = tcCfg.interventionStrength or 0.6
                        
                        -- DYNAMIC LAUNCH DRAG: 
                        -- Prevent the TC from strangling the engine below the car's physical momentum threshold.
                        if absSpd < 4.0 then
                            -- Allow immense slip exactly off the line to physically overcome 1300kg+ resting inertia
                            threshold = threshold + 2.5 
                            retention = 0.60
                        end
                        
                        if maxWheelSpd > minSpeed then
                            local slipRatio = (maxWheelSpd - absSpd) / math.max(absSpd, 0.1)
                            if slipRatio > threshold then
                                -- Spindle speed exceeds realistic slip bounds. Intervene mechanically.
                                local excessDist = slipRatio - threshold
                                local drop = math.min(1.0, excessDist * strength)
                                interventionFactor = math.max(retention, 1.0 - drop)
                            end
                        end
                    end
                    
                    -- This multiplier constantly overrides default power delivery, now dynamically bounded by chassis transmission AND true mechanical traction control
                    SetVehicleEngineTorqueMultiplier(veh, torqueMult * gearMult * interventionFactor)
                end
            end
        end

        -- Cleanup cache periodically or just idle
        if not inVehicle then
            Wait(500)
        else
            Wait(0) -- Need per-frame execution for torque multiplier to apply smoothly
        end
    end
end)
