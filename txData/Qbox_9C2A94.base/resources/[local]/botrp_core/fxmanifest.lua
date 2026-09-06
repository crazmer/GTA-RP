fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'botrp_core'
author 'BotRP Development'
description 'BotRP player experience foundation'
version '0.4.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/playerdata.lua',
    'config/shared.lua'
}

client_scripts {
    'client/identity.lua',
    'client/main.lua',
    'client/onboarding.lua'
}

server_scripts {
    'server/identity.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'qbx_core'
}
