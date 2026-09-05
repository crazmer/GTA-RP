local function logEvent(message)
    lib.print.info(('[BotRP] %s'):format(message))
end

AddEventHandler('playerJoining', function()
    logEvent(('playerJoining source=%s'):format(source))
end)

AddEventHandler('playerDropped', function(reason)
    logEvent(('playerDropped source=%s reason=%s'):format(source, reason or 'unknown'))
end)
