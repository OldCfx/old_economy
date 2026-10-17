local isMenuOpen = false

local function toggleUI(state)
    isMenuOpen = state
    SetNuiFocus(state, state)
    if not state then
        SendNUIMessage({ action = "close" })
    end
end

RegisterNetEvent("old_economy:openUI", function(data)
    toggleUI(true)
    SendNUIMessage({
        action = "open",
        data = data
    })
end)

RegisterNetEvent("old_economy:updateUI", function(data)
    SendNUIMessage({
        action = "update",
        data = data
    })
end)

RegisterNetEvent("old_economy:refreshDenied", function()
    SendNUIMessage({
        action = "refreshDenied"
    })
end)

RegisterNUICallback("close", function(_, cb)
    toggleUI(false)
    cb({ ok = true })
end)

RegisterNUICallback("refreshData", function(_, cb)
    TriggerServerEvent("old_economy:requestRefresh")
    cb({ ok = true })
end)

RegisterNUICallback("actionIndividual", function(data, cb)
    TriggerServerEvent("old_economy:actionIndividual", data)
    cb({ ok = true })
end)

RegisterNUICallback("actionSector", function(data, cb)
    TriggerServerEvent("old_economy:actionSector", data)
    cb({ ok = true })
end)
