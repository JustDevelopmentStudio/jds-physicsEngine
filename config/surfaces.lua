--[[
    jds-resources :: surface grip lookup
    Base grip = thunder feel (dry tarmac ~0.36); thunder lowers further for realistic wet
]]
Config = Config or {}
Config.Surfaces = {
    -- Road (base ~thunder-level; thunder applies extra penalty)
    [0x10DD5498] = { dry = 0.33, wet = 0.21 },   -- Tarmac
    [0xB26EEFB0] = { dry = 0.31, wet = 0.19 },   -- TarmacPainted
    [0x70726A55] = { dry = 0.30, wet = 0.18 },   -- TarmacPothole
    [0xF116BC2D] = { dry = 0.24, wet = 0.18 },   -- RumbleStrip
    [0x46CA81E8] = { dry = 0.31, wet = 0.19 },   -- Concrete
    [0x1567BF52] = { dry = 0.29, wet = 0.18 },   -- ConcretePothole
    [0xBF59B491] = { dry = 0.25, wet = 0.16 },   -- ConcreteDusty
    [0x78239B1A] = { dry = 0.31, wet = 0.18 },   -- ConcretePavement
    [0x2D9C1E0D] = { dry = 0.25, wet = 0.16 },   -- Stone
    [0x2257A573] = { dry = 0.24, wet = 0.14 },   -- Cobblestone
    [0x61B1F936] = { dry = 0.25, wet = 0.15 },   -- Brick
    [0xBB9CA6D8] = { dry = 0.24, wet = 0.15 },   -- BrickPavement
    [0xC72165D6] = { dry = 0.24, wet = 0.14 },   -- BreezeBlock
    [0xD48AA0F2] = { dry = 0.21, wet = 0.14 },   -- MetalSolidRoadSurface
    [0x8388FA6C] = { dry = 0.31, wet = 0.18 },   -- StuntRampSurface
    -- Loose
    [0xA0EBF7E4] = { dry = 0.18, wet = 0.12 },   -- SandLoose
    [0x1E6D775E] = { dry = 0.21, wet = 0.14 },   -- SandCompact
    [0x363CBCD5] = { dry = 0.15, wet = 0.14 },   -- SandWet
    [0x8E4D8AFF] = { dry = 0.21, wet = 0.14 },   -- SandTrack
    [0x1E5E7A48] = { dry = 0.16, wet = 0.12 },   -- SandDryDeep
    [0x4CCC2AFF] = { dry = 0.14, wet = 0.12 },   -- SandWetDeep
    [0x38BBD00C] = { dry = 0.23, wet = 0.15 },   -- GravelSmall
    [0x7EDC5571] = { dry = 0.21, wet = 0.14 },   -- GravelLarge
    [0xEABD174E] = { dry = 0.18, wet = 0.14 },   -- GravelDeep
    [0x72C668B6] = { dry = 0.18, wet = 0.14 },   -- GravelTrainTrack
    [0x8F9CD58F] = { dry = 0.23, wet = 0.14 },   -- DirtTrack
    [0x8C31B7EA] = { dry = 0.21, wet = 0.12 },   -- MudHard
    [0x129ECA2A] = { dry = 0.18, wet = 0.12 },   -- MudPothole
    [0x61826E7A] = { dry = 0.16, wet = 0.08 },   -- MudSoft
    [0x42251DC0] = { dry = 0.14, wet = 0.08 },   -- MudDeep
    [0x0D4C07E2] = { dry = 0.12, wet = 0.06 },   -- Marsh
    [0x5E73A22E] = { dry = 0.12, wet = 0.06 },   -- MarshDeep
    [0xD63CCDDB] = { dry = 0.21, wet = 0.14 },   -- Soil
    [0x4434DFE7] = { dry = 0.21, wet = 0.12 },   -- ClayHard
    [0x216FF3F0] = { dry = 0.16, wet = 0.08 },   -- ClaySoft
    [0xCDEB5023] = { dry = 0.25, wet = 0.16 },   -- Rock
    [0xF8902AC8] = { dry = 0.21, wet = 0.14 },   -- RockMossy
    [0x4F747B87] = { dry = 0.18, wet = 0.14 },   -- Grass
    [0xB34E900D] = { dry = 0.18, wet = 0.14 },   -- GrassShort
    [0xE47A3E41] = { dry = 0.16, wet = 0.12 },   -- GrassLong
    [0x92B69883] = { dry = 0.14, wet = 0.12 },   -- Hay
    [0x22AD7B72] = { dry = 0.14, wet = 0.10 },   -- Bushes
    [0x8653C6CD] = { dry = 0.12, wet = 0.08 },   -- Leaves
    -- Ice & Snow
    [0xD125AA55] = { dry = 0.06, wet = 0.05 },   -- Ice
    [0x8CE6E7D9] = { dry = 0.08, wet = 0.05 },   -- IceTarmac
    [0x8C8308CA] = { dry = 0.14, wet = 0.08 },   -- SnowLoose
    [0xCBA23987] = { dry = 0.15, wet = 0.12 },   -- SnowCompact
    [0x608ABC80] = { dry = 0.12, wet = 0.08 },   -- SnowDeep
    [0x5C67C62A] = { dry = 0.14, wet = 0.08 },   -- SnowTarmac
    -- Fluids & hazards
    [0x19F81600] = { dry = 0.03, wet = 0.03 },   -- Water
    [0x3B982E13] = { dry = 0.06, wet = 0.06 },   -- Puddle
    [0xDA2E9567] = { dry = 0.05, wet = 0.05 },   -- Oil
    [0x9E98536C] = { dry = 0.05, wet = 0.05 },   -- Petrol
    -- Default fallback (used when material unknown - assume paved)
    [0x962C3F7B] = { dry = 0.31, wet = 0.21 },   -- Default (concrete-like)
}
Config.Surfaces.Default = { dry = 0.31, wet = 0.21 }
