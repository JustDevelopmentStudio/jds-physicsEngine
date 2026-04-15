--[[
    jds-resources :: advanced physics (client)
    True Earth gravity 9.8 m/s²
]]
local config = Config.Physics or {}
local EARTH_GRAVITY_MS2 = config.gravityMs2 or 9.8

-- World gravity (SetGravityLevel: 0=heaviest, 3=moon)
CreateThread(function()
    SetGravityLevel(config.gravityLevel or 0)
end)

-- Movement multipliers
CreateThread(function()
    local pid = PlayerId()
    SetRunSprintMultiplierForPlayer(pid, config.runSprintMultiplier or 1.0)
    SetSwimMultiplierForPlayer(pid, config.swimMultiplier or 1.0)
    if config.moveRateOverride then
        SetPedMoveRateOverride(PlayerPedId(), config.moveRateOverride)
    end
    if config.useStaminaTweaks then
        SetPlayerMaxStamina(pid, config.maxStamina or 100.0)
    end
end)

-- Vehicle gravity: true 9.8 m/s² (or multiplier if useEarthGravity = false)
CreateThread(function()
    local lastVeh = 0
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                if veh ~= lastVeh then
                    lastVeh = veh
                end
                local amount = config.useEarthGravity and EARTH_GRAVITY_MS2 or config.vehicleGravityMultiplier
                SetVehicleGravityAmount(veh, amount)
            end
        else
            lastVeh = 0
        end
        Wait(config.useEarthGravity and 100 or 500)
    end
end)

-- Advanced Aerodynamics: Slipstreaming / Drafting
CreateThread(function()
    while true do
        Wait(50) -- Smooth application of force
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local speed = GetEntitySpeed(veh) * 2.23694 -- mph
                if speed > 65.0 then -- drafting requires high speed wind displacement
                    local c = GetEntityCoords(veh)
                    local f = GetEntityForwardVector(veh)
                    local forwardOffset = c + (f * 35.0) 
                    
                    -- Cast a shape test specifically looking for other vehicles (flag 2)
                    local handle = StartShapeTestRay(c.x, c.y, c.z, forwardOffset.x, forwardOffset.y, forwardOffset.z, 2, veh, 0)
                    local _, hit, hitCoords, _, entityHit = GetShapeTestResult(handle)
                    
                    if hit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
                        -- Check if the lead vehicle is moving roughly the same direction to avoid gaining slipstream from oncoming traffic
                        local diffRot = math.abs(GetEntityHeading(veh) - GetEntityHeading(entityHit))
                        if diffRot < 45.0 or diffRot > 315.0 then
                            local dist = #(c - hitCoords)
                            -- The closer you are to their rear bumper, the heavier the slipstream
                            local power = 1.0 - (dist / 35.0) 
                            
                            -- Apply a continuous forward velocity push to mimic zero wind resistance
                            -- Param 1: ForceType=1, Y=forward force. 
                            ApplyForceToEntity(veh, 1, 0.0, 1.35 * power, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
                        end
                    end
                end
            end
        end
    end
end)
