fx_version 'cerulean'
game 'gta5'

name 'botrp_character'
author 'BotRP Development'
description 'BotRP character selection and creation layer for Qbox'
version '0.2.0'

lua54 'yes'

ui_page 'html/index.html'

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

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'qbx_core',
    'ox_lib'
}
