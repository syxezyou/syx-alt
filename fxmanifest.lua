fx_version 'cerulean'
game 'gta5'

author 'SYX'
description 'Roue RP et ciblage autonome avec la touche Alt'
version '1.0.0'

ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }

shared_script 'config.lua'
client_scripts { 'client/roleplay.lua', 'client/target.lua', 'client/main.lua' }
server_script 'server/main.lua'
