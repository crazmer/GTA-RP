local uiOpen = false
local busy = false

local function notify(message, type)
    lib.notify({ title = 'BotRP', description = message, type = type or 'inform' })
end

local function closeUi()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function sendCharacters()
    local characters, amount = lib.callback.await('qbx_core:server:getCharacters', false)
    characters = characters or {}
    amount = tonumber(amount) or Config.MaxVisibleCharacters
    SendNUIMessage({
        action = 'setCharacters',
        characters = characters,
        maxCharacters = math.min(amount, Config.MaxVisibleCharacters),
        serverName = Config.ServerName
    })
end

local function openUi()
    if uiOpen or busy then return end
    busy = true
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    DisplayRadar(false)
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    sendCharacters()
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', serverName = Config.ServerName })
    DoScreenFadeIn(350)
    busy = false
end

local function spawnAfterCharacter(cData)
    closeUi()
    DisplayRadar(false)

    if Config.PreferApartments and GetResourceState('qbx_apartments') == 'started' then
        TriggerEvent('apartments:client:setupSpawnUI', cData)
        return
    end

    if Config.PreferQbxSpawn and GetResourceState('qbx_spawn') == 'started' then
        TriggerEvent('qb-spawn:client:setupSpawns', cData)
        TriggerEvent('qb-spawn:client:openUI', true)
        return
    end

    local spawn = Config.DefaultSpawn
    if QBX and QBX.PlayerData and QBX.PlayerData.position then
        local position = QBX.PlayerData.position
        if position.x and position.y and position.z then
            spawn = vec4(position.x, position.y, position.z, position.w or spawn.w)
        end
    end

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    SetEntityCoords(cache.ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(cache.ped, spawn.w)
    SetEntityVisible(cache.ped, true, false)
    FreezeEntityPosition(cache.ped, false)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end
    DisplayRadar(true)
    DoScreenFadeIn(350)
end

RegisterNUICallback('selectCharacter', function(data, cb)
    cb({ ok = true })
    if busy then return end
    local citizenid = tostring(data.citizenid or '')
    if citizenid == '' then return end

    busy = true
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    local success = lib.callback.await('qbx_core:server:loadCharacter', false, citizenid)
    if not success then
        DoScreenFadeIn(250)
        busy = false
        notify('Unable to load that character.', 'error')
        sendCharacters()
        return
    end
    Wait(250)
    busy = false
    spawnAfterCharacter({ citizenid = citizenid })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    cb({ ok = true })
    if busy then return end

    local firstName = tostring(data.firstname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local lastName = tostring(data.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local nationality = tostring(data.nationality or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local birthdate = tostring(data.birthdate or '')
    local gender = tonumber(data.gender)

    if #firstName < 2 or #firstName > 50 or #lastName < 2 or #lastName > 50 then
        notify('Enter a valid first and last name.', 'error')
        return
    end
    if #nationality < 2 or #nationality > 50 or birthdate == '' or (gender ~= 0 and gender ~= 1) then
        notify('Complete all character details.', 'error')
        return
    end

    busy = true
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    local newData = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = firstName,
        lastname = lastName,
        nationality = nationality,
        birthdate = birthdate,
        gender = gender,
    })

    if not newData then
        DoScreenFadeIn(250)
        busy = false
        notify('Character creation failed. Check your details or character limit.', 'error')
        sendCharacters()
        return
    end
    busy = false
    spawnAfterCharacter(newData)
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    cb({ ok = true })
    if busy or not Config.DeleteCharacters then return end
    local citizenid = tostring(data.citizenid or '')
    if citizenid == '' then return end

    busy = true
    -- Qbox validates the requesting source when handling this event.
    TriggerServerEvent('qbx_core:server:deleteCharacter', citizenid)
    Wait(500)
    busy = false
    sendCharacters()
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    Wait(250)
    openUi()
end)

CreateThread(function()
    while GetResourceState('qbx_core') ~= 'started' do Wait(250) end
    while not NetworkIsSessionStarted() do Wait(250) end
    Wait(750)
    openUi()
end)

exports('OpenCharacterManager', openUi)
exports('CloseCharacterManager', closeUi)
