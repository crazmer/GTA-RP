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

local function needs(data)
    local metadata = data.metadata or {}
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

local function update()
    if IsPauseMenuActive() then
        if visible then SendNUIMessage({ action = 'hide' }); visible = false end
        return
    end

    local data = QBX.PlayerData
    if not data or not data.charinfo then
        if visible then SendNUIMessage({ action = 'hide' }); visible = false end
        return
    end

    local job = data.job or {}
    local grade = job.grade and (job.grade.name or job.grade.level) or ''
    local metadata = data.metadata or {}
    local muted = false
    if MumbleIsPlayerMuted then
        local ok, result = pcall(MumbleIsPlayerMuted, PlayerId())
        muted = ok and result == true
    end

    SendNUIMessage({
        action = 'update',
        cash = money((data.money or {}).cash),
        bank = money((data.money or {}).bank),
        job = job.label or job.name or 'Civilian',
        grade = tostring(grade or 'Freelancer'),
        health = healthPercent(PlayerPedId()),
        armor = math.floor(clamp(GetPedArmour(PlayerPedId()), 0, 100)),
        needs = needs(data),
        voice = muted and 'Muted' or voiceLabel(),
        speaking = NetworkIsPlayerTalking(PlayerId()),
        radio = radioActive,
        ping = GetPlayerPing(PlayerId()),
    })
    visible = true
end

RegisterNetEvent('QBCore:Client:OnMoneyChange', update)
RegisterNetEvent('QBCore:Client:OnJobUpdate', update)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() Wait(1000); update() end)
RegisterNetEvent('pma-voice:setTalkingMode', function(mode) voiceMode = tonumber(mode) or 2; update() end)
RegisterNetEvent('pma-voice:radioActive', function(active) radioActive = active == true; update() end)
AddEventHandler('qbx_core:client:playerLoggedOut', function()
    SendNUIMessage({ action = 'hide' })
    visible = false
end)

CreateThread(function()
    while true do
        Wait(750)
        update()
    end
end)
