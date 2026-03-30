--[[
    jds-resources :: surface detection
    Raycasts ground, returns materialHash and grip (μ)
    Supports per-wheel detection and async-safe raycast
]]
local Surfaces = Config.Surfaces or {}
local DefaultSurface = Surfaces.Default or { dry = 0.75, wet = 0.50 }
local surfCfg = (Config.PhysicsAdvanced or {}).surfaceDetection or {}
local RAY_LENGTH = surfCfg.rayLength or 2.0
local USE_ALL_WHEELS = surfCfg.useAllWheels == true

local function getSurfaceGrip(materialHash, wetness)
    if not materialHash or materialHash == 0 then
        return DefaultSurface.dry
    end
    local s = Surfaces[materialHash] or DefaultSurface
    local dry, wet = s.dry or 0.75, s.wet or 0.50
    local w = math.max(0, math.min(1, wetness or 0))
    return dry + (wet - dry) * w
end

--- Wheel bone names: 0=lf, 1=rf, 2=lm, 3=rm, 4=lr, 5=rr
local WHEEL_BONES = { [0] = "wheel_lf", [1] = "wheel_rf", [2] = "wheel_lm", [3] = "wheel_rm", [4] = "wheel_lr", [5] = "wheel_rr" }

local function getWheelWorldPosition(vehicle, wheelIndex)
    local boneName = WHEEL_BONES[wheelIndex]
    if not boneName then return nil end
    local bone = GetEntityBoneIndexByName(vehicle, boneName)
    if bone == -1 then return nil end
    return GetWorldPositionOfEntityBone(vehicle, bone)
end

--- Raycast at position; returns materialHash. Uses delayed callback for async safety.
--- Call from main loop - stores result for next-frame read to avoid Wait(0) hack.
local pendingRaycasts = {}
local raycastFrame = 0

local function startRaycast(x, y, z)
    if not x or not y or not z then return nil end
    local handle = StartShapeTestRay(x, y, z, x, y, z - RAY_LENGTH, 1, 0, 0)
    return handle
end

local function getRaycastResult(handle)
    if not handle then return nil end
    local ret, hit, _, _, materialHash, _ = GetShapeTestResultIncludingMaterial(handle)
    if hit and materialHash and materialHash ~= 0 then
        return materialHash
    end
    return nil
end

--- Async-safe: start raycast, return handle. Call getRaycastResult next frame.
function StartGroundRaycast(x, y, z)
    return startRaycast(x, y, z)
end

function GetGroundRaycastResult(handle)
    return getRaycastResult(handle)
end

--- Synchronous single-point (may have 1-frame lag; use for non-critical paths)
local function getGroundMaterialAtPositionSync(x, y, z)
    if not x or not y or not z then return nil end
    local handle = startRaycast(x, y, z)
    Wait(0)
    return getRaycastResult(handle)
end

-- Returns: effectiveMu, materialHash (for single point)
function GetGroundGripAtPosition(x, y, z, roadWetness)
    roadWetness = roadWetness or 0
    local hash = getGroundMaterialAtPositionSync(x, y, z)
    return getSurfaceGrip(hash, roadWetness), hash
end

--- Get min grip across all wheel positions (when useAllWheels) or center
function GetVehicleGroundGrip(vehicle, roadWetness)
    if not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        return DefaultSurface.dry, nil
    end

    roadWetness = roadWetness or 0
    local minMu = 1.0
    local primaryHash = nil

    if USE_ALL_WHEELS then
        local numWheels = GetVehicleNumberOfWheels(vehicle) or 4
        local wheelIndices = (numWheels == 2) and { 0, 1 } or { 0, 1, 4, 5 }
        local validCount = 0

        for _, wi in ipairs(wheelIndices) do
            local wx, wy, wz = getWheelWorldPosition(vehicle, wi)
            if wx and wy and wz then
                local hash = getGroundMaterialAtPositionSync(wx, wy, wz)
                local mu = getSurfaceGrip(hash, roadWetness)
                minMu = math.min(minMu, mu)
                if not primaryHash then primaryHash = hash end
                validCount = validCount + 1
            end
        end

        if validCount == 0 then
            -- Fallback to center
            local x, y, z = GetEntityCoords(vehicle)
            local hash = getGroundMaterialAtPositionSync(x, y, z)
            minMu = getSurfaceGrip(hash, roadWetness)
            primaryHash = hash
        end
    else
        local x, y, z = GetEntityCoords(vehicle)
        local hash = getGroundMaterialAtPositionSync(x, y, z)
        minMu = getSurfaceGrip(hash, roadWetness)
        primaryHash = hash
    end

    return minMu, primaryHash
end
