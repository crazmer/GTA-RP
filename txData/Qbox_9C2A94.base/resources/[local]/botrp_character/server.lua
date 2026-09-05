local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

RegisterNetEvent('botrp_character:server:deleteCharacter', function(citizenid)
    local source = source
    if type(citizenid) ~= 'string' or citizenid == '' then return end

    local player = getPlayer(source)
    if player then
        -- Never allow a player to delete the character that is currently loaded.
        if player.PlayerData.citizenid == citizenid then
            return
        end
    end

    local ok = pcall(function()
        exports.qbx_core:DeleteCharacter(citizenid)
    end)

    if not ok then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'BotRP',
            description = 'Character could not be deleted.',
            type = 'error'
        })
    end
end)

lib.callback.register('botrp_character:server:getFoundationInfo', function(source)
    local player = getPlayer(source)
    if not player then return nil end

    local data = player.PlayerData
    return {
        citizenid = data.citizenid,
        userId = data.userId,
        name = data.charinfo and ('%s %s'):format(data.charinfo.firstname or '', data.charinfo.lastname or '') or GetPlayerName(source),
        job = data.job and data.job.name or 'unemployed',
        grade = data.job and data.job.grade and data.job.grade.level or 0,
    }
end)

AddEventHandler('playerDropped', function()
    -- Qbox remains the source of truth for persistence. This resource intentionally
    -- does not write directly to the players table.
end)
