local visible = true
local nuiReady = false
local voiceMode = 2
local radioActive = false
local playerDataCache = {}
local lastPayload = nil

local function clamp(value, min, max)
    value = tonumber(value) or 0
    return math.max(min, math.min(max, value))
end

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function getPlayerData()
    if type(QBX) == 'table' and type(QBX.PlayerData) == 'table' and next(QBX.PlayerData) ~= nil then
        playerDataCache = QBX.PlayerData
        return QBX.PlayerData
    end

    if type(playerDataCache) == 'table' and next(playerDataCache) ~= nil then
        return playerDataCache
    end

    return {}
end

local function healthPercent(ped)
    if not DoesEntityExist(ped) then return 0 end
    local maxHealth = GetEntityMaxHealth(ped)
    local currentHealth = GetEntityHealth(ped)
    if maxHealth <= 100 then return 0 end
    return math.floor(clamp(((currentHealth - 100) / (maxHealth - 100)) * 100, 0, 100))
end

local function getNeeds(data)
    local metadata = type(data) == 'table' and data.metadata or {}
    local hunger = tonumber(metadata and metadata.hunger)
    local thirst = tonumber(metadata and metadata.thirst)
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

local function getPing()
    -- GetPlayerPing is not available as a client native on every FXServer
    -- build. Treat ping as optional rather than allowing it to break the HUD.
    if type(GetPlayerPing) == 'function' then
        local ok, result = pcall(GetPlayerPing, PlayerId())
        if ok and tonumber(result) then return tonumber(result) end
    end
    return nil
end

local function buildPayload(data)
    local playerData = data or getPlayerData()
    local ped = PlayerPedId()
    local moneyData = type(playerData.money) == 'table' and playerData.money or {}
    local job = type(playerData.job) == 'table' and playerData.job or {}
    local gradeData = type(job.grade) == 'table' and job.grade or {}
    local grade = gradeData.name or job.grade_label or gradeData.level or job.grade or 'Freelancer'

    return {
        action = 'update',
        cash = money(moneyData.cash),
        bank = money(moneyData.bank),
        job = job.label or job.name or 'Civilian',
        grade = tostring(grade),
        health = healthPercent(ped),
        armor = math.floor(clamp(GetPedArmour(ped), 0, 100)),
        needs = getNeeds(playerData),
        voice = voiceLabel(),
        speaking = NetworkIsPlayerTalking(PlayerId()),
        radio = radioActive,
        ping = getPing(),
    }
end

local function payloadChanged(payload)
    if not lastPayload then return true end
    for key, value in pairs(payload) do
        if key ~= 'action' and lastPayload[key] ~= value then return true end
    end
    return false
end

local function sendHud(force)
    local payload = buildPayload()
    if force or payloadChanged(payload) then
        SendNUIMessage(payload)
        lastPayload = payload
    end
    visible = true
end

local function hideHud()
    if nuiReady then SendNUIMessage({ action = 'hide' }) end
    visible = false
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    lastPayload = nil
    sendHud(true)
    cb({ ok = true })
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        for _ = 1, 40 do
            sendHud(true)
            if type(QBX) == 'table' and type(QBX.PlayerData) == 'table' and next(QBX.PlayerData) ~= nil then
                playerDataCache = QBX.PlayerData
                sendHud(true)
                return
            end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if type(data) == 'table' then playerDataCache = data end
    sendHud(true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerDataCache = {}
    lastPayload = nil
    hideHud()
end)

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    sendHud(true)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if type(playerDataCache) == 'table' and type(job) == 'table' then playerDataCache.job = job end
    sendHud(true)
end)

RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
    voiceMode = tonumber(mode) or 2
    sendHud(true)
end)

RegisterNetEvent('pma-voice:radioActive', function(active)
    radioActive = active == true
    sendHud(true)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    nuiReady = false
    lastPayload = nil
    visible = true
    CreateThread(function()
        for _ = 1, 20 do
            sendHud(true)
            Wait(250)
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(500)
        if IsPauseMenuActive() then
            if visible then hideHud() end
        else
            if not visible then sendHud(true) else sendHud(false) end
        end
    end
end)
