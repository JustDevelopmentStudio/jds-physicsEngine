--[[
    jds-physicsEngine :: Forza-Inspired Telemetry
]]

local showTelemetry = false
local lastVelocity = nil
local lastGameTime = 0

-- Key mapping parameters
-- PageUp (10), PageDown (11)
CreateThread(function()
    while true do
        Wait(5)
        if IsControlJustPressed(0, 10) then
            showTelemetry = not showTelemetry
            SendNUIMessage({
                action = "toggle",
                show = showTelemetry
            })
        end

        if showTelemetry and IsControlJustPressed(0, 11) then
            SendNUIMessage({
                action = "cycle"
            })
        end
    end
end)

CreateThread(function()
    while true do
        Wait(50)
        
        if showTelemetry then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                
                -- Telemetry fetch mapping
                local speed = GetEntitySpeed(veh) * 2.23694
                local gear = GetVehicleCurrentGear(veh)
                local rpm = GetVehicleCurrentRpm(veh)
                
                -- Tire state fetch (exports from tire_state.lua)
                local t0 = GetTireTemp and GetTireTemp(0) or 20
                local t1 = GetTireTemp and GetTireTemp(1) or 20
                local t2 = GetTireTemp and GetTireTemp(2) or 20
                local t3 = GetTireTemp and GetTireTemp(3) or 20
                
                local wear = GetTireWear and GetTireWear() or 0.0
                
                local s0 = GetVehicleWheelSuspensionCompression(veh, 0) or 0
                local s1 = GetVehicleWheelSuspensionCompression(veh, 1) or 0
                local s2 = GetVehicleWheelSuspensionCompression(veh, 2) or 0
                local s3 = GetVehicleWheelSuspensionCompression(veh, 3) or 0
                
                local steer = GetVehicleSteeringAngle(veh)
                
                local throttle = GetControlNormal(0, 71) -- 71 is INPUT_VEH_ACCELERATE
                local brake = GetControlNormal(0, 72)    -- 72 is INPUT_VEH_BRAKE
                
                -- G-Force Calculation
                local curTime = GetGameTimer()
                local dt = (curTime - lastGameTime) / 1000.0
                if dt == 0 then dt = 0.05 end
                
                local velocity = GetEntityVelocity(veh)
                local gForceX = 0.0
                local gForceY = 0.0
                
                if lastVelocity ~= nil then
                    local accelX = (velocity.x - lastVelocity.x) / dt
                    local accelY = (velocity.y - lastVelocity.y) / dt
                    local accelZ = (velocity.z - lastVelocity.z) / dt
                    
                    local pos = GetEntityCoords(veh)
                    local rightPos = GetOffsetFromEntityInWorldCoords(veh, 1.0, 0.0, 0.0)
                    local right = { x = rightPos.x - pos.x, y = rightPos.y - pos.y, z = rightPos.z - pos.z }
                    
                    local forward = GetEntityForwardVector(veh)
                    
                    local latAccel = (accelX * right.x) + (accelY * right.y) + (accelZ * right.z)
                    local lonAccel = (accelX * forward.x) + (accelY * forward.y) + (accelZ * forward.z)
                    
                    -- Convert to G's (1G = 9.81 m/s^2)
                    gForceX = latAccel / 9.81
                    gForceY = lonAccel / 9.81
                end
                
                lastVelocity = velocity
                lastGameTime = curTime
                
                SendNUIMessage({
                    action = "update",
                    speed = speed,
                    gear = gear,
                    rpm = rpm,
                    steerAngle = steer,
                    throttle = throttle,
                    brake = brake,
                    wear = wear,
                    gForce = {x = gForceX, y = gForceY},
                    tires = {t0, t1, t2, t3},
                    susp = {s0, s1, s2, s3}
                })
            else
                -- Not in vehicle, softly close it down natively
                showTelemetry = false
                SendNUIMessage({
                    action = "toggle",
                    show = false
                })
            end
        else
            Wait(500) -- Sleep deeply if telemetry UI is turned off
        end
    end
end)
