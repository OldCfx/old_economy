local refreshCooldowns = {}

local webhook = ""

local function sendDiscordLog(title, fields, color)
    if not webhook or webhook == '' then return end

    local description = ""
    if type(fields) == "table" then
        for _, data in ipairs(fields) do
            description = description .. ("**%s :** %s\n"):format(data.key, data.value)
        end
    else
        description = fields
    end

    local embed = {
        {
            ["color"] = color or 5763719,
            ["title"] = title,
            ["description"] = description,
            ["footer"] = {
                ["text"] = os.date('%d/%m/%Y %H:%M:%S')
            }
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST',
        json.encode({ username = 'OldXBlunt', embeds = embed, avatar_url = 'https://i.goopics.net/sek245.png' }),
        { ['Content-Type'] = 'application/json' })
end



local function canAccess(xPlayer)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    return Config.AuthorizedGroups[group] == true
end

local function parseJsonAccounts(rawAccounts)
    if not rawAccounts then
        return {}
    end
    if type(rawAccounts) == "table" then
        return rawAccounts
    end
    local ok, parsed = pcall(json.decode, rawAccounts)
    if ok and parsed then
        return parsed
    end
    return {}
end

local function getEconomyData()
    local users = MySQL.query.await("SELECT identifier, firstname, lastname, accounts FROM users", {})
    local addonData = MySQL.query.await([[
        SELECT
            aad.account_name,
            aad.money,
            COALESCE(aa.label, aad.account_name) AS label
        FROM addon_account_data aad
        LEFT JOIN addon_account aa ON aad.account_name = aa.name
    ]], {})

    local totalBank = 0
    local totalMoney = 0
    local totalBlackMoney = 0
    local totalSocietyBank = 0

    local rankings = {}
    local onlinePlayers = {}
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in ipairs(xPlayers) do
        onlinePlayers[xPlayer.identifier] = xPlayer
    end

    local bankKey = Config.Accounts.bank
    local moneyKey = Config.Accounts.money
    local blackMoneyKey = Config.Accounts.black_money

    if users then
        for _, u in ipairs(users) do
            local xTarget = onlinePlayers[u.identifier]
            local bank = 0
            local money = 0
            local blackMoney = 0

            if xTarget then
                bank = xTarget.getAccount(bankKey) and xTarget.getAccount(bankKey).money or 0
                money = xTarget.getAccount(moneyKey) and xTarget.getAccount(moneyKey).money or 0
                blackMoney = xTarget.getAccount(blackMoneyKey) and xTarget.getAccount(blackMoneyKey).money or 0
            else
                local acc = parseJsonAccounts(u.accounts)
                bank = tonumber(acc[bankKey]) or 0
                money = tonumber(acc[moneyKey]) or 0
                blackMoney = tonumber(acc[blackMoneyKey]) or 0
            end

            totalBank = totalBank + bank
            totalMoney = totalMoney + money
            totalBlackMoney = totalBlackMoney + blackMoney

            local total = bank + money + blackMoney
            local playerName = (u.firstname and u.lastname) and (u.firstname .. " " .. u.lastname) or u.identifier

            local displayId = ""
            if xTarget then
                displayId = "ID: " .. tostring(xTarget.source)
            else
                local len = string.len(u.identifier or "")
                local lastFour = (len >= 4) and string.sub(u.identifier, -4) or u.identifier
                displayId = "..." .. lastFour
            end

            table.insert(rankings, {
                name = playerName,
                identifier = u.identifier,
                displayId = displayId,
                category = "player",
                type = "Joueur",
                bank = bank,
                money = money,
                blackMoney = blackMoney,
                total = total,
                isOnline = (xTarget ~= nil)
            })
        end
    end

    if addonData then
        for _, acc in ipairs(addonData) do
            local balance = tonumber(acc.money) or 0
            totalSocietyBank = totalSocietyBank + balance
            local societyLabel = (acc.label and acc.label ~= "") and acc.label or acc.account_name

            table.insert(rankings, {
                name = societyLabel,
                identifier = acc.account_name,
                displayId = "Société",
                category = "society",
                type = "Société",
                bank = balance,
                money = 0,
                blackMoney = 0,
                total = balance,
                isOnline = true
            })
        end
    end

    table.sort(rankings, function(a, b)
        return a.total > b.total
    end)

    local richest = rankings[1]
    local richestEntity = {
        name = richest and richest.name or "N/A",
        identifier = richest and richest.identifier or "N/A",
        displayId = richest and richest.displayId or "N/A",
        type = richest and richest.type or "N/A",
        totalWealth = richest and richest.total or 0
    }

    return {
        economy = {
            totalBank = totalBank,
            totalMoney = totalMoney,
            totalBlackMoney = totalBlackMoney,
            totalSocietyBank = totalSocietyBank,
            richestEntity = richestEntity
        },
        rankings = rankings
    }
end

local allowedGroupKeys = {}
for group, isAllowed in pairs(Config.AuthorizedGroups) do
    if isAllowed then
        table.insert(allowedGroupKeys, group)
    end
end

ESX.RegisterCommand(Config.CommandName, allowedGroupKeys, function(xPlayer, args, showError)
    if not canAccess(xPlayer) then
        xPlayer.showNotification("Vous n'avez pas l'autorisation d'accéder à ce menu.")
        return
    end

    local data = getEconomyData()
    TriggerClientEvent("old_economy:openUI", xPlayer.source, data)
end, false, { help = Config.CommandHelp })

RegisterNetEvent("old_economy:requestRefresh", function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not canAccess(xPlayer) then return end

    local now = os.time()
    local lastRefresh = refreshCooldowns[xPlayer.identifier] or 0
    local remaining = Config.RefreshCooldown - (now - lastRefresh)

    if remaining > 0 then
        xPlayer.showNotification(("Veuillez patienter %s seconde(s) avant d'actualiser."):format(remaining))
        TriggerClientEvent("old_economy:refreshDenied", src)
        return
    end

    refreshCooldowns[xPlayer.identifier] = now
    local data = getEconomyData()
    TriggerClientEvent("old_economy:updateUI", src, data)
    xPlayer.showNotification("~g~Données économiques actualisées avec succès.")
end)

RegisterNetEvent("old_economy:actionIndividual", function(data)
    local src = source
    local xAdmin = ESX.GetPlayerFromId(src)
    if not canAccess(xAdmin) then return end

    local action = data.action
    local targetType = data.targetType
    local identifier = data.identifier
    local rawAccount = data.account
    local amount = math.abs(tonumber(data.amount) or 0)
    local reason = tostring(data.reason or "Non spécifié")

    local actualAccount = Config.Accounts[rawAccount] or rawAccount

    if amount <= 0 then
        xAdmin.showNotification("~r~Le montant doit être supérieur à zéro.")
        return
    end

    sendDiscordLog("Action sur le compte", {
        { key = "STAFF",   value = GetPlayerName(xAdmin.source) .. " (" .. xAdmin.source .. ")" },
        { key = "Cible",   value = identifier },
        { key = "Compte",  value = targetType },
        { key = "Montant", value = amount .. " $" },
        { key = "Action",  value = action },
        { key = "Motif",   value = reason }
    }, 65280)

    if targetType == "society" then
        TriggerEvent("esx_addonaccount:getSharedAccount", identifier, function(acc)
            if acc then
                if action == "add" then
                    acc.addMoney(amount)
                elseif action == "remove" then
                    acc.removeMoney(amount)
                end
            else
                local row = MySQL.single.await("SELECT money FROM addon_account_data WHERE account_name = ?",
                    { identifier })
                if row then
                    local current = tonumber(row.money) or 0
                    local newBal = (action == "add") and (current + amount) or math.max(0, current - amount)
                    MySQL.update.await("UPDATE addon_account_data SET money = ? WHERE account_name = ?",
                        { newBal, identifier })
                end
            end
        end)
    else
        local xTarget = ESX.GetPlayerFromIdentifier(identifier)
        if xTarget then
            if action == "add" then
                xTarget.addAccountMoney(actualAccount, amount)
            elseif action == "remove" then
                xTarget.removeAccountMoney(actualAccount, amount)
            end
        else
            local row = MySQL.single.await("SELECT accounts FROM users WHERE identifier = ?", { identifier })
            if row then
                local accs = parseJsonAccounts(row.accounts)
                local current = tonumber(accs[actualAccount]) or 0
                local newBal = (action == "add") and (current + amount) or math.max(0, current - amount)
                accs[actualAccount] = newBal
                MySQL.update.await("UPDATE users SET accounts = ? WHERE identifier = ?",
                    { json.encode(accs), identifier })
            end
        end
    end

    xAdmin.showNotification(("~g~Opération réussie : %s %s $."):format(
        action == "add" and "Ajout de" or "Retrait de", amount))

    SetTimeout(350, function()
        local updatedData = getEconomyData()
        TriggerClientEvent("old_economy:updateUI", src, updatedData)
    end)
end)

RegisterNetEvent("old_economy:actionSector", function(data)
    local src = source
    local xAdmin = ESX.GetPlayerFromId(src)
    if not canAccess(xAdmin) then return end

    local pool = data.pool
    local operation = data.operation
    local mode = data.mode
    local value = tonumber(data.value) or 0
    local reason = tostring(data.reason or "Non spécifié")

    if value <= 0 then
        xAdmin.showNotification("~r~Valeur invalide pour la régulation.")
        return
    end

    sendDiscordLog("Action sur un TYPE", {
        { key = "STAFF",   value = GetPlayerName(xAdmin.source) .. " (" .. xAdmin.source .. ")" },
        { key = "Cible",   value = pool },
        { key = "Montant", value = value .. " $" },
        { key = "Action",  value = operation },
        { key = "Mode",    value = mode },
        { key = "Motif",   value = reason }
    }, 16705372)

    if pool == "totalSocietyBank" then
        local societies = MySQL.query.await("SELECT account_name, money FROM addon_account_data", {})
        if societies then
            for _, soc in ipairs(societies) do
                local current = tonumber(soc.money) or 0
                local delta = (mode == "percent") and math.floor((current * value) / 100) or value
                local newBal = (operation == "inject") and (current + delta) or math.max(0, current - delta)

                TriggerEvent("esx_addonaccount:getSharedAccount", soc.account_name, function(acc)
                    if acc then
                        acc.setMoney(newBal)
                    else
                        MySQL.update.await("UPDATE addon_account_data SET money = ? WHERE account_name = ?",
                            { newBal, soc.account_name })
                    end
                end)
            end
        end
    else
        local actualAccount = Config.Accounts.bank
        if pool == "totalMoney" then
            actualAccount = Config.Accounts.money
        elseif pool == "totalBlackMoney" then
            actualAccount = Config.Accounts.black_money
        end

        local xPlayers = ESX.GetExtendedPlayers()
        local onlineIds = {}
        for _, xP in ipairs(xPlayers) do
            onlineIds[xP.identifier] = true
            local current = xP.getAccount(actualAccount) and xP.getAccount(actualAccount).money or 0
            local delta = (mode == "percent") and math.floor((current * value) / 100) or value
            if operation == "inject" then
                xP.addAccountMoney(actualAccount, delta)
            else
                xP.removeAccountMoney(actualAccount, delta)
            end
        end

        local allUsers = MySQL.query.await("SELECT identifier, accounts FROM users", {})
        if allUsers then
            for _, u in ipairs(allUsers) do
                if not onlineIds[u.identifier] then
                    local accs = parseJsonAccounts(u.accounts)
                    local current = tonumber(accs[actualAccount]) or 0
                    local delta = (mode == "percent") and math.floor((current * value) / 100) or value
                    local newBal = (operation == "inject") and (current + delta) or math.max(0, current - delta)
                    accs[actualAccount] = newBal
                    MySQL.update.await("UPDATE users SET accounts = ? WHERE identifier = ?",
                        { json.encode(accs), u.identifier })
                end
            end
        end
    end

    xAdmin.showNotification("~g~Régulation appliquée avec succès.")

    SetTimeout(500, function()
        local updatedData = getEconomyData()
        TriggerClientEvent("old_economy:updateUI", src, updatedData)
    end)
end)
