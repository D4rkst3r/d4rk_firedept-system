fx_version 'cerulean'
game 'gta5'

-- Ressourcen-Info
author 'D4rkst3r'
description 'Modulares Fire Department System'
version '0.0.1'

-- WARUM lua54? Moderne Lua-Features (bessere Performance, neue Syntax)
lua54 'yes'

-- Shared Files (laufen auf Client UND Server)
shared_scripts {
    'config.lua',
    'shared/functions.lua',
    'shared/events.lua',
    'modules/fire/config.lua' -- Fire Module Config laden
}

-- Server-only Files
server_scripts {
    'core/permissions.lua', -- Rechteverwaltung
    'core/storage.lua',
    'modules/fire/server.lua'
}

-- Client-only Files
client_scripts {
    'core/main.lua',
    'core/utils.lua',
    'modules/fire/client.lua'
}
