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

local function updateHud(force)
    if not Config.hud.enabled then return end

    local data = QBX.PlayerData
    if not data or not data.charinfo then
        if visible then
            SendNUIMessage({ action = 'hide' })
            visible = false
        end
        return
    end

    if IsPauseMenuActive() then
        if visible then
            SendNUIMessage({ action = 'hide' })
            visible = false
        end
        return
    end

    local money = data.money or {}
    local job = data.job or {}
    local ped = PlayerPedId()
    local healthValue = Config.hud.showHealth and getHealthPercent(ped) or nil
    local armorValue = Config.hud.showArmor and clampPercent(GetPedArmour(ped)) or nil
    local needsValue = Config.hud.showNeeds and getNeeds(data) or nil
    local pingValue = Config.hud.showConnection and GetPlayerPing(PlayerId()) or nil

    SendNUIMessage({
        action = 'update',
        enabled = true,
        cash = Config.hud.showCash and formatMoney(money.cash) or nil,
        bank = Config.hud.showBank and formatMoney(money.bank) or nil,
        job = Config.hud.showJob and (job.label or job.name or 'Unemployed') or nil,
        grade = Config.hud.showJob and ((job.grade and (job.grade.name or job.grade.level)) or '') or nil,
        health = healthValue,
        armor = armorValue,
        needs = needsValue,
        voice = Config.hud.showVoice and getVoiceLabel() or nil,
        voiceSpeaking = Config.hud.showVoice and NetworkIsPlayerTalking(PlayerId()) or false,
        radioActive = Config.hud.showVoice and radioActive or false,
        voiceMuted = Config.hud.showVoice and isVoiceMuted() or false,
        connection = pingValue,
    })

    visible = true
end

local function hideHud()
    if not visible then return end
    SendNUIMessage({ action = 'hide' })
    visible = false
end

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    updateHud(true)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    updateHud(true)
end)

RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
    voiceMode = tonumber(mode) or 2
    updateHud(true)
end)

RegisterNetEvent('pma-voice:radioActive', function(active)
    radioActive = active == true
    updateHud(true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    updateHud(true)
end)

AddEventHandler('qbx_core:client:playerLoggedOut', hideHud)

CreateThread(function()
    while true do
        Wait(Config.hud.updateInterval or 750)
        if QBX.PlayerData and QBX.PlayerData.charinfo then
            updateHud(false)
        elseif visible then
            hideHud()
        end
    end
end)
