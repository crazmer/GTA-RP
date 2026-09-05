local visible = false
local voiceMode = 2
local radioActive = false

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
    if not hunger and not thirst then return nil end
    if not hunger then return math.floor(clamp(thirst, 0, 100)) end
    if not thirst then return math.floor(clamp(hunger, 0, 100)) end
    return math.floor(math.min(clamp(hunger, 0, 100), clamp(thirst, 0, 100)))
end

local function voiceLabel()
    if voiceMode == 1 then return 'Whisper' end
    if voiceMode == 3 then return 'Shout' end
    return 'Normal'
end

local function sendHud(data)
    local playerData = data or QBX.PlayerData or {}
    local moneyData = playerData.money or {}
    local job = playerData.job or {}
    local grade = job.grade and (job.grade.name or job.grade.level) or 'Freelancer'
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
end

local function hideHud()
    SendNUIMessage({ action = 'hide' })
    visible = false
end

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    sendHud()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    sendHud()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    sendHud()
end)

RegisterNetEvent('qbx_core:client:playerLoaded', function()
    Wait(500)
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

AddEventHandler('qbx_core:client:playerLoggedOut', hideHud)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        local timeout = GetGameTimer() + 10000
        while GetResourceState('qbx_core') ~= 'started' and GetGameTimer() < timeout do
            Wait(250)
        end

        -- Send an initial payload even while character data is loading. This
        -- guarantees the NUI itself is visible and prevents a silent HUD.
        sendHud()
        Wait(1000)
        sendHud()
    end)
end)

CreateThread(function()
    while true do
        Wait(1000)

        if IsPauseMenuActive() then
            if visible then hideHud() end
        else
            if not visible then sendHud() else sendHud() end
        end
    end
end)
