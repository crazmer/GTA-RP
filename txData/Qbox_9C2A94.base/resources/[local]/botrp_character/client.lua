local uiOpen = false
local busy = false
local sessionReady = false
local previewing = false
local lifecycle = 'BOOT'
local transitionStartedAt = 0

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

local function forceGameplayVisible(ped)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        ClearPedTasksImmediately(ped)
    end
    SetNuiFocus(false, false)
    DisplayRadar(true)
    stopLoadingScreen()
    DoScreenFadeIn(0)
end

local function safeGameplaySpawn()
    lifecycle = 'SPAWNING'
    transitionStartedAt = GetGameTimer()
    debugLog('Starting deterministic gameplay spawn')

    closeUi()
    stopLoadingScreen()
    DisplayRadar(false)

    local spawn = Config.NewCharacterSpawn or Config.FallbackSpawn or vec4(-1037.8, -2737.8, 20.2, 330.0)
    local ped = ensurePlayerEntity(10000)
    if ped == 0 then
        forceGameplayVisible(0)
        lifecycle = 'ERROR'
        busy = false
        notify('Player could not be initialized. Please reconnect.', 'error')
        return false
    end

    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, true)

    local loadSceneStarted = false
    local okScene = pcall(function()
        NewLoadSceneStart(spawn.x, spawn.y, spawn.z, spawn.x, spawn.y, spawn.z, 50.0, 0)
        loadSceneStarted = true
    end)

    if okScene then
        local collisionDeadline = GetGameTimer() + 5000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionDeadline do
            RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
            Wait(50)
        end
    else
        debugLog('NewLoadSceneStart failed; continuing without scene preload')
    end

    if loadSceneStarted then
        pcall(NewLoadSceneStop)
    end

    local moveOk, moveErr = pcall(function()
        ClearPedTasksImmediately(ped)
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
        SetEntityHeading(ped, spawn.w or 0.0)
    end)

    forceGameplayVisible(ped)
    busy = false

    if not moveOk then
        lifecycle = 'ERROR'
        debugLog(('Final player placement failed: %s'):format(tostring(moveErr)))
        notify('Spawn placement failed. Please reconnect.', 'error')
        return false
    end

    lifecycle = 'COMPLETE'
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
        local ok, err = pcall(function()
            TriggerEvent('qb-spawn:client:setupSpawns')
        end)
        if not ok then
            debugLog(('qbx_spawn handoff failed: %s'):format(tostring(err)))
            return safeGameplaySpawn()
        end
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
    SendNUIMessage({ action = 'setBusy', busy = true })
    stopLoadingScreen()

    local success = lib.callback.await('qbx_core:server:loadCharacter', false, citizenid)
    if not success then
        forceGameplayVisible(PlayerPedId())
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
    transitionStartedAt = GetGameTimer()
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

    -- Qbox Login() has already created the server Player. The client load
    -- event may arrive before or after this callback; neither case should
    -- cause a black screen. Never fade out until the final spawn is ready.
    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline and not QBX.IsLoggedIn do
        Wait(50)
    end

    local spawnOk, spawnErr = pcall(safeGameplaySpawn)
    if not spawnOk then
        debugLog(('Post-create spawn threw an error: %s'):format(tostring(spawnErr)))
        forceGameplayVisible(PlayerPedId())
        lifecycle = 'ERROR'
        busy = false
        notify('Character was created, but spawn recovery was required.', 'error')
    end
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
    if QBX.IsLoggedIn then return end
    openUi()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    debugLog('Qbox player loaded event received')
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
    -- Absolute safety net: BotRP must never leave the player faded out during
    -- a character transition, regardless of Qbox state or a downstream error.
    while true do
        Wait(1000)
        if sessionReady and (lifecycle == 'CREATING_CHARACTER' or lifecycle == 'WAITING_FOR_PLAYER' or lifecycle == 'SPAWNING') then
            local age = GetGameTimer() - transitionStartedAt
            if IsScreenFadedOut() and age >= 5000 then
                debugLog(('Fade watchdog recovered lifecycle state %s'):format(lifecycle))
                forceGameplayVisible(PlayerPedId())
                lifecycle = 'ERROR'
                busy = false
                notify('Character transition recovered from a stalled screen.', 'error')
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        forceGameplayVisible(PlayerPedId())
    end
end)
