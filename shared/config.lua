Config = {}

Config.CommandName = "eco"
Config.CommandHelp = "Ouvrir le panneau de gestion de l'économie"

Config.AuthorizedGroups = {
    ["owner"] = true,
    ["superadmin"] = true
}

Config.Accounts = {
    bank = "bank",
    money = "money",
    black_money = "black_money"
}

Config.RefreshCooldown = 10

Config.DefaultMaxFilter = 10000000
Config.StepFilter = 100000
