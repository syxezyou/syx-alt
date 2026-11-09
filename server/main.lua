local supplies = {}
local nextUse = {}

RegisterNetEvent('alt_rp:consume', function(action)
    local player = source
    if type(action) ~= 'string' or Config.Supplies[action] == nil then return end

    local now = GetGameTimer()
    if now < (nextUse[player] or 0) then
        TriggerClientEvent('alt_rp:consumeResult', player, action, false, 'Attends la fin de ton action.')
        return
    end

    local stock = supplies[player] or {
        eat = Config.Supplies.eat,
        drink = Config.Supplies.drink
    }
    supplies[player] = stock

    if stock[action] <= 0 then
        nextUse[player] = now + 500
        TriggerClientEvent('alt_rp:consumeResult', player, action, false, 'Tes provisions sont épuisées.')
        return
    end

    stock[action] = stock[action] - 1
    nextUse[player] = now + 4500
    TriggerClientEvent('alt_rp:consumeResult', player, action, true,
        ('Provisions restantes : %d'):format(stock[action]))
end)

AddEventHandler('playerDropped', function()
    supplies[source] = nil
    nextUse[source] = nil
end)
