local visible = false

local function formatMoney(value)
    return ('$%s'):format(('%d'):format(math.floor(tonumber(value) or 0)))
end

local function updateHud()
    if not Config.hud.enabled then return end

    local data = QBX.PlayerData
    if not data or not data.charinfo then return end

    local money = data.money or {}
    local job = data.job or {}

    SendNUIMessage({
        action = 'update',
        visible = true,
        cash = Config.hud.showCash and formatMoney(money.cash) or nil,
        bank = Config.hud.showBank and formatMoney(money.bank) or nil,
        job = Config.hud.showJob and (job.label or job.name or 'Unemployed') or nil,
        grade = Config.hud.showJob and ((job.grade and (job.grade.name or job.grade.level)) or '') or nil,
    })

    visible = true
end

local function hideHud()
    if not visible then return end
    SendNUIMessage({ action = 'hide' })
    visible = false
end

RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    updateHud()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    updateHud()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    updateHud()
end)

AddEventHandler('qbx_core:client:playerLoggedOut', hideHud)

CreateThread(function()
    while true do
        Wait(1500)
        if visible then
            updateHud()
        end
    end
end)
