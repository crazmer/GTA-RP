local function notify(description, title)
    lib.notify({
        title = title or Config.Name,
        description = description,
        type = 'inform',
        duration = 4500
    })
end

RegisterNetEvent('botrp_core:client:status', function(data)
    notify(('Core %s is online.'):format(data.version), data.name)
end)

CreateThread(function()
    Wait(Config.WelcomeDelay + 500)
    notify('Welcome to BotRP. Your city, your character, your story.', 'Welcome')
end)

CreateThread(function()
    while true do
        Wait(Config.StatusInterval)
        if NetworkIsSessionStarted() then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local health = GetEntityHealth(ped)
                local maxHealth = GetEntityMaxHealth(ped)
                if maxHealth > 0 and health > maxHealth then
                    SetEntityHealth(ped, maxHealth)
                end
            end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
