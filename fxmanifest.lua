fx_version 'cerulean'
game 'gta5'

dependency 'Renewed-Weathersync'  -- weather + time sync for ambient temp and road wetness

author 'Just Development Studios'
version '1.2'
description 'Just Development Studios - Advanced Physics Engine'

shared_scripts {
    'config/physics.lua',
    'config/surfaces.lua',
    'config/weather.lua',
    'config/physics_advanced.lua',
    'config/vehicle_damage.lua',
    'config/vehicle_performance.lua',
    'config/ambient_temp.lua',
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
    'exports/client.lua',
}
server_scripts {
    'server/main.lua',
}
