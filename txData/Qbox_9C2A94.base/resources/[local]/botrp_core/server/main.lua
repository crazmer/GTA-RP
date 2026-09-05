local function sendHelp(source)
    TriggerClientEvent('chat:addMessage', source, {
        color = { 232, 237, 242 },
        multiline = true,
        args = { 'BotRP', 'Welcome. Use /botrphelp for this guide. Start by creating your character through the existing Qbox character flow.' }
    })
end

RegisterCommand('botrphelp', function(source)
    if source == 0 then
        print('[BotRP] /botrphelp is an in-game command.')
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 232, 237, 242 },
        multiline = true,
        args = { 'BotRP', 'Getting started: create your character, choose a spawn, explore the city, and use the existing Qbox jobs, inventory, phone, vehicles and banking systems.' }
    })
end, false)

RegisterCommand('botrpstatus', function(source)
    if source == 0 then
        print(('[BotRP] Core %s is running.'):format(Config.Version))
        return
    end

    TriggerClientEvent('botrp_core:client:status', source, {
        name = Config.Name,
        version = Config.Version
    })
end, false)

AddEventHandler('playerJoining', function()
    local source = source
    SetTimeout(Config.WelcomeDelay, function()
        if GetPlayerName(source) then
            sendHelp(source)
        end
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print(('[BotRP] Core %s started.'):format(Config.Version))
end)
