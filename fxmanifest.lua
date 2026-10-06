fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'x_aidispatch'
author 'MR X'
description 'X AI Dispatch - smart emergency dispatch system | X Studio'
version '1.0.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua',
}

files {
    'locales/*.json',
}

escrow_ignore {
    'config.lua',
    'locales/*.json',
    'sql/*.sql',
}
