local visible = false
local voiceMode = 2
local radioActive = false
local loggedIn = false
local playerDataCache = {}

local function clamp(value, min, max)
    value = tonumber(value) or 0
    return math.max(min, math.min(max, value))
end

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function getPlayerData()
    -- qbx_core's playerdata module is imported by fxmanifest.lua and exposes
    -- the authoritative live client data as QBX.PlayerData.
    if type(QBX) == 'table' and type(QBX.PlayerData) == 'table' and next(QBX.PlayerData) ~= nil then
        playerDataCache = QBX.PlayerData
        return QBX.PlayerData
    end

    if type(playerDataCache) == 'table' and next(playerDataCache) ~= nil then
        return playerDataCache
    end

    return nil
end

local function healthPercent(ped)
    if not DoesEntityExist(ped) then return 0 end

    local data = getPlayerData()
    local metadata = data and data.metadata or {}
    local metadataHealth = tonumber(metadata.health)

    if metadataHealth then
        return math.floor(clamp(metadataHealth, 0, 100))
    end

    local maxHealth = GetEntityMaxHealth(ped)
    local currentHealth = GetEntityHealth(ped)
    if maxHealth <= 100 then return 0 end

    return math.floor(clamp(((currentHealth - 100) / (maxHealth - 100)) * 100, 0, 100))
end

local function getNeeds(data)
    local metadata = data and data.metadata or {}
    local hunger = tonumber(metadata.hunger)
    local thirst = tonumber(metadata.thirst)

    if hunger == nil and thirst == nil then return nil end
    if hunger == nil then return math.floor(clamp(thirst, 0, 100)) end
    if thirst == nil then return math.floor(clamp(hunger, 0, 100)) end

    return math.floor(math.min(clamp(hunger, 0, 100), clamp(thirst, 0, 100)))
end

local function voiceLabel()
    if voiceMode == 1 then return 'Whisper' end
    if voiceMode == 3 then return 'Shout' end
    return 'Normal'
end

local function sendHud(data)
    local playerData = data or getPlayerData()
    local ped = PlayerPedId()
    local moneyData = type(playerData) == 'table' and playerData.money or {}
    local job = type(playerData) == 'table' and playerData.job or {}
    local gradeData = type(job) == 'table' and type(job.grade) == 'table' and job.grade or {}
    local grade = gradeData.name or job.grade_label or gradeData.level or job.grade or 'Freelancer'
    local muted = false

    if type(MumbleIsPlayerMuted) == 'function' then
        local ok, result = pcall(MumbleIsPlayerMuted, PlayerId())
        muted = ok and result == true
    end

    -- The NUI is deliberately updated even when Qbox data is temporarily
    -- unavailable. This keeps the HUD visible after a resource restart while
    -- the player-data module catches up.
    SendNUIMessage({
        action = 'update',
        ready = type(playerData) == 'table' and next(playerData) ~= nil,
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

    if type(playerData) == 'table' and next(playerData) ~= nil then
        playerDataCache = playerData
        loggedIn = true
    end

    return true
end

local function hideHud()
    SendNUIMessage({ action = 'hide' })
    visible = false
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    loggedIn = true
    CreateThread(function()
        for _ = 1, 40 do
            sendHud()
            if type(QBX) == 'table' and type(QBX.PlayerData) == 'table' and next(QBX.PlayerData) ~= nil then return end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    loggedIn = false
    playerDataCache = {}
    hideHud()
end)

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    sendHud()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    local data = getPlayerData()
    if type(data) == 'table' and type(job) == 'table' then
        data.job = job
        playerDataCache = data
    end
    sendHud(data)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function()
    sendHud()
end)

RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
    voiceMode = tonumber(mode) or 2
    sendHud()
end)

RegisterNetEvent('pma-voice:radioActive', function(active)
    radioActive = active == true
    sendHud()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Show/update immediately. Do not depend on an event that may have fired
    -- before this resource was restarted.
    CreateThread(function()
        for _ = 1, 120 do
            local data = getPlayerData()
            sendHud(data)

            if type(data) == 'table' and next(data) ~= nil then
                return
            end

            Wait(250)
        end
    end)
end)

CreateThread(function()
    -- Keep the UI alive at low frequency and refresh only local/client state.
    -- No server or database polling is performed here.
    while true do
        Wait(1000)

        if IsPauseMenuActive() then
            if visible then hideHud() end
        else
            sendHud()
        end
    end
end)
