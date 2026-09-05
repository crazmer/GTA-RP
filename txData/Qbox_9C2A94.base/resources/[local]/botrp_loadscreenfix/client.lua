local shutdownDone = false

local function shutdownLoadingScreen()
    if shutdownDone then return end
    if LocalPlayer.state.isLoggedIn ~= true then return end

    shutdownDone = true

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    CreateThread(function()
        Wait(100)
        if not IsScreenFadedIn() then
            DoScreenFadeIn(250)
        end
    end)
end

-- Qbox's normal post-spawn event.
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    shutdownLoadingScreen()
end)

-- Covers custom character resources that set the Qbox login state but finish
-- their own spawn flow outside qbx_core's built-in multicharacter UI.
AddStateBagChangeHandler('isLoggedIn', nil, function(bagName, _, value)
    if bagName ~= ('player:%s'):format(GetPlayerServerId(PlayerId())) then
        return
    end

    if value == true then
        CreateThread(function()
            Wait(250)
            shutdownLoadingScreen()
        end)
    else
        shutdownDone = false
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state.isLoggedIn == true then
            shutdownLoadingScreen()
            break
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)
