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
