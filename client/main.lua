local state = 'idle'
local pressedAt, ready

local function reset()
    if state == 'wheel' then
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'wheel', visible = false })
    elseif state == 'target' then
        AltTarget.stop()
    end
    state = 'idle'
end

local function canStart()
    return ready and not IsPauseMenuActive() and not IsNuiFocused() and AltRP.canAct()
end

RegisterCommand('+alt_rp', function()
    if state ~= 'idle' or not canStart() then return end
    pressedAt = GetGameTimer()
    state = 'pressed'
end, false)

RegisterCommand('-alt_rp', function()
    if state == 'pressed' and GetGameTimer() - pressedAt < Config.HoldMs and canStart() then
        state = 'wheel'
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'wheel', visible = true, actions = AltRP.wheel() })
    elseif state ~= 'wheel' then
        reset()
    end
end, false)

RegisterKeyMapping('+alt_rp', 'ALT · Roue RP / Ciblage', 'keyboard', Config.Key)

RegisterNUICallback('ready', function(_, cb)
    ready = true
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    if state == 'wheel' then reset() end
    cb({ ok = true })
end)

RegisterNUICallback('select', function(data, cb)
    local valid = state == 'wheel' and type(data) == 'table' and type(data.id) == 'string'
    if valid then
        reset()
        AltRP.select(data.id)
    end
    cb({ ok = valid })
end)

CreateThread(function()
    while true do
        if state == 'pressed' or state == 'target' or state == 'spent' then
            DisableControlAction(0, 19, true)
        end
        if state == 'pressed' or state == 'target' then
            if not canStart() then
                if state == 'target' then AltTarget.stop() end
                state = 'spent'
            elseif state == 'pressed' and GetGameTimer() - pressedAt >= Config.HoldMs then
                state = 'target'
                AltTarget.start()
            elseif state == 'target' and AltTarget.tick() then
                AltTarget.stop()
                state = 'spent'
            end
        elseif state == 'wheel' and (IsPauseMenuActive() or not AltRP.canAct()) then
            reset()
        end
        Wait(0)
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    reset()
    AltRP.cleanupAnimation()
    AltRP.restoreOutfit()
end)
