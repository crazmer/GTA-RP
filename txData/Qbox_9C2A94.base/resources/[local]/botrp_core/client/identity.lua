local identity = nil
local generation = 0

local function clean(value)
    if value == nil then return nil end
    value = tostring(value)
    if value == '' then return nil end
    return value
end

local function buildIdentity(data)
    if type(data) ~= 'table' or not data.citizenid then
        return nil
    end

    local charinfo = data.charinfo or {}
    local job = data.job or {}
    local grade = job.grade or {}
    local gang = data.gang or {}
    local gangGrade = gang.grade or {}
    local money = data.money or {}

    generation += 1

    return {
        generation = generation,
        citizenid = clean(data.citizenid),
        userId = tonumber(data.userId) or nil,
        name = clean(data.name) or clean(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')),
        firstname = clean(charinfo.firstname),
        lastname = clean(charinfo.lastname),
        birthdate = clean(charinfo.birthdate),
        gender = tonumber(charinfo.gender),
        nationality = clean(charinfo.nationality),
        phone = clean(charinfo.phone),
        account = clean(charinfo.account),
        job = {
            name = clean(job.name),
            label = clean(job.label),
            grade = tonumber(grade.level) or 0,
            gradeName = clean(grade.name),
            onduty = job.onduty == true,
            type = clean(job.type),
            payment = tonumber(job.payment) or 0,
            isBoss = job.isboss == true,
            bankAuth = job.bankAuth == true,
        },
        gang = {
            name = clean(gang.name),
            label = clean(gang.label),
            grade = tonumber(gangGrade.level) or 0,
            gradeName = clean(gangGrade.name),
            isBoss = gang.isboss == true,
        },
        money = {
            cash = tonumber(money.cash) or 0,
            bank = tonumber(money.bank) or 0,
            crypto = tonumber(money.crypto) or 0,
        },
    }
end

local function publishIdentity(reason, suppliedIdentity)
    identity = suppliedIdentity or buildIdentity(QBX.PlayerData)

    TriggerEvent('botrp_core:client:identityUpdated', identity, reason)
    if identity then
        TriggerEvent('BotRP:PlayerIdentityUpdated', identity, reason)
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(0)
    publishIdentity('loaded')

    local serverIdentity = lib.callback.await('botrp_core:server:getIdentity', false)
    if serverIdentity and identity and serverIdentity.citizenid == identity.citizenid then
        identity = serverIdentity
        TriggerEvent('botrp_core:client:identityUpdated', identity, 'serverVerified')
        TriggerEvent('BotRP:PlayerIdentityUpdated', identity, 'serverVerified')
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if type(data) == 'table' then
        QBX.PlayerData = data
    end
    if QBX.IsLoggedIn then
        publishIdentity('playerData')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    identity = nil
    generation += 1
    TriggerEvent('botrp_core:client:identityUpdated', nil, 'unloaded')
    TriggerEvent('BotRP:PlayerIdentityUpdated', nil, 'unloaded')
end)

exports('GetIdentity', function()
    return identity
end)

exports('IsCharacterLoaded', function()
    return identity ~= nil and QBX.IsLoggedIn == true
end)

exports('GetCitizenId', function()
    return identity and identity.citizenid or nil
end)

exports('GetCharacterName', function()
    return identity and identity.name or nil
end)

CreateThread(function()
    while GetResourceState('qbx_core') ~= 'started' do Wait(250) end
    if QBX.IsLoggedIn then
        publishIdentity('resourceStart')
    end
end)
