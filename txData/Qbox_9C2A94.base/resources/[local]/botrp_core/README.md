# BotRP Core

Player-experience foundation for BotRP.

## Player identity

`client/identity.lua` normalizes the active Qbox character into one read-only identity object for BotRP resources. Qbox remains the authoritative source for persistence and player lifecycle.

Client exports:

- `exports.botrp_core:GetIdentity()`
- `exports.botrp_core:IsCharacterLoaded()`
- `exports.botrp_core:GetCitizenId()`
- `exports.botrp_core:GetCharacterName()`

Client event:

- `BotRP:PlayerIdentityUpdated(identity, reason)`
- `botrp_core:client:identityUpdated(identity, reason)`

Server export/callback:

- `exports.botrp_core:GetIdentity(source)`
- `lib.callback.await('botrp_core:server:getIdentity', false)`

The normalized object contains character identity, job/grade, gang/grade and money values used by BotRP systems. Resources should consume these exports/events instead of repeatedly querying Qbox or duplicating identity storage.

## Current features

- Lightweight welcome notification after character load
- Optional first-character onboarding dialog
- Minimal responsive NUI HUD for cash, bank, and job
- HUD updates on money/job changes and character load
- HUD hides on character logout
- Server-side join/leave lifecycle logging
- Shared BotRP player identity API

This resource intentionally does not modify qbx_core. It consumes Qbox APIs/events and can be updated independently.
