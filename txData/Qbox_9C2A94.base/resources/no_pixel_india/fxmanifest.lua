fx_version 'cerulean'
game 'gta5'

name 'no_pixel_india'
author 'GTA-RP'
description 'Original NoPixel India experience layer for Qbox'
version '0.2.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua'
}

server_scripts {
    'server.lua'
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

lua54 'yes'
use_experimental_fxv2_oal 'yes'
