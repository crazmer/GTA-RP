# BotRP Character Foundation

Version: 0.1.0

BotRP's character presentation layer for the Qbox server.

## What it does

- Replaces Qbox's built-in character-selection presentation with a standalone BotRP NUI.
- Uses Qbox's existing character callbacks for listing, loading and creating characters.
- Uses Qbox's own deletion event so character ownership rules remain in Qbox.
- Uses the existing `qbx_apartments` / `qbx_spawn` resources when available.
- Does not write directly to the `players` database table.
- Can be shared as a standalone BotRP resource with other Qbox servers.

## Dependencies

Required:

- `qbx_core`
- `ox_lib`

Recommended/used when present:

- `qbx_spawn`
- `qbx_apartments`
- `illenium-appearance`
- `spawnmanager`

## Installation

1. Put `botrp_character` inside your server's `[local]` resources folder.
2. In `qbx_core/config/client.lua`, set:

```lua
characters = {
    useExternalCharacters = true,
}
```

Keep the rest of the Qbox character configuration intact.

3. Start the resource after `qbx_core`:

```cfg
ensure qbx_core
ensure botrp_character
```

4. Restart the server.

## Important

Qbox remains the source of truth for character persistence. Do not add direct SQL writes to this resource.

If another resource already provides external character management, do not run both systems at the same time.

## Configuration

Edit `config.lua` for:

- Server name
- Maximum visible character slots
- Character deletion availability
- Apartment/spawn preference
- Fallback spawn location
- UI accent/background colors

## Current character fields

The UI reads the character information already supplied by Qbox:

- First/last name
- Citizen ID
- Birth date
- Job and grade
- Cash
- Bank
- Nationality

## Future foundation work

Planned next layers can build on this resource without changing Qbox core:

- Character onboarding/backstory
- Spawn preferences
- Character profile cards
- Identity/ID documents
- New-player tutorial state
- Character-specific settings
