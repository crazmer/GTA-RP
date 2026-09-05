BOTRP HUD - INSTALLATION & SHARING GUIDE
=========================================

Resource name
-------------
botrp_hud

What this resource does
-----------------------
A standalone bottom-right HUD for a Qbox/FiveM server. It displays:
- BOTRP branding
- Cash
- Bank
- Job
- Job grade/role
- Health
- Armor
- Hunger/thirst status
- Voice mode
- Speaking/radio state
- FPS/system status

Resource layout
---------------
botrp_hud/
  fxmanifest.lua
  client.lua
  web/
    index.html
    style.css
    app.js

Requirements
------------
1. FiveM / FXServer with NUI support.
2. Qbox Framework (qbx_core) installed and working.
3. qbx_core must be started before botrp_hud.
4. The server must use the normal Qbox PlayerData structure.

This HUD does NOT require botrp_core.
It is intentionally separated so friends can install it independently.

Required dependency
--------------------
qbx_core

Recommended voice setup
-----------------------
The HUD supports pma-voice events when pma-voice is present, but it does not
start or replace a voice resource. Keep the voice system used by your server.

If your voice setup requires Mumble natives, enable the appropriate Mumble
setting in your server configuration according to the voice resource you use.

Installation
------------
1. Copy the entire folder:
   botrp_hud

2. Place it inside your server resources folder, for example:
   resources/[local]/botrp_hud

3. Add this to server.cfg AFTER qbx_core:

   ensure botrp_hud

4. Restart the server, or use the server console:

   ensure botrp_hud

If your server has another HUD enabled (for example qbx_hud), disable that
HUD if you want botrp_hud to be the only HUD. Do not run two HUDs together
unless you intentionally want both.

Qbox integration
-----------------
The HUD loads Qbox's player-data module and reads the current QBX.PlayerData.
The following fields are expected when available:

playerData.money.cash
playerData.money.bank
playerData.job.label / name
playerData.job.grade.name / level
playerData.metadata.hunger
playerData.metadata.thirst

Health and armor are read locally from the player's ped.

The HUD is designed to tolerate missing optional fields. If hunger/thirst is
not provided by the server, the needs value may show as --% rather than
crashing the resource.

Voice integration
-----------------
The HUD listens for these commonly used pma-voice events when available:

pma-voice:setTalkingMode
pma-voice:radioActive

Voice mode values currently map as:
1 = Whisper
2 = Normal
3 = Shout

If your voice resource uses different events or additional modes, update
client.lua before sharing with that server.

System/FPS indicator
--------------------
The fifth status indicator uses a lightweight client FPS/system value. It does
not depend on GetPlayerPing, because GetPlayerPing is not available in every
client environment/build used by this project.

If you want ping instead, implement it using a server/client method supported
by your target FXServer/client build rather than adding GetPlayerPing back to
this client resource.

HUD position and style
----------------------
Default position: bottom-right.

The HUD uses:
- near-black card background
- blue outline/accent
- transparent NUI canvas outside the card
- responsive sizing

Main styling is in:
web/style.css

NUI behavior is in:
web/app.js

Client/data integration is in:
client.lua

How to update the HUD
---------------------
After replacing files, restart only the resource if the server is already
running:

restart botrp_hud

For a clean update, a full server restart is preferred.

Sharing with friends
--------------------
You can send friends the complete botrp_hud folder.
They should not need botrp_core, your database, or your BotRP server scripts
just to use the HUD.

They DO need a compatible qbx_core installation and should verify their
Qbox version exposes the PlayerData structure expected above.

Common issues
-------------
1. HUD does not appear
   - Confirm the folder contains fxmanifest.lua at the top level.
   - Confirm server.cfg contains: ensure botrp_hud
   - Confirm qbx_core starts before botrp_hud.
   - Check the client F8 console for botrp_hud errors.

2. HUD appears but values stay at defaults
   - Confirm the server is actually using Qbox PlayerData.
   - Check money/job/metadata fields on the friend's Qbox installation.
   - Check client F8 for Lua/NUI errors.

3. Two HUDs appear
   - Disable the other HUD resource, such as qbx_hud.

4. Black fullscreen overlay
   - Make sure the HTML body/canvas remains transparent outside the HUD card.
   - Check that only botrp_hud owns this NUI page.
   - Do not put botrp_hud's ui_page back into another resource.

5. Voice indicator does not change
   - Verify the server's voice resource and event names.
   - The HUD does not provide a voice system by itself.

Testing checklist before sharing
---------------------------------
- Server starts without botrp_hud manifest errors.
- HUD appears after joining a character.
- Cash shows correctly.
- Bank shows correctly.
- Job and grade show correctly.
- Health changes correctly.
- Armor changes correctly.
- Needs display correctly when metadata is available.
- Voice mode changes correctly when supported by the voice resource.
- Radio state changes correctly when supported.
- FPS/system indicator remains stable.
- Pause menu hides the HUD.
- Reconnecting does not permanently hide the HUD.
- Restarting botrp_hud does not create a black overlay.

Compatibility note
------------------
This resource is built for the Qbox architecture used by this project. It is
not a universal QBCore/ESX HUD. For another framework, the client data adapter
must be changed.

Support/debug information to provide
-------------------------------------
When reporting a problem, send:
- FiveM client F8 errors
- server console errors mentioning botrp_hud
- Qbox version
- voice resource name/version
- a screenshot of the HUD/problem

No private server keys, database passwords, tokens, or license keys should be
included in bug reports.
