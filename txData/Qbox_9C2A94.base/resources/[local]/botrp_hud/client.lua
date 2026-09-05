local visible = false
local voiceMode = 2
local radioActive = false
local loggedIn = false
local playerDataCache = {}

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function money(value)
    return ('$%s'):format(('%d'):format(math.floor(tonumber(value) or 0)))
end

local function healthPercent(ped)
    if not DoesEntityExist(ped) then return 0 end

    local maxHealth = GetEntityMaxHealth(ped)
    local currentHealth = GetEntityHealth(ped)
    if maxHealth <= 100 then return 0 end

    return math.floor(clamp(((currentHealth - 100) / (maxHealth - 100)) * 100, 0, 100))
end

local function getPlayerData()
    -- qbx_core exposes the authoritative client PlayerData through QBX.PlayerData.
    -- The playerdata module is loaded by this resource's fxmanifest, so this is
    -- safe and avoids depending on a load event having fired after a HUD restart.
    if type(QBX) == 'table' and type(QBX.PlayerData) == 'table' and next(QBX.PlayerData) ~= nil then
        playerDataCache = QBX.PlayerData
        return QBX.PlayerData
    end

    if GetResourceState('qbx_core') == 'started' then
        local ok, data = pcall(function()
            return exports.qbx_core:GetPlayerData()
        end)

        if ok and type(data) == 'table' and next(data) ~= nil then
            playerDataCache = data
            return data
        end
    end

    if type(playerDataCache) == 'table' and next(playerDataCache) ~= nil then
        return playerDataCache
    end

    return nil
end

local function getNeeds(data)
    local metadata = data and data.metadata or {}
    local state = LocalPlayer and LocalPlayer.state

    local hunger = state and tonumber(state.hunger) or nil
    local thirst = state and tonumber(state.thirst) or nil

    if hunger == nil then hunger = tonumber(metadata.hunger) end
    if thirst == nil then thirst = tonumber(metadata.thirst) end

    if hunger == nil and thirst == nil then return nil end
    if hunger == nil then return math.floor(clamp(thirst, 0, 100)) end
    if thirst == nil then return math.floor(clamp(hunger, 0, 100)) end

    -- The HUD has one needs slot, so show the lower of hunger/thirst.
    return math.floor(math.min(clamp(hunger, 0, 100), clamp(thirst, 0, 100)))
end

local function voiceLabel()
    if voiceMode == 1 then return 'Whisper' end
    if voiceMode == 3 then return 'Shout' end
    return 'Normal'
end

local function sendHud(data)
    local playerData = data or getPlayerData()
    if type(playerData) ~= 'table' or next(playerData) == nil then return false end

    playerDataCache = playerData
    loggedIn = true

    local moneyData = playerData.money or {}
    local job = playerData.job or {}
    local gradeData = type(job.grade) == 'table' and job.grade or {}
    local grade = gradeData.name or job.grade_label or gradeData.level or job.grade or 'Freelancer'
    local ped = PlayerPedId()
    local muted = false

    if type(MumbleIsPlayerMuted) == 'function' then
        local ok, result = pcall(MumbleIsPlayerMuted, PlayerId())
        muted = ok and result == true
    end

    SendNUIMessage({
        action = 'update',
        ready = true,
        cash = money(moneyData.cash),
        bank = money(moneyData.bank),
        job = job.label or job.name or 'Civilian',
        grade = tostring(grade),
        health = healthPercent(ped),
        armor = math.floor(clamp(GetPedArmour(ped), 0, 100)),
        needs = getNeeds(playerData),
        voice = muted and 'Muted' or voiceLabel(),
        speaking = NetworkIsPlayerTalking(PlayerId()),
        radio = radioActive,
        ping = GetPlayerPing(PlayerId()),
    })

    visible = true
    return true
end

local function refreshHud()
    local coreLoggedIn = type(QBX) == 'table' and QBX.IsLoggedIn == true
    if not loggedIn and not coreLoggedIn then
        local data = getPlayerData()
        if not data then return false end
    end

    return sendHud()
end

local function hideHud()
    SendNUIMessage({ action = 'hide' })
    visible = false
end

-- Qbox uses this event for the authoritative PlayerData update.
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if type(data) == 'table' then
        playerDataCache = data
    end

    loggedIn = true
    sendHud(data)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    loggedIn = true

    CreateThread(function()
        for _ = 1, 40 do
            if sendHud() then return end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    loggedIn = false
    playerDataCache = {}
    hideHud()
end)

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    refreshHud()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    local data = getPlayerData() or playerDataCache
    if type(data) == 'table' and type(job) == 'table' then
        data.job = job
        playerDataCache = data
    end

    refreshHud()
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function()
    refreshHud()
end)

RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
    voiceMode = tonumber(mode) or 2
    refreshHud()
end)

RegisterNetEvent('pma-voice:radioActive', function(active)
    radioActive = active == true
    refreshHud()
end)

AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    loggedIn = value == true

    if loggedIn then
        CreateThread(function()
            for _ = 1, 20 do
                if sendHud() then return end
                Wait(250)
            end
        end)
    else
        hideHud()
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        -- Do not wait for a network event. A HUD resource can be restarted
        -- while the player is already loaded, so read the current Qbox state.
        local timeout = GetGameTimer() + 30000

        while GetGameTimer() < timeout do
            local data = getPlayerData()
            local coreReady = type(QBX) == 'table' and QBX.IsLoggedIn == true

            if data and (coreReady or data.citizenid or data.money or data.job or data.metadata) then
                loggedIn = true
                sendHud(data)
                return
            end

            Wait(250)
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(1000)

        if IsPauseMenuActive() then
            if visible then hideHud() end
        elseif loggedIn or (type(QBX) == 'table' and QBX.IsLoggedIn == true) then
            -- Only local/state data is refreshed here. No server/database polling.
            refreshHud()
        end
    end
end)
