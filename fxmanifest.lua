fx_version 'cerulean'
game 'gta5'

dependency 'jds-advanceenvironment'  -- weather + time sync for ambient temp and road wetness

author 'Just Development Studios'
version '2.0.0'
description 'Just Development Studios - advanced physics engine'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

shared_scripts {
    'config/physics.lua',
    'config/surfaces.lua',
    'config/weather.lua',
    'config/physics_advanced.lua',
    'config/vehicle_damage.lua',
    'config/vehicle_performance.lua',
    'config/ambient_temp.lua',
    'config/engines.lua',
    'config/vehicle_engines.lua',
}
client_scripts {
    'client/physics.lua',
    'client/surface_detection.lua',
    'client/road_conditions.lua',
    'client/tire_state.lua',
    'client/vehicle_damage.lua',
    'client/vehicle_performance.lua',
    'client/traction_control.lua',
    'client/grip_application.lua',
    'client/torque_simulator.lua',
    'client/telemetry.lua',
    'exports/client.lua',
}
server_scripts {
    'server/main.lua',
}
