lib.versionCheck('Qbox-project/qbx_spawn')

lib.callback.register('qbx_spawn:server:getLastLocation', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then
        return nil, nil
    end

    local citizenid = player.PlayerData.citizenid
    local queryResult = MySQL.single.await('SELECT position FROM players WHERE citizenid = ?', { citizenid })
    local position = queryResult and queryResult.position and json.decode(queryResult.position) or nil
    local currentPropertyId = player.PlayerData.metadata.currentPropertyId

    -- Newly-created characters may not have a usable saved position yet.
    -- Returning nil lets the client omit the last-location entry and use the
    -- configured spawn points instead of trying to index a nil coordinate.
    if type(position) ~= 'table' or not position.x or not position.y or not position.z then
        position = nil
        currentPropertyId = nil
    end

    return position, currentPropertyId
end)

lib.callback.register('qbx_spawn:server:getProperties', function(source)
    if not GetResourceState('qbx_properties'):find('start') then
        return {}
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end

    local houseData = {}
    local properties = MySQL.query.await('SELECT id, property_name, coords FROM properties WHERE owner = ?', { player.PlayerData.citizenid }) or {}

    for i = 1, #properties do
        local coords = properties[i].coords and json.decode(properties[i].coords) or nil
        if type(coords) == 'table' and coords.x and coords.y and coords.z then
            houseData[#houseData + 1] = {
                label = properties[i].property_name,
                coords = coords,
                propertyId = properties[i].id,
            }
        end
    end

    return houseData
end)
