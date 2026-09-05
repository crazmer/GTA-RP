fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'botrp_hud'
author 'BotRP Development'
description 'BotRP standalone player HUD'
version '1.0.0'

shared_script '@qbx_core/modules/playerdata.lua'

client_script 'client.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

dependencies {
    'qbx_core'
}
