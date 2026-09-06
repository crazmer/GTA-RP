local function clean(value)
    if value == nil then return nil end
    value = tostring(value)
    if value == '' then return nil end
    return value
end

local function buildIdentity(player)
    if not player or type(player.PlayerData) ~= 'table' then return nil end

    local data = player.PlayerData
    if not data.citizenid then return nil end

    local charinfo = data.charinfo or {}
    local job = data.job or {}
    local grade = job.grade or {}
    local gang = data.gang or {}
    local gangGrade = gang.grade or {}
    local money = data.money or {}

    return {
        citizenid = clean(data.citizenid),
        userId = tonumber(data.userId) or nil,
        license = clean(data.license),
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

lib.callback.register('botrp_core:server:getIdentity', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and buildIdentity(player) or nil
end)

exports('GetIdentity', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and buildIdentity(player) or nil
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not player then return end
    local identity = buildIdentity(player)
    TriggerClientEvent('botrp_core:client:identityServerReady', player.PlayerData.source, identity)
end)
