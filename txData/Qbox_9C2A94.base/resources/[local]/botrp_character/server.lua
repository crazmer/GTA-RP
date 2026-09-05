local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

-- Character persistence remains entirely owned by qbx_core. This resource
-- intentionally avoids direct database writes and only exposes read-only
-- foundation data for future BotRP systems.
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
    -- Qbox handles persistence and logout state.
end)
