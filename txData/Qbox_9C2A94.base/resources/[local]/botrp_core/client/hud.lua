local visible = false
local voiceMode = 2
local radioActive = false

local function formatMoney(value)
    return ('$%s'):format(('%d'):format(math.floor(tonumber(value) or 0)))
end

local function clampPercent(value)
    return math.max(0, math.min(100, math.floor(tonumber(value) or 0)))
end

local function getHealthPercent(ped)
    if not DoesEntityExist(ped) then return 0 end
    local maxHealth = GetEntityMaxHealth(ped)
    local health = GetEntityHealth(ped)
    if maxHealth <= 100 then return 0 end
    return clampPercent(((health - 100) / (maxHealth - 100)) * 100)
end

local function getNeeds(data)
    local metadata = data.metadata or {}
    local hunger = tonumber(metadata.hunger)
    local thirst = tonumber(metadata.thirst)

    if not hunger and not thirst then return nil end
    if not hunger then return clampPercent(thirst) end
    if not thirst then return clampPercent(hunger) end

    return math.min(clampPercent(hunger), clampPercent(thirst))
end

local function getVoiceLabel()
    if voiceMode == 1 then return 'Whisper' end
    if voiceMode == 3 then return 'Shout' end
    return 'Normal'
end

local function isVoiceMuted()
    local ok, muted = pcall(MumbleIsPlayerMuted, PlayerId())
    return ok and muted == true
end

local function sendUpdate()
    local data = QBX.PlayerData
    if not data or not data.charinfo then return false end

    local money = data.money or {}
    local job = data.job or {}
    local ped = PlayerPedId()

    SendNUIMessage({
        action = 'update',
        enabled = true,
        cash = Config.hud.showCash and formatMoney(money.cash) or nil,
        bank = Config.hud.showBank and formatMoney(money.bank) or nil,
        job = Config.hud.showJob and (job.label or job.name or 'Unemployed') or nil,
        grade = Config.hud.showJob and ((job.grade and (job.grade.name or job.grade.level)) or '') or nil,
        health = Config.hud.showHealth and getHealthPercent(ped) or nil,
        armor = Config.hud.showArmor and clampPercent(GetPedArmour(ped)) or nil,
        needs = Config.hud.showNeeds and getNeeds(data) or nil,
        voice = Config.hud.showVoice and getVoiceLabel() or nil,
        voiceSpeaking = Config.hud.showVoice and NetworkIsPlayerTalking(PlayerId()) or false,
        radioActive = Config.hud.showVoice and radioActive or false,
        voiceMuted = Config.hud.showVoice and isVoiceMuted() or false,
        connection = Config.hud.showConnection and GetPlayerPing(PlayerId()) or nil,
        showCash = Config.hud.showCash,
        showBank = Config.hud.showBank,
        showJob = Config.hud.showJob,
        showHealth = Config.hud.showHealth,
        showArmor = Config.hud.showArmor,
        showNeeds = Config.hud.showNeeds,
        showVoice = Config.hud.showVoice,
        showConnection = Config.hud.showConnection,
        position = Config.hud.position,
        scale = Config.hud.scale,
        opacity = Config.hud.opacity,
    })

    return true
end

local function updateHud()
    if not Config.hud.enabled then return end

    if IsPauseMenuActive() then
        if visible then
            SendNUIMessage({ action = 'hide' })
            visible = false
        end
        return
    end

    if sendUpdate() then
        visible = true
    elseif visible then
        SendNUIMessage({ action = 'hide' })
        visible = false
    end
end

local function hideHud()
    if not visible then return end
    SendNUIMessage({ action = 'hide' })
    visible = false
end

RegisterNetEvent('QBCore:Client:OnMoneyChange', updateHud)
RegisterNetEvent('QBCore:Client:OnJobUpdate', updateHud)

RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
    voiceMode = tonumber(mode) or 2
    updateHud()
end)

RegisterNetEvent('pma-voice:radioActive', function(active)
    radioActive = active == true
    updateHud()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    updateHud()
end)

AddEventHandler('qbx_core:client:playerLoggedOut', hideHud)

CreateThread(function()
    while true do
        Wait(Config.hud.updateInterval or 750)
        updateHud()
    end
end)
