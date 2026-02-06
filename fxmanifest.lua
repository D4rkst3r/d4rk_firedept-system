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
    'shared/*.lua'
}

-- Server-only Files
server_scripts {
    'core/permissions.lua',
    'core/storage.lua',
    'modules/*/server.lua' -- Wildcard: lädt alle server.lua in modules
}

-- Client-only Files
client_scripts {
    'core/main.lua',
    'core/interaction.lua',
    'modules/*/client.lua'
}

-- UI Files (HTML/CSS/JS)
ui_page 'ui/html/index.html'
files {
    'ui/html/*.html',
    'ui/html/*.css',
    'ui/html/*.js'
}
