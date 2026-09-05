# BotRP — GTA V Enhanced local test

## 1. Server files
Use the current recommended FiveM for GTAV Enhanced server build. Cfx.re documents that the Enhanced Windows server executable is `cfx-server.exe`.

## 2. Database
Create a local MySQL/MariaDB database for Qbox and import the schema required by the resources in this repository. Keep credentials only in `txData/Qbox_9C2A94.base/server.local.cfg`.

## 3. Local secrets
Copy:

`txData/Qbox_9C2A94.base/server.local.cfg.example`

to:

`txData/Qbox_9C2A94.base/server.local.cfg`

Set your private Cfx.re license key and local database connection string. Do not commit this file.

## 4. Start
Run the Enhanced server from the server-data directory with the configuration loaded by txAdmin or with `+exec server.cfg`.

## 5. First in-game checks
- Connect with the GTA V Enhanced FiveM client.
- Confirm Qbox character flow appears.
- Confirm inventory and phone load.
- Confirm banking/vehicles load after database initialization.
- Use `/botrphelp` for the basic onboarding message.
- Use `/botrpstatus` to verify the BotRP core resource.

## 6. If startup fails
Fix fatal resource/database/configuration errors before testing gameplay. Warnings about legacy assets should be handled resource-by-resource for Enhanced rather than by blindly renaming folders.
