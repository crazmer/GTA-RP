local uiOpen = false
local busy = false
local sessionReady = false
local previewing = false
local lifecycle = 'BOOT'

local function debugLog(message)
    if Config.Debug then
        print(('[BotRP Character] %s'):format(message))
    end
end

local function notify(message, type)
    lib.notify({ title = Config.ServerName, description = message, type = type or 'inform' })
end

local function stopLoadingScreen()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
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

local function openUi()
    if uiOpen or busy or not sessionReady or QBX.IsLoggedIn then return end

    lifecycle = 'CHARACTER_SELECTION'
    debugLog('Opening character selection')
    busy = true
    DisplayRadar(false)
    stopLoadingScreen()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)

    local ok, err = pcall(sendCharacters)
    if not ok then
        debugLog(('Character list failed: %s'):format(tostring(err)))
        busy = false
        notify('Character data could not be loaded.', 'error')
        return
    end

    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', serverName = Config.ServerName })
    busy = false
end

local function ensurePlayerEntity(timeout)
    timeout = timeout or 10000
    local deadline = GetGameTimer() + timeout
    while GetGameTimer() < deadline do
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            cache.ped = ped
            return ped
        end
        Wait(100)
    end
    return 0
end

local function safeGameplaySpawn()
    lifecycle = 'SPAWNING'
    debugLog('Starting deterministic gameplay spawn')

    closeUi()
    stopLoadingScreen()
    SetNuiFocus(false, false)
    DisplayRadar(false)

    local spawn = Config.NewCharacterSpawn or Config.FallbackSpawn or vec4(-1037.8, -2737.8, 20.2, 330.0)
    local ped = ensurePlayerEntity(10000)

    if ped == 0 then
        debugLog('Player entity was not ready after creation')
        SetNuiFocus(false, false)
        DisplayRadar(true)
        DoScreenFadeIn(0)
        lifecycle = 'ERROR'
        busy = false
        notify('Player could not be initialized. Please reconnect.', 'error')
        return false
    end

    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    NewLoadSceneStart(spawn.x, spawn.y, spawn.z, spawn.x, spawn.y, spawn.z, 50.0, 0)

    local collisionDeadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionDeadline do
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        Wait(50)
    end
    NewLoadSceneStop()

    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.w or 0.0)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    DisplayRadar(true)
    DoScreenFadeIn(0)
    SetGameplayCamRelativePitch(0.0, 1.0)
    lifecycle = 'COMPLETE'
    busy = false
    debugLog('Character lifecycle COMPLETE')
    return true
end

local function openExistingCharacterSpawn()
    lifecycle = 'SPAWNING'
    debugLog('Starting existing-character spawn')
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
            local requested = lib.requestModel(model, Config.PreviewModelTimeout or 5000)
            if not requested then error('preview model timeout') end
            SetPlayerModel(cache.playerId, model)
            if GetResourceState('illenium-appearance') == 'started' then
                local appearance = json.decode(clothing)
                if appearance then
                    exports['illenium-appearance']:setPedAppearance(PlayerPedId(), appearance)
                end
            end
            SetModelAsNoLongerNeeded(model)
        end)
        if not modelOk then notify('Character preview could not be loaded.', 'error') end
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
    lifecycle = 'LOADING_CHARACTER'
    debugLog(('Loading character %s'):format(citizenid))
    SendNUIMessage({ action = 'setBusy', busy = true })
    stopLoadingScreen()

    local success = lib.callback.await('qbx_core:server:loadCharacter', false, citizenid)
    if not success then
        DoScreenFadeIn(0)
        busy = false
        lifecycle = 'CHARACTER_SELECTION'
        SendNUIMessage({ action = 'setBusy', busy = false })
        notify('Unable to load that character.', 'error')
        return
    end

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

    busy = true
    lifecycle = 'CREATING_CHARACTER'
    debugLog('Create request received')
    SendNUIMessage({ action = 'setBusy', busy = true })
    stopLoadingScreen()

    local ok, newData = pcall(function()
        return lib.callback.await('qbx_core:server:createCharacter', false, {
            firstname = firstName,
            lastname = lastName,
            nationality = nationality,
            gender = gender,
            birthdate = birthdate,
        })
    end)

    if not ok or not newData then
        debugLog(('Character creation failed: %s'):format(tostring(newData)))
        busy = false
        lifecycle = 'CHARACTER_SELECTION'
        SendNUIMessage({ action = 'setBusy', busy = false })
        notify('Character creation failed. Check your details or character limit.', 'error')
        return
    end

    debugLog('Qbox character creation complete')
    lifecycle = 'WAITING_FOR_PLAYER'
    SendNUIMessage({ action = 'setBusy', busy = true })

    -- Login() has already created the Player object server-side. We do not
    -- call loadCharacter or trigger OnPlayerLoaded manually. Wait only until
    -- the client-side Qbox state is ready, but never hold the screen black.
    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline and not QBX.IsLoggedIn do
        Wait(50)
    end

    if not QBX.IsLoggedIn then
        debugLog('Qbox client login event did not arrive; continuing with safe spawn')
    else
        debugLog('Qbox client player initialized')
    end

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

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    Wait(250)
    if QBX.IsLoggedIn then return end
    openUi()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    debugLog('Qbox player loaded event received')
    if lifecycle == 'CHARACTER_SELECTION' then return end
    stopLoadingScreen()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    debugLog('Qbox player unload event received')
    lifecycle = 'CHARACTER_SELECTION'
    busy = false
    previewing = false
end)

CreateThread(function()
    debugLog('Resource started')
    while GetResourceState('qbx_core') ~= 'started' do Wait(250) end
    debugLog('qbx_core ready')

    while not NetworkIsSessionStarted() do Wait(250) end
    sessionReady = true

    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    stopLoadingScreen()
    Wait(250)

    if not QBX.IsLoggedIn then
        openUi()
    else
        lifecycle = 'COMPLETE'
    end
end)

CreateThread(function()
    -- Last-resort recovery: while BotRP owns the character transition, never
    -- permit the player to remain faded out indefinitely.
    while true do
        Wait(1000)
        if sessionReady and not QBX.IsLoggedIn and (lifecycle == 'WAITING_FOR_PLAYER' or lifecycle == 'SPAWNING') and IsScreenFadedOut() then
            debugLog(('Fade watchdog recovered lifecycle state %s'):format(lifecycle))
            DoScreenFadeIn(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        DoScreenFadeIn(0)
    end
end)
