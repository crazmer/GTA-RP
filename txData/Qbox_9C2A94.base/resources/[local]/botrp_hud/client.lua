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
    local max = GetEntityMaxHealth(ped)
    local current = GetEntityHealth(ped)
    if max <= 100 then return 0 end
    return math.floor(clamp(((current - 100) / (max - 100)) * 100, 0, 100))
end

local function getPlayerData()
    -- QBX globals are resource-local. Use the public qbx_core export so this
    -- resource remains isolated and can be shared/installed independently.
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

    -- Qbox publishes hunger/thirst through player statebags. Prefer those,
    -- then fall back to PlayerData metadata for compatibility.
    local hunger = state and tonumber(state.hunger) or tonumber(metadata.hunger)
    local thirst = state and tonumber(state.thirst) or tonumber(metadata.thirst)

    if hunger == nil then hunger = tonumber(metadata.hunger) end
    if thirst == nil then thirst = tonumber(metadata.thirst) end

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
    if type(playerData) ~= 'table' or next(playerData) == nil then return false end

    playerDataCache = playerData

    local moneyData = playerData.money or {}
    local job = playerData.job or {}
    local gradeData = type(job.grade) == 'table' and job.grade or {}
    local grade = gradeData.name or gradeData.level or job.grade_label or 'Freelancer'
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
    if not loggedIn then return false end
    return sendHud()
end

local function hideHud()
    SendNUIMessage({ action = 'hide' })
    visible = false
end

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if type(data) == 'table' then
        playerDataCache = data
    end
    loggedIn = true
    sendHud(data)
end)

RegisterNetEvent('qbx_core:client:onPlayerDataChanged', function(data)
    if type(data) == 'table' then
        playerDataCache = data
    end
    loggedIn = true
    refreshHud()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    loggedIn = true
    CreateThread(function()
        for _ = 1, 20 do
            if sendHud() then return end
            Wait(500)
        end
    end)
end)

RegisterNetEvent('qbx_core:client:playerLoaded', function()
    loggedIn = true
    CreateThread(function()
        for _ = 1, 20 do
            if sendHud() then return end
            Wait(500)
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    refreshHud()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if type(job) == 'table' then
        playerDataCache.job = job
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
    if loggedIn then refreshHud() else hideHud() end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    loggedIn = false
    playerDataCache = {}
    hideHud()
end)

AddEventHandler('qbx_core:client:playerLoggedOut', function()
    loggedIn = false
    playerDataCache = {}
    hideHud()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        local timeout = GetGameTimer() + 20000
        while GetResourceState('qbx_core') ~= 'started' and GetGameTimer() < timeout do
            Wait(250)
        end

        while GetGameTimer() < timeout do
            local data = getPlayerData()
            if data and (data.charinfo or data.money or data.job or data.metadata) then
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
            -- Only local/state data is refreshed here; there are no server or
            -- database polls. This keeps health, needs, voice and ping current.
            refreshHud()
        end
    end
end)
