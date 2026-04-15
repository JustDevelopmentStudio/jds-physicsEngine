--[[
    jds-physicsEngine :: engine profiles
    Define realistic torque curves and characteristics for various real-world engine types.
]]
Config = Config or {}

-- Torque curve is a table of { RPM_Percentage, Torque_Multiplier }
-- RPM_Percentage: 0.0 is idle, 1.0 is redline
-- Torque_Multiplier: Applied continuously to SetVehicleEngineTorqueMultiplier

Config.Engines = {
    -- Default generic fallback
    ["Generic"] = {
        name = "Generic Default",
        driveInertiaMult = 1.0,  
        topSpeedMult = 1.05,
        curve = {
            {0.0, 0.8}, {0.3, 0.95}, {0.6, 1.0}, {0.8, 1.0}, {1.0, 0.9}
        },
        -- Raised back to just +5% instead of +15%
        gearMultipliers = { [0] = 0.84, [1] = 1.47, [2] = 1.26, [3] = 1.05, [4] = 0.95, [5] = 0.89, [6] = 0.84 }
    },

    ["V8_Muscle"] = {
        name = "NA V8 Muscle",
        driveInertiaMult = 0.85,
        topSpeedMult = 1.10,
        curve = { {0.0, 0.9}, {0.1, 1.3}, {0.4, 1.4}, {0.7, 1.1}, {0.9, 0.8}, {1.0, 0.6} },
        gearMultipliers = { [0] = 1.05, [1] = 1.89, [2] = 1.47, [3] = 1.16, [4] = 0.95, [5] = 0.84, [6] = 0.79 }
    },

    ["I4_Turbo"] = {
        name = "Inline-4 Turbo",
        driveInertiaMult = 1.2,
        topSpeedMult = 1.05,
        curve = { {0.0, 0.6}, {0.2, 0.65}, {0.4, 1.4}, {0.6, 1.5}, {0.8, 1.3}, {1.0, 1.0} },
        gearMultipliers = { [0] = 0.84, [1] = 1.58, [2] = 1.37, [3] = 1.16, [4] = 1.0, [5] = 0.89, [6] = 0.84 }
    },

    ["V12_Hyper"] = {
        name = "High-Rev V12",
        driveInertiaMult = 1.6,
        topSpeedMult = 1.20,
        curve = { {0.0, 0.8}, {0.2, 0.9}, {0.5, 1.1}, {0.8, 1.3}, {0.9, 1.4}, {1.0, 1.3} },
        gearMultipliers = { [0] = 1.05, [1] = 1.68, [2] = 1.37, [3] = 1.26, [4] = 1.05, [5] = 1.0, [6] = 0.95 }
    },

    ["V10_NA"] = {
        name = "NA V10",
        driveInertiaMult = 1.7, 
        topSpeedMult = 1.15,
        curve = { {0.0, 0.75}, {0.3, 0.85}, {0.6, 1.1}, {0.8, 1.35}, {0.95, 1.45}, {1.0, 1.4} },
        gearMultipliers = { [0] = 1.05, [1] = 1.58, [2] = 1.31, [3] = 1.21, [4] = 1.05, [5] = 1.0, [6] = 0.95 }
    },

    ["W16_QuadTurbo"] = {
        name = "W16 Quad Turbo",
        driveInertiaMult = 0.9,
        topSpeedMult = 2.45,
        curve = { {0.0, 1.2}, {0.2, 1.4}, {0.4, 1.6}, {0.6, 1.7}, {0.8, 1.6}, {1.0, 1.4} },
        gearMultipliers = { [0] = 1.58, [1] = 2.63, [2] = 1.89, [3] = 1.47, [4] = 1.16, [5] = 1.0, [6] = 0.89, [7] = 0.84, [8] = 0.79 }
    },

    ["V6_TwinTurbo"] = {
        name = "TT V6 / Flat-6",
        driveInertiaMult = 1.3,
        topSpeedMult = 1.15,
        curve = { {0.0, 0.7}, {0.2, 1.0}, {0.4, 1.35}, {0.7, 1.4}, {0.9, 1.25}, {1.0, 1.0} },
        gearMultipliers = { [0] = 1.05, [1] = 1.63, [2] = 1.37, [3] = 1.16, [4] = 1.05, [5] = 0.95, [6] = 0.89 }
    },

    ["I6_Turbo"] = {
        name = "Inline-6 Turbo",
        driveInertiaMult = 1.3,
        topSpeedMult = 1.13,
        curve = { {0.0, 0.6}, {0.3, 0.7}, {0.5, 1.4}, {0.8, 1.55}, {0.95, 1.3}, {1.0, 1.1} },
        gearMultipliers = { [0] = 0.84, [1] = 1.68, [2] = 1.47, [3] = 1.16, [4] = 1.0, [5] = 0.89, [6] = 0.84 }
    },

    ["Flat4_Turbo"] = {
        name = "Flat-4 Turbo",
        driveInertiaMult = 1.1,
        topSpeedMult = 1.03,
        curve = { {0.0, 0.7}, {0.2, 1.2}, {0.4, 1.35}, {0.6, 1.3}, {0.8, 1.0}, {1.0, 0.8} },
        gearMultipliers = { [0] = 0.84, [1] = 1.52, [2] = 1.31, [3] = 1.16, [4] = 1.0, [5] = 0.89, [6] = 0.84 }
    },

    ["EV_DualMotor"] = {
        name = "Electric Dual Motor",
        driveInertiaMult = 2.0,
        topSpeedMult = 1.10,
        curve = { {0.0, 1.8}, {0.1, 1.8}, {0.3, 1.5}, {0.6, 1.2}, {0.8, 0.9}, {1.0, 0.6} },
        gearMultipliers = { [0] = 1.58, [1] = 1.05, [2] = 1.05, [3] = 1.05, [4] = 1.05, [5] = 1.05, [6] = 1.05 }
    },

    ["Diesel_Heavy"] = {
        name = "Turbo Diesel",
        driveInertiaMult = 0.6,
        topSpeedMult = 0.84,
        curve = { {0.0, 1.0}, {0.1, 1.5}, {0.3, 1.5}, {0.5, 1.0}, {0.8, 0.6}, {1.0, 0.4} },
        gearMultipliers = { [0] = 1.58, [1] = 1.89, [2] = 1.68, [3] = 1.47, [4] = 1.26, [5] = 1.05, [6] = 0.95, [7] = 0.84, [8] = 0.84 }
    },

    ["Rotary_Turbo"] = {
        name = "Rotary Turbo",
        driveInertiaMult = 1.6,
        topSpeedMult = 1.10,
        curve = { {0.0, 0.4}, {0.3, 0.6}, {0.6, 1.3}, {0.8, 1.6}, {0.95, 1.7}, {1.0, 1.6} },
        gearMultipliers = { [0] = 1.05, [1] = 1.58, [2] = 1.37, [3] = 1.26, [4] = 1.05, [5] = 0.95, [6] = 0.84 }
    },

    ["V8_Supercharged"] = {
        name = "Supercharged V8",
        driveInertiaMult = 1.0,
        topSpeedMult = 1.20,
        curve = { {0.0, 1.2}, {0.2, 1.5}, {0.5, 1.55}, {0.7, 1.5}, {0.9, 1.3}, {1.0, 1.1} },
        gearMultipliers = { [0] = 1.05, [1] = 2.1, [2] = 1.68, [3] = 1.37, [4] = 1.05, [5] = 0.95, [6] = 0.84 }
    },

    ["V12_NA"] = {
        name = "Naturally Aspirated V12",
        driveInertiaMult = 1.3,
        topSpeedMult = 1.25,
        curve = { {0.0, 0.9}, {0.3, 1.1}, {0.5, 1.3}, {0.8, 1.4}, {0.9, 1.4}, {1.0, 1.3} },
        gearMultipliers = { [0] = 1.05, [1] = 1.58, [2] = 1.31, [3] = 1.16, [4] = 1.05, [5] = 0.95, [6] = 0.89 }
    },

    ["V4_Motorcycle"] = {
        name = "V4 Superbike",
        driveInertiaMult = 2.0,
        topSpeedMult = 1.25,
        curve = { {0.0, 0.8}, {0.2, 1.1}, {0.5, 1.5}, {0.8, 1.8}, {0.95, 1.9}, {1.0, 1.5} },
        gearMultipliers = { [0] = 1.05, [1] = 1.47, [2] = 1.26, [3] = 1.16, [4] = 1.05, [5] = 1.0, [6] = 0.95 }
    },

    ["Police_Interceptor"] = {
        name = "Police Interceptor V8",
        driveInertiaMult = 1.3,
        topSpeedMult = 1.30,
        curve = { {0.0, 1.0}, {0.3, 1.2}, {0.5, 1.4}, {0.8, 1.45}, {0.9, 1.4}, {1.0, 1.3} },
        gearMultipliers = { [0] = 1.05, [1] = 1.79, [2] = 1.37, [3] = 1.31, [4] = 1.16, [5] = 1.05, [6] = 1.05 }
    }
}
