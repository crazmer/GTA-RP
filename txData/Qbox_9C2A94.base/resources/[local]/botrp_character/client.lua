local uiOpen = false
local busy = false
local sessionReady = false
local previewing = false

local function notify(message, type)
    lib.notify({ title = Config.ServerName, description = message, type = type or 'inform' })
end

local function closeUi()
    uiOpen = false
    previewing = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function sendCharacters()
    local characters, amount = lib.callback.await('qbx_core:server:getCharacters', false)
    characters = type(characters) == 'table' and characters or {}
    amount = math.max(1, math.min(tonumber(amount) or Config.MaxVisibleCharacters, Config.MaxVisibleCharacters))
    SendNUIMessage({ action = 'setCharacters', characters = characters, maxCharacters = amount, serverName = Config.ServerName })
end

local function stopLoadingScreen()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

local function openUi()
    if uiOpen or busy or not sessionReady then return end
    busy = true
    DisplayRadar(false)
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    stopLoadingScreen()

    local ok, err = pcall(sendCharacters)
    if not ok then
        busy = false
        notify('Character data could not be loaded.', 'error')
        return
    end

    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', serverName = Config.ServerName })
    busy = false
end

local function safeGameplaySpawn()
    -- New characters have no guaranteed persisted last-location yet. Do not
    -- invoke qbx_spawn here: its camera/scaleform flow is unnecessary for a
    -- newly-created player and can leave the client faded out if its UI fails.
    closeUi()
    stopLoadingScreen()
    DisplayRadar(false)

    local spawn = Config.NewCharacterSpawn or vec4(-1037.8, -2737.8, 20.2, 330.0)
    local deadline = GetGameTimer() + 10000

    while (not DoesEntityExist(cache.ped) or not NetworkIsPlayerActive(cache.playerId)) and GetGameTimer() < deadline do
        Wait(100)
    end

    if not DoesEntityExist(cache.ped) then
        notify('Player entity was not ready. Please reconnect.', 'error')
        busy = false
        return false
    end

    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityCoordsNoOffset(cache.ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(cache.ped, spawn.w or 0.0)
    FreezeEntityPosition(cache.ped, false)
    SetEntityVisible(cache.ped, true, false)
    ClearPedTasksImmediately(cache.ped)
    SetEntityInvincible(cache.ped, false)
    DisplayRadar(true)
    DoScreenFadeIn(500)
    busy = false
    return true
end

local function openExistingCharacterSpawn()
    closeUi()
    stopLoadingScreen()
    DisplayRadar(false)

    if GetResourceState('qbx_spawn') == 'started' then
        TriggerEvent('qb-spawn:client:setupSpawns')
        return true
    end

    return safeGameplaySpawn()
end

RegisterNUICallback('previewCharacter', function(data, cb)
    cb({ ok = true })
    if busy or previewing then return end
    local citizenid = tostring(data and data.citizenid or '')
    if citizenid == '' or #citizenid > 64 then return end
    previewing = true
    local ok, clothing, model = pcall(function()
        return lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenid)
    end)
    if ok and model and clothing then
        local modelOk = pcall(function()
            lib.requestModel(model, Config.PreviewModelTimeout or 5000)
            SetPlayerModel(cache.playerId, model)
            if GetResourceState('illenium-appearance') == 'started' then
                local appearance = json.decode(clothing)
                if appearance then
                    exports['illenium-appearance']:setPedAppearance(PlayerPedId(), appearance)
                end
            end
            SetModelAsNoLongerNeeded(model)
        end)
        if not modelOk then
            notify('Character preview could not be loaded.', 'error')
        end
    end
    previewing = false
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    cb({ ok = true })
    if busy then return end
    local citizenid = tostring(data and data.citizenid or '')
    if citizenid == '' or #citizenid > 64 then
        notify('Invalid character selection.', 'error')
        return
    end

    busy = true
    SendNUIMessage({ action = 'setBusy', busy = true })
    stopLoadingScreen()

    local success = lib.callback.await('qbx_core:server:loadCharacter', false, citizenid)
    if not success then
        DoScreenFadeIn(250)
        busy = false
        SendNUIMessage({ action = 'setBusy', busy = false })
        notify('Unable to load that character.', 'error')
        sendCharacters()
        return
    end

    busy = false
    openExistingCharacterSpawn()
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

    -- Keep the NUI visible while the server creates the character. Fading out
    -- before the callback returns is what made callback failures look like a
    -- permanent black screen.
    busy = true
    SendNUIMessage({ action = 'setBusy', busy = true })
    stopLoadingScreen()

    local newData = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = firstName,
        lastname = lastName,
        nationality = nationality,
        gender = gender,
        birthdate = birthdate,
    })

    if not newData then
        busy = false
        SendNUIMessage({ action = 'setBusy', busy = false })
        notify('Character creation failed. Check your details or character limit.', 'error')
        return
    end

    -- Qbox Login() has already loaded the new character. Do not call Login,
    -- OnPlayerLoaded, spawnNoApartments, or qb-spawn again. New characters
    -- receive one deterministic safe spawn; existing characters use qbx_spawn.
    DoScreenFadeOut(150)
    while not IsScreenFadedOut() do Wait(0) end
    safeGameplaySpawn()
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    cb({ ok = true })
    if busy or not Config.DeleteCharacters then return end
    local citizenid = tostring(data and data.citizenid or '')
    if citizenid == '' or #citizenid > 64 then return end
    busy = true
    local success = lib.callback.await('qbx_core:server:deleteCharacter', false, citizenid)
    busy = false
    notify(success and 'Character deleted.' or 'Character could not be deleted.', success and 'success' or 'error')
    sendCharacters()
end)

RegisterNUICallback('ready', function(_, cb) cb({ ok = true }) end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    Wait(250)
    openUi()
end)

CreateThread(function()
    while true do
        Wait(100)
        if NetworkIsSessionStarted() then
            sessionReady = true
            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
            Wait(500)
            openUi()
            break
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        DoScreenFadeIn(250)
    end
end)