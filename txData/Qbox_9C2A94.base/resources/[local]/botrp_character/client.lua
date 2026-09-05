local uiOpen = false
local busy = false
local sessionReady = false
local previewing = false

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
    previewing = false
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

local function openQbxSpawn()
    closeUi()
    SetNuiFocus(false, false)
    DisplayRadar(false)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    if GetResourceState('qbx_spawn') ~= 'started' then return false end

    -- qbx_spawn owns the spawn camera and waits for its own server callbacks.
    -- Its installed event intentionally takes no arguments.
    TriggerEvent('qb-spawn:client:setupSpawns')
    return true
end

local function spawnFallback()
    closeUi()
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    local spawn = Config.DefaultSpawn or vec4(-540.58, -212.02, 37.65, 208.88)
    local ped = PlayerPedId()

    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.w or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)

    -- qbx_core Login has already created the online player. This is the same
    -- client loaded event used by Qbox's no-apartment spawn path.
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    DoScreenFadeIn(750)
end

local function finishNewCharacter()
    -- New-character spawning is deliberately deterministic. The custom
    -- character manager must not depend on an apartment resource or a second
    -- multicharacter/spawn implementation. Existing characters can still use
    -- qbx_spawn below.
    spawnFallback()
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
        local loaded = pcall(function()
            lib.requestModel(model, Config.PreviewModelTimeout or 5000)
            SetPlayerModel(cache.playerId, model)
            if GetResourceState('illenium-appearance') == 'started' then
                exports['illenium-appearance']:setPedAppearance(PlayerPedId(), json.decode(clothing))
            end
            SetModelAsNoLongerNeeded(model)
        end)

        if not loaded then
            notify('Character preview could not be displayed.', 'error')
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
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    local success = lib.callback.await('qbx_core:server:loadCharacter', false, citizenid)
    if not success then
        DoScreenFadeIn(250)
        busy = false
        notify('Unable to load that character.', 'error')
        sendCharacters()
        return
    end

    busy = false
    if not openQbxSpawn() then
        spawnFallback()
    end
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
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- qbx_core creates AND logs in the new character in this callback.
    -- Never call loadCharacter a second time.
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

    local deadline = GetGameTimer() + 5000
    while not QBX.IsLoggedIn and GetGameTimer() < deadline do
        Wait(50)
    end

    if not QBX.IsLoggedIn then
        print('[botrp_character] ERROR: qbx_core did not finish client login after creation')
        DoScreenFadeIn(500)
        busy = false
        openUi()
        return
    end

    busy = false
    finishNewCharacter()
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
