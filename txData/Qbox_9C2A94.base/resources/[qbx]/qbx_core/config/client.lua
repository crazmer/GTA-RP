return {
    statusIntervalSeconds = 5, -- how often to check hunger/thirst status to remove health if 0.
    loadingModelsTimeout = 30000, -- Waiting time for ox_lib to load the models before throws an error, for low specs pc

    characters = {
        -- Use Qbox's built-in character manager for character selection and creation.
        useExternalCharacters = false,
        enableDeleteButton = true,
        startingApartment = true,

        dateFormat = 'YYYY-MM-DD',
        dateMin = '1900-01-01',
        dateMax = '2006-12-31',

        limitNationalities = true,

        profanityWords = {
            ['bad word'] = true
        },

        locations = {
            {
                pedCoords = vec4(969.25, 72.61, 116.18, 276.55),
                camCoords = vec4(972.2, 72.9, 116.68, 97.27),
            },
            {
                pedCoords = vec4(1104.49, 195.9, -49.44, 44.22),
                camCoords = vec4(1102.29, 198.14, -48.86, 225.07),
            },
            {
                pedCoords = vec4(-2163.87, 1134.51, -24.37, 310.05),
                camCoords = vec4(-2161.7, 1136.4, -23.77, 131.52),
            },
            {
                pedCoords = vec4(-996.71, -68.07, -99.0, 57.61),
                camCoords = vec4(-999.90, -66.30, -98.45, 241.68),
            },
            {
                pedCoords = vec4(-1023.45, -418.42, 67.66, 205.69),
                camCoords = vec4(-1021.8, -421.7, 68.14, 27.11),
            },
            {
                pedCoords = vec4(2265.27, 2925.02, -84.8, 267.77),
                camCoords = vec4(2268.24, 2925.02, -84.36, 90.88),
            },
            {
                pedCoords = vec4(-1004.5, -478.51, 50.03, 28.19),
                camCoords = vec4(-1006.36, -476.19, 50.50, 210.38),
            }
        },
    },

    discord = {
        enabled = true,
        richPresence = 'Players {currentPlayers}/{maxPlayers}',
        updateInterval = 15000,
        appId = '1024981890798731345',
        largeIcon = {
            icon = 'duck',
            text = 'Qbox Ducky',
        },
        smallIcon = {
            icon = 'logo_name',
            text = 'This is a small icon with text',
        },
        firstButton = {
            text = 'Qbox Discord',
            link = 'https://discord.gg/Z6Whda5hHA',
        },
        secondButton = {
            text = 'Main Website',
            link = 'https://www.qbox.re/',
        }
    },

    --- Only used by QB bridge
    hasKeys = function(plate, vehicle)
        return exports.qbx_vehiclekeys:HasKeys(plate)
    end,

    --- Only used by QB bridge
    giveKeys = function(plate, vehicle)
        return exports.qbx_vehiclekeys:GiveKeys(plate)
    end,

    teleport = {
        fadeDuration = 250,
        groundSearchStartZ = 1000.0,
        groundSearchMaxZ = 100.0,
        groundSearchStep = 50.0,
        loadSceneRadius = 50.0,
        timeout = 5000,
    },

    meCommand = {
        distance = 50.0,
        displayTime = 5000,
    },

    getVehiclesInRadius = {
        defaultRadius = 50.0,
    },

    setVehicleProperties = {
        waitInterval = 100,
        timeout = 5000,
    },

    pvp = true,
    motd = '',
}
