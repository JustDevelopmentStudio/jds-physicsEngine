--[[
    jds-physicsEngine :: realistic vehicle damage model
    Impact detection, engine/body/tire damage, performance degradation
]]
local cfg = Config.VehicleDamage or {}
local enabled = cfg.enabled
local impactCfg = cfg.impactDetection or {}
local engineCfg = cfg.engine or {}
local bodyCfg = cfg.body or {}
local tireCfg = cfg.tires or {}
local perfCfg = cfg.performance or {}
local locCfg = cfg.localizedDamage or {}
local envCfg = cfg.environmental or {}
local classMults = cfg.classMultipliers or {}

local UPDATE_MS = impactCfg.updateIntervalMs or 50
local SPEED_DELTA_THRESH = impactCfg.speedDeltaThreshold or 8.0
local MIN_SPEED = impactCfg.minSpeedForDamage or 5.0
local COOLDOWN_MS = impactCfg.cooldownMs or 300

--- Get entity speed in m/s (magnitude of velocity)
local function getEntitySpeedMps(entity)
    if not entity or not DoesEntityExist(entity) then return 0 end
    local v = GetEntityVelocity(entity)
    if v and v.x and v.y and v.z then
        return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    end
    return 0
end

--- Vehicle state cache for impact detection
local vehicleState = {}
local lastImpactTime = {}
local redlineStartTime = {}  -- for overheating

local function getClassMultiplier(vehicle)
    if not DoesEntityExist(vehicle) then return 1.0 end
    local vc = GetVehicleClass(vehicle)
    return classMults[vc] or 1.0
end

local function shouldSkipVehicle(vehicle)
    if not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return true end
    local vc = GetVehicleClass(vehicle)
    -- Skip trains, helicopters, planes, boats for damage
    if vc == 21 or vc == 15 or vc == 16 or vc == 14 then return true end
    return false
end

--- Get impact direction as vehicle-relative offset (x,y,z) for SetVehicleDamage
local function getImpactOffset(vehicle, velX, velY, velZ)
    local forward = GetEntityForwardVector(vehicle)
    if not forward or not forward.x then return 0, 2, 0 end
    local fx, fy, fz = forward.x, forward.y, forward.z
    local dot = (velX or 0) * fx + (velY or 0) * fy + (velZ or 0) * fz
    -- Positive dot = moving forward, impact at front (positive Y in vehicle space)
    local sign = dot >= 0 and 1 or -1
    return 0, sign * 2, 0
end

--- Apply damage from impact
local function applyImpactDamage(vehicle, speedBefore, speedAfter, prevVelX, prevVelY, prevVelZ, classMult)
    local delta = speedBefore - speedAfter
    if delta < SPEED_DELTA_THRESH or speedBefore < MIN_SPEED then return end

    local severity = math.min(1.5, delta / SPEED_DELTA_THRESH)
    local speedFactor = 1.0 + (speedBefore / (engineCfg.criticalSpeed or 25)) * ((engineCfg.speedDamageMultiplier or 2.5) - 1)

    local engineDmg = (engineCfg.damagePerImpact or 15) * severity * speedFactor * classMult
    local bodyDmg = (bodyCfg.damagePerImpact or 20) * severity * speedFactor * classMult

    local ok, currEngine = pcall(GetVehicleEngineHealth, vehicle)
    local ok2, currBody = pcall(GetVehicleBodyHealth, vehicle)
    if not ok or not ok2 then return end

    local newEngine = (currEngine or 1000) - engineDmg
    local newBody = (currBody or 1000) - bodyDmg

    newEngine = math.max(engineCfg.minEngineHealth or -4000, newEngine)
    newBody = math.max(bodyCfg.minBodyHealth or 0, newBody)

    pcall(SetVehicleEngineHealth, vehicle, newEngine)
    pcall(SetVehicleBodyHealth, vehicle, newBody)

    -- Multiplayer sync: broadcast damage to other clients
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId and netId > 0 then
        TriggerServerEvent("jds-physicsEngine:damageApplied", netId, newEngine, newBody)
    end

    -- Localized damage (SetVehicleDamage) - deformation at impact point
    if locCfg.enabled and SetVehicleDamage then
        local ox, oy, oz = getImpactOffset(vehicle, prevVelX, prevVelY, prevVelZ)
        local dmg = (locCfg.damageAmount or 0.5) * severity * 500
        local rad = locCfg.radius or 0.5
        pcall(SetVehicleDamage, vehicle, ox, oy, oz, dmg, rad, locCfg.focusOnModel ~= false)
    end

    -- Per-wheel health damage
    if tireCfg.wheelHealthDamage and SetVehicleWheelHealth then
        local wheelDmg = (tireCfg.wheelHealthDamage or 50) * severity * classMult
        local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
        for i = 0, numWheels - 1 do
            local okW, health = pcall(GetVehicleWheelHealth, vehicle, i)
            if okW and health and health > 0 then
                pcall(SetVehicleWheelHealth, vehicle, i, math.max(0, health - wheelDmg))
            end
        end
    end

    -- Engine undriveable when very damaged
    if engineCfg.undriveableThreshold and newEngine < engineCfg.undriveableThreshold then
        pcall(SetVehicleUndriveable, vehicle, true)
    end

    -- Tire blowout chance
    if tireCfg.allowBlowouts and tireCfg.blowoutChancePerImpact and speedBefore >= (tireCfg.blowoutSpeedThreshold or 35) then
        local bodyFrac = (currBody or 1000) / 1000
        if bodyFrac <= (tireCfg.blowoutDamageThreshold or 0.4) or math.random() < (tireCfg.blowoutChancePerImpact * severity) then
            local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
            local wheelToBurst = math.random(0, math.max(0, numWheels - 1))
            pcall(SetVehicleTyreBurst, vehicle, wheelToBurst, true, 1000.0)
        end
    end
end

--- Main impact detection loop (velocity delta)
CreateThread(function()
    if not enabled then return end

    while true do
        Wait(UPDATE_MS)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            vehicleState[ped] = nil
        else
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) ~= ped or shouldSkipVehicle(veh) then goto continue end

            if engineCfg.enableEngineDegrade then
                pcall(SetVehicleEngineCanDegrade, veh, true)
            end

            local netId = NetworkGetNetworkIdFromEntity(veh)
            local state = vehicleState[veh] or {}
            local speed = getEntitySpeedMps(veh)
            local now = GetGameTimer()

            local engineHealth = GetVehicleEngineHealth(veh) or 1000
            if state.lastEngineHealth and engineHealth > state.lastEngineHealth + 200 then
                 -- Admin physically repaired the vehicle. Make sure we remove the 'broken' block!
                 pcall(SetVehicleUndriveable, veh, false)
            end
            state.lastEngineHealth = engineHealth

            if state.prevSpeed then
                local delta = state.prevSpeed - speed
                local lastImpact = lastImpactTime[veh] or 0
                if delta >= SPEED_DELTA_THRESH and state.prevSpeed >= MIN_SPEED and (now - lastImpact) >= COOLDOWN_MS then
                    lastImpactTime[veh] = now
                    local classMult = getClassMultiplier(veh)
                    local pv = state.prevVel or {}
                    applyImpactDamage(veh, state.prevSpeed, speed, pv.x or 0, pv.y or 0, pv.z or 0, classMult)
                end
            end

            -- Environmental damage: water ingress (skip boats)
            if envCfg.waterIngress and GetVehicleClass(veh) ~= 14 then
                local ok, submerged = pcall(GetEntitySubmergedLevel, veh)
                if ok and submerged and submerged > (envCfg.submergedThreshold or 0.5) then
                    local dt = UPDATE_MS / 1000
                    local dmg = (envCfg.waterDamagePerSecond or 25) * dt
                    local okE, eng = pcall(GetVehicleEngineHealth, veh)
                    if okE and eng then
                        local newEng = math.max(engineCfg.minEngineHealth or -4000, eng - dmg)
                        pcall(SetVehicleEngineHealth, veh, newEng)
                        if newEng < (engineCfg.undriveableThreshold or 100) then
                            pcall(SetVehicleUndriveable, veh, true)
                        end
                        local netId = NetworkGetNetworkIdFromEntity(veh)
                        if netId and netId > 0 then
                            local _, body = pcall(GetVehicleBodyHealth, veh)
                        TriggerServerEvent("jds-physicsEngine:damageApplied", netId, newEng, body or 1000)
                        end
                    end
                end
            end

            -- Environmental damage: overheating from sustained redline
            if envCfg.overheating then
                local rpm = GetVehicleCurrentRpm(veh) or 0
                local redline = envCfg.redlineRpm or 0.9
                local cooldown = (envCfg.overheatCooldownSec or 2) * 1000
                
                -- High-speed airflow cooling logic
                -- Convert m/s speed to mph
                local mph = speed * 2.23694
                local isCooling = false
                
                -- Sports(6) and Supers(7) have much better high-speed radiator aerodynamic flow
                local vehicleClass = GetVehicleClass(veh)
                local coolingSpeed = (vehicleClass == 6 or vehicleClass == 7) and 60.0 or 45.0
                
                -- If we are driving fast enough, the radiator forces air through the engine, preventing overheating
                if mph > coolingSpeed then
                    isCooling = true
                end

                if rpm >= redline and not isCooling then
                    redlineStartTime[veh] = redlineStartTime[veh] or now
                    local elapsed = now - (redlineStartTime[veh] or now)
                    if elapsed >= cooldown then
                        local dt = UPDATE_MS / 1000
                        local dmg = (envCfg.overheatDamagePerSecond or 8) * dt
                        local okE, eng = pcall(GetVehicleEngineHealth, veh)
                        if okE and eng and eng > 0 then
                            local newEng = math.max(engineCfg.minEngineHealth or -4000, eng - dmg)
                            pcall(SetVehicleEngineHealth, veh, newEng)
                            local netId = NetworkGetNetworkIdFromEntity(veh)
                            if netId and netId > 0 then
                                local _, body = pcall(GetVehicleBodyHealth, veh)
                                TriggerServerEvent("jds-physicsEngine:damageApplied", netId, newEng, body or 1000)
                            end
                        end
                    end
                else
                    -- Not redlining or we are currently cooling via airflow
                    redlineStartTime[veh] = nil
                end
            end

            -- Deep Damage Mechanics: Suspension & Transmissions
            local v = GetEntityVelocity(veh)
            -- Track previous vertical velocity to detect heavy landings
            local vz = v and v.z or 0
            if state.prevVel and state.prevVel.z then
                local deltaZ = state.prevVel.z - vz
                -- If we were falling extremely fast (-15 m/s) and suddenly stopped falling (hit the ground)
                if state.prevVel.z < -15.0 and deltaZ < -15.0 then
                    -- Massive bottom-out!
                    local severity = math.abs(state.prevVel.z) / 15.0
                    local suspDmg = 50 * severity
                    local okB, curB = pcall(GetVehicleBodyHealth, veh)
                    if okB and curB then
                        local newBody = math.max(0, curB - suspDmg)
                        pcall(SetVehicleBodyHealth, veh, newBody)
                        -- Cause erratic traction issues from broken tie rods/suspension arms
                        if SetVehicleWheelHealth then
                            pcall(SetVehicleWheelHealth, veh, 0, math.max(0, (GetVehicleWheelHealth(veh, 0) or 1000) - (100 * severity)))
                            pcall(SetVehicleWheelHealth, veh, 1, math.max(0, (GetVehicleWheelHealth(veh, 1) or 1000) - (100 * severity)))
                        end
                    end
                end
            end

            -- Transmission Damage (Money-Shift)
            local gear = GetVehicleCurrentGear(veh) or 1
            local mph = speed * 2.23694
            local rpm = GetVehicleCurrentRpm(veh) or 0
            if gear > 0 and rpm >= 0.98 then
                -- Define max speeds per gear to detect a forced downshift over-rev
                local maxGearSpeeds = { [1] = 55, [2] = 85, [3] = 135 }
                local limit = maxGearSpeeds[gear]
                if limit and mph > limit then
                    -- User money-shifted! Massive immediate engine damage
                    local okE, curE = pcall(GetVehicleEngineHealth, veh)
                    if okE and curE and curE > -4000 then
                        local dmg = 150 * (mph / limit)  -- Scales damage based on how bad the money shift was
                        local newE = math.max(-4000, curE - dmg)
                        pcall(SetVehicleEngineHealth, veh, newE)
                        -- Trigger particle/audio effects via sync if possible, or just kill the engine
                        local netId = NetworkGetNetworkIdFromEntity(veh)
                        if netId and netId > 0 then
                            TriggerServerEvent("jds-physicsEngine:damageApplied", netId, newE, GetVehicleBodyHealth(veh) or 1000)
                        end
                    end
                end
            end

            state.prevVel = v and { x = v.x, y = v.y, z = v.z } or state.prevVel
            state.prevSpeed = speed
            vehicleState[veh] = state
            ::continue::
        end
    end
end)

--- Multiplayer: receive damage sync from other players
RegisterNetEvent("jds-physicsEngine:syncDamage", function(sourcePlayer, netId, engineHealth, bodyHealth)
    if sourcePlayer == GetPlayerServerId(PlayerId()) then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
        pcall(SetVehicleEngineHealth, vehicle, engineHealth)
        pcall(SetVehicleBodyHealth, vehicle, bodyHealth)
    end
end)

--- Cleanup on exit
AddEventHandler("onResourceStop", function(name)
    if GetCurrentResourceName() ~= name then return end
    vehicleState = {}
    lastImpactTime = {}
    redlineStartTime = {}
end)

-- =============================================================================
-- DAMAGE GRIP MODIFIER (for grip_application.lua integration)
-- =============================================================================

--- Returns 0..1 grip modifier based on vehicle damage (engine, body, tires)
---@param vehicle number
---@return number gripMod 1.0 = no penalty, lower = more damaged
function GetDamageGripModifier(vehicle)
    if not perfCfg.enabled or not vehicle or not DoesEntityExist(vehicle) then
        return 1.0
    end

    local penalty = 0
    local maxPenalty = perfCfg.maxGripPenalty or 0.35

    if perfCfg.engineGripPenalty and engineCfg.engineHealthThreshold then
        local ok, health = pcall(GetVehicleEngineHealth, vehicle)
        if ok and health and health < engineCfg.engineHealthThreshold then
            local frac = 1 - (health - (engineCfg.minEngineHealth or -4000)) / (engineCfg.engineHealthThreshold - (engineCfg.minEngineHealth or -4000))
            penalty = penalty + frac * 0.15 -- up to 15% from engine
        end
    end

    if perfCfg.bodyGripPenalty and bodyCfg.bodyHealthThreshold then
        local ok, health = pcall(GetVehicleBodyHealth, vehicle)
        if ok and health and health < bodyCfg.bodyHealthThreshold then
            local frac = 1 - health / bodyCfg.bodyHealthThreshold
            penalty = penalty + frac * 0.12 -- up to 12% from body
        end
    end

    if perfCfg.tireGripPenalty then
        local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
        local burstCount = 0
        local wheelHealthPenalty = 0
        for i = 0, numWheels - 1 do
            local ok, burst = pcall(IsVehicleTyreBurst, vehicle, i, false)
            if ok and burst then burstCount = burstCount + 1 end
            if tireCfg.wheelHealthAffectsSteering and GetVehicleWheelHealth then
                local okW, wh = pcall(GetVehicleWheelHealth, vehicle, i)
                if okW and wh and wh < 1000 then
                    wheelHealthPenalty = wheelHealthPenalty + (1 - wh / 1000) * 0.06
                end
            end
        end
        if burstCount > 0 then
            penalty = penalty + (burstCount / numWheels) * 0.25 -- up to 25% from burst tires
        end
        penalty = penalty + math.min(0.1, wheelHealthPenalty) -- up to 10% from low wheel health
    end

    penalty = math.min(maxPenalty, penalty)
    return math.max(0.15, 1.0 - penalty)
end

--- Get full damage snapshot for HUDs / exports
---@param vehicle number
---@return table { engineHealth, bodyHealth, burstTires, gripModifier }
function GetVehicleDamageSnapshot(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return { engineHealth = 1000, bodyHealth = 1000, burstTires = 0, wheelHealth = {}, gripModifier = 1.0 }
    end
    local okE, engine = pcall(GetVehicleEngineHealth, vehicle)
    local okB, body = pcall(GetVehicleBodyHealth, vehicle)
    local burstCount = 0
    local wheelHealth = {}
    local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
    for i = 0, numWheels - 1 do
        local ok, burst = pcall(IsVehicleTyreBurst, vehicle, i, false)
        if ok and burst then burstCount = burstCount + 1 end
        if GetVehicleWheelHealth then
            local okW, wh = pcall(GetVehicleWheelHealth, vehicle, i)
            if okW and wh then wheelHealth[i] = wh end
        end
    end
    return {
        engineHealth = okE and engine or 1000,
        bodyHealth = okB and body or 1000,
        burstTires = burstCount,
        wheelHealth = wheelHealth,
        totalWheels = numWheels,
        gripModifier = GetDamageGripModifier(vehicle),
    }
end
