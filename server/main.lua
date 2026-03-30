--[[
    jds-physicsEngine :: server
    Damage sync broadcast, ambient temp (see ambient_temp.lua)
]]
RegisterNetEvent("jds-physicsEngine:damageApplied", function(netId, engineHealth, bodyHealth)
    local src = source
    if not netId or not engineHealth or not bodyHealth then return end
    TriggerClientEvent("jds-physicsEngine:syncDamage", -1, src, netId, engineHealth, bodyHealth)
end)
