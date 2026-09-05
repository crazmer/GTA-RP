# BotRP Loadscreen Fix

Small client-side safety resource for BotRP's custom character flow.

It shuts down the FiveM loading-screen NUI after Qbox reports that the player is logged in, preventing the custom character flow from leaving the player on a black screen.

## Installation

Add to `server.cfg` after `qbx_core`:

```cfg
ensure qbx_core
ensure botrp_loadscreenfix
```

Keep the resource separate from `botrp_character` and `botrp_hud` so loading-screen handling can be changed without touching either UI.

## Notes

- Requires `qbx_core`.
- Does not implement character selection, spawning, appearance, or voice.
- Does not create a second character-selection UI.
