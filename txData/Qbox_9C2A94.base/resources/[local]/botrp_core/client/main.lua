local function notify(text, notifyType)
    lib.notify({
        title = 'BotRP',
        description = text,
        type = notifyType or 'inform',
        position = 'top-right'
    })
end

local function welcomePlayer()
    local data = QBX.PlayerData
    if not data or not data.charinfo then return end

    local firstName = data.charinfo.firstname or 'Player'
    notify(('Welcome, %s. Your city story starts now.'):format(firstName), 'success')
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    welcomePlayer()
end)

AddEventHandler('qbx_core:client:playerLoggedOut', function()
    SendNUIMessage({ action = 'hide' })
end)
