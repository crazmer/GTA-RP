fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'botrp_core'
author 'BotRP Development'
description 'BotRP player experience foundation'
version '0.3.2'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/playerdata.lua',
    'config/shared.lua'
}

client_scripts {
    'client/main.lua',
    'client/hud.lua',
    'client/onboarding.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

dependencies {
    'ox_lib',
    'qbx_core'
}
