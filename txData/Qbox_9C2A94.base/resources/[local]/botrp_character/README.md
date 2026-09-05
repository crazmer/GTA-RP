# BotRP Character Foundation

This resource provides the BotRP character-management presentation layer while Qbox remains the owner of character persistence and login state.

## Required Qbox setting

Qbox ships with its own multicharacter system. Before enabling this resource, open the deployed `qbx_core/config/client.lua` and set:

```lua
useExternalCharacters = true
```

Do not modify the qbx_core resource code itself; this is a supported configuration option.

## Flow

1. Player connects.
2. BotRP requests the character list from qbx_core.
3. Player selects an existing character or creates a new one.
4. qbx_core validates and loads/creates the character.
5. BotRP hands spawning to the existing `qbx_apartments`, `qbx_spawn`, or qbx_core default spawn flow.
6. HUD and other BotRP resources consume the resulting Qbox PlayerData.

## Security

BotRP does not write Qbox-owned database tables. Character create/load/delete operations use qbx_core's server callbacks so ownership, identifiers, limits, and persistence remain server-side.

## Resource order

`qbx_core` must start before `botrp_character`. The server config starts this resource after the framework resources.
