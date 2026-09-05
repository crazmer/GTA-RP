fx_version 'cerulean'
game 'gta5'

name 'botrp_core'
author 'BotRP Development'
description 'BotRP Enhanced core experience layer'
version '0.1.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'qbx_core',
    'ox_lib'
}
