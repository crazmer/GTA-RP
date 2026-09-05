local config = require 'config.server'
local logger = require 'modules.logger'
local storage = require 'server.storage.main'
local starterItems = require 'config.shared'.starterItems

---@param license2 string
---@param license? string
local function getAllowedAmountOfCharacters(license2, license)
    return config.characters.playersNumberOfCharacters[license2] or license and config.characters.playersNumberOfCharacters[license] or config.characters.defaultNumberOfCharacters
end

local function giveStarterItems(source)
    if GetResourceState('ox_inventory') == 'missing' then return end
    while GetResourceState('ox_inventory') == 'starting' do
        Wait(100)
    end
    if GetResourceState('ox_inventory') ~= 'started' then return end
    local deadline = GetGameTimer() + 10000
    while not exports.ox_inventory:GetInventory(source) and GetGameTimer() < deadline do
        Wait(100)
    end
    if not exports.ox_inventory:GetInventory(source) then return end
    for i = 1, #starterItems do
        local item = starterItems[i]
        if item.metadata and type(item.metadata) == 'function' then
            exports.ox_inventory:AddItem(source, item.name, item.amount, item.metadata(source))
        else
            exports.ox_inventory:AddItem(source, item.name, item.amount, item.metadata)
        end
    end
end

local function giveStarterItemsAsync(source)
    CreateThread(function()
        local ok, err = pcall(giveStarterItems, source)
        if not ok then
            lib.print.warn(('Starter items failed for source %s: %s'):format(source, tostring(err)))
        end
    end)
end

lib.callback.register('qbx_core:server:getCharacters', function(source)
    local license2, license = GetPlayerIdentifierByType(source, 'license2'), GetPlayerIdentifierByType(source, 'license')
    storage.normalizeCids(license2, license)
    return storage.fetchAllPlayerEntities(license2, license), getAllowedAmountOfCharacters(license2, license)
end)

lib.callback.register('qbx_core:server:getPreviewPedData', function(_, citizenId)
    local ped = storage.fetchPlayerSkin(citizenId)
    if not ped then return end
    return ped.skin, ped.model and joaat(ped.model)
end)

lib.callback.register('qbx_core:server:loadCharacter', function(source, citizenId)
    local success = Login(source, citizenId)
    if not success then return end
    logger.log({
        source = 'qbx_core', webhook = config.logging.webhook['joinleave'], event = 'Loaded', color = 'green',
        message = ('**%s** (%s |  ||%s|| | %s | %s | %s) loaded'):format(GetPlayerName(source), GetPlayerIdentifierByType(source, 'discord') or 'undefined', GetPlayerIdentifierByType(source, 'ip') or 'undefined', GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license') or 'undefined', citizenId, source)
    })
    lib.print.info(('%s (Citizen ID: %s ID: %s) has successfully loaded!'):format(GetPlayerName(source), citizenId, source))
    return true
end)

local function sanitizeNewCharInfo(data)
    local MAX_TEXT = 50
    local MAX_BACKSTORY = 1000
    local function text(value, maxLength)
        if type(value) ~= 'string' then return nil end
        value = value:gsub('^%s+', ''):gsub('%s+$', '')
        if value == '' or #value > maxLength then return nil end
        return value
    end
    local firstname = text(data.firstname, MAX_TEXT)
    local lastname = text(data.lastname, MAX_TEXT)
    local nationality = text(data.nationality, MAX_TEXT)
    local birthdate = text(data.birthdate, MAX_TEXT)
    local gender = tonumber(data.gender)
    if not firstname or not lastname or not nationality or not birthdate or gender == nil then return nil end
    return { firstname = firstname, lastname = lastname, nationality = nationality, birthdate = birthdate, gender = math.floor(gender), backstory = text(data.backstory, MAX_BACKSTORY) or 'placeholder backstory' }
end

local function getNextCid(existingCharacters)
    local lastCharacter = existingCharacters[#existingCharacters]
    return (lastCharacter and lastCharacter.charinfo.cid or 0) + 1
end

lib.callback.register('qbx_core:server:createCharacter', function(source, data)
    if type(data) ~= 'table' then return end
    local license2, license = GetPlayerIdentifierByType(source, 'license2'), GetPlayerIdentifierByType(source, 'license')
    local existingCharacters = storage.fetchAllPlayerEntities(license2, license)
    if #existingCharacters >= getAllowedAmountOfCharacters(license2, license) then return end
    local charinfo = sanitizeNewCharInfo(data)
    if not charinfo then return end
    charinfo.cid = getNextCid(existingCharacters)
    local newData = { charinfo = charinfo }
    local success = Login(source, nil, newData)
    if not success then return end

    -- Login must be allowed to return immediately. Waiting for ox_inventory
    -- here can leave the NUI callback open indefinitely, which looks like a
    -- Create button that does nothing while game audio continues underneath.
    giveStarterItemsAsync(source)

    lib.print.info(('%s has created a character'):format(GetPlayerName(source)))
    return newData
end)

RegisterNetEvent('qbx_core:server:deleteCharacter', function(citizenId)
    local src = source
    DeleteCharacter(src --[[@as number]], citizenId)
    Notify(src, locale('success.character_deleted'), 'success')
end)
