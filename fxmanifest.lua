fx_version 'cerulean'
game 'gta5'
name "old_economy"
description "economy manager"
author "OldMoney"
version "1.0.0"

ui_page 'ui/dist/index.html'

files {
	'ui/dist/index.html',
	'ui/dist/assets/**'
}

shared_scripts {
	'@es_extended/imports.lua',
	'shared/*.lua'
}

client_scripts {
	'client/*.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua'
}
