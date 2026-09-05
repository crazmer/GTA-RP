local uiOpen = false
local busy = false
local sessionReady = false

local function notify(message, type)
    lib.notify({
        title = Config.ServerName,
        description = message,
        type = type or 'inform'
    })
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function sendCharacters()
    local characters, amount = lib.callback.await('qbx_core:server:getCharacters', false)
    characters = type(characters) == 'table' and characters or {}
    amount = math.max(1, math.min(tonumber(amount) or Config.MaxVisibleCharacters, Config.MaxVisibleCharacters))

    SendNUIMessage({
        action = 'setCharacters',
        characters = characters,
        maxCharacters = amount,
        serverName = Config.ServerName,
    })
end

local function openUi()
    if uiOpen or busy or not sessionReady then return end

    busy = true
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    DisplayRadar(false)
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    local ok = pcall(sendCharacters)
    if not ok then
        DoScreenFadeIn(250)
        busy = false
        notify('Character data could not be loaded.', 'error')
        return
    end

    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', serverName = Config.ServerName })
    DoScreenFadeIn(350)
    busy = false
end

local function spawnAfterCharacter(citizenid)
    closeUi()
    DisplayRadar(false)

    if Config.PreferApartments and GetResourceState('qbx_apartments') == 'started' then
        TriggerEvent('apartments:client:setupSpawnUI', citizenid)
        return
    end

    if Config.PreferQbxSpawn and GetResourceState('qbx_spawn') == 'started' then
        TriggerEvent('qb-spawn:client:setupSpawns', citizenid)
        TriggerEvent('qb-spawn:client:openUI', true)
        return
    end

    -- Let qbx_core handle its own default spawn path. This avoids duplicating
    -- player-loaded events or persistence logic in BotRP.
    TriggerEvent('qbx_core:client:spawnNoApartments')
end

RegisterNUICallback('selectCharacter', function(data, cb)
    cb({ ok = true })
    if busy then return end

    local citizenid = tostring(data and data.citizenid or '')
    if citizenid == '' or #citizenid > 64 then
        notify('Invalid character selection.', 'error')
        return
    end

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
    spawnAfterCharacter(citizenid)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    cb({ ok = true })
    if busy or type(data) ~= 'table' then return end

    local function clean(value, max)
        value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if #value < 2 or #value > max then return nil end
        return value
    end

    local firstName = clean(data.firstname, 50)
    local lastName = clean(data.lastname, 50)
    local nationality = clean(data.nationality, 50)
    local birthdate = tostring(data.birthdate or '')
    local gender = tonumber(data.gender)

    if not firstName or not lastName or not nationality then
        notify('Enter a valid first name, last name and nationality.', 'error')
        return
    end
    if not birthdate:match('^%d%d%d%d%-%d%d%-%d%d$') then
        notify('Enter a valid birth date.', 'error')
        return
    end
    if gender ~= 0 and gender ~= 1 then
        notify('Select a valid character gender.', 'error')
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
    spawnAfterCharacter(newData.citizenid)
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    cb({ ok = true })
    if busy or not Config.DeleteCharacters then return end

    local citizenid = tostring(data and data.citizenid or '')
    if citizenid == '' or #citizenid > 64 then return end

    busy = true
    local success = lib.callback.await('qbx_core:server:deleteCharacter', false, citizenid)
    busy = false

    if success then
        notify('Character deleted.', 'success')
    else
        notify('Character could not be deleted.', 'error')
    end

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

    sessionReady = true
    Wait(750)
    openUi()
end)

exports('OpenCharacterManager', openUi)
exports('CloseCharacterManager', closeUi)
