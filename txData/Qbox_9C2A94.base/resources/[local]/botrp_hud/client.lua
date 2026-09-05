local visible = false
local voiceMode = 2
local radioActive = false
local loggedIn = false

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function money(value)
    return ('$%s'):format(('%d'):format(math.floor(tonumber(value) or 0)))
end

local function healthPercent(ped)
    if not DoesEntityExist(ped) then return 0 end
    local max = GetEntityMaxHealth(ped)
    local current = GetEntityHealth(ped)
    if max <= 100 then return 0 end
    return math.floor(clamp(((current - 100) / (max - 100)) * 100, 0, 100))
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

local function getPlayerData()
    if type(QBX) ~= 'table' then return nil end
    if type(QBX.PlayerData) ~= 'table' then return nil end
    return QBX.PlayerData
end

local function sendHud(data)
    local playerData = data or getPlayerData()
    if type(playerData) ~= 'table' then return false end

    local moneyData = playerData.money or {}
    local job = playerData.job or {}
    local gradeData = job.grade or {}
    local grade = gradeData.name or gradeData.level or 'Freelancer'
    local ped = PlayerPedId()
    local muted = false

    if type(MumbleIsPlayerMuted) == 'function' then
        local ok, result = pcall(MumbleIsPlayerMuted, PlayerId())
        muted = ok and result == true
    end

    SendNUIMessage({
        action = 'update',
        ready = playerData.charinfo ~= nil,
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
    if not loggedIn then return end
    sendHud()
end

local function hideHud()
    SendNUIMessage({ action = 'hide' })
    visible = false
end

-- Qbox uses these events to publish the authoritative PlayerData table to
-- clients. Listening to the full-data event is important because money,
-- metadata and character/job changes are all reflected there.
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    loggedIn = true
    sendHud(data)
end)

RegisterNetEvent('qbx_core:client:onPlayerDataChanged', function()
    loggedIn = true
    refreshHud()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    loggedIn = true
    CreateThread(function()
        for _ = 1, 10 do
            if sendHud() then return end
            Wait(500)
        end
    end)
end)

RegisterNetEvent('qbx_core:client:playerLoaded', function()
    loggedIn = true
    CreateThread(function()
        for _ = 1, 10 do
            if sendHud() then return end
            Wait(500)
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    refreshHud()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if type(QBX) == 'table' and type(QBX.PlayerData) == 'table' and type(job) == 'table' then
        QBX.PlayerData.job = job
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

AddEventHandler('qbx_core:client:playerLoggedOut', function()
    loggedIn = false
    hideHud()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        local timeout = GetGameTimer() + 15000
        while GetResourceState('qbx_core') ~= 'started' and GetGameTimer() < timeout do
            Wait(250)
        end

        -- Qbox may start before the character is selected. Wait for its
        -- PlayerData instead of sending a permanent zero/default payload.
        while GetGameTimer() < timeout do
            local data = getPlayerData()
            if data and (data.charinfo or data.money or data.job) then
                loggedIn = true
                sendHud(data)
                return
            end
            Wait(500)
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(1000)

        if IsPauseMenuActive() then
            if visible then hideHud() end
        elseif loggedIn then
            -- Low-frequency local refresh keeps health/armor/voice/ping current
            -- without polling the server or database.
            refreshHud()
        end
    end
end)
