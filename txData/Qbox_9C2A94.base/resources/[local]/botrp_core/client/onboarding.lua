local shownCharacter = nil

local function showOnboarding()
    if not Config.onboarding.enabled then return end

    local data = QBX.PlayerData
    if not data or not data.citizenid then return end
    if shownCharacter == data.citizenid then return end

    shownCharacter = data.citizenid

    lib.alertDialog({
        header = 'Welcome to BotRP',
        content = '**Your city story starts here.**\n\n• Explore the city and meet other players\n• Find work and build your own path\n• Use your phone and map to get around\n• Treat other players as characters, not menus\n\nThis is a short introduction for new characters.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Got it',
            cancel = 'Close'
        }
    })
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2500)
    showOnboarding()
end)

AddEventHandler('qbx_core:client:playerLoggedOut', function()
    shownCharacter = nil
end)
