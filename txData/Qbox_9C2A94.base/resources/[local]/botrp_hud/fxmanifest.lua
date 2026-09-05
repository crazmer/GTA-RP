fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'botrp_hud'
author 'BotRP Development'
description 'BotRP standalone player HUD'
version '1.0.1'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

dependencies {
    'qbx_core'
}
