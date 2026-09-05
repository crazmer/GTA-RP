fx_version 'cerulean'
game 'gta5'

name 'botrp_character'
author 'BotRP Development'
description 'BotRP character foundation and Qbox character management UI'
version '0.1.0'

lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
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
