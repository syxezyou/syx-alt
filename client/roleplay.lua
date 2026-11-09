AltRP = {}
local outfits = {}
local outfitPed, outfitModel
local pending, busy, heldObject, currentAnim

local consumables = {
    eat = {
        dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger',
        model = `prop_cs_burger_01`, position = vector3(0.13, 0.05, 0.02), rotation = vector3(-50.0, 16.0, 60.0)
    },
    drink = {
        dict = 'amb@world_human_drinking@coffee@male@idle_a', clip = 'idle_c',
        model = `prop_ld_flow_bottle`, position = vector3(0.10, 0.03, 0.03), rotation = vector3(-80.0, 0.0, 0.0)
    }
}

local props = { hat = 0, glasses = 1 }
local components = { pants = 4, shoes = 6 }
local clothing = {
    { id = 'top', label = 'Haut', icon = 'shirt' },
    { id = 'pants', label = 'Pantalon', icon = 'pants' },
    { id = 'shoes', label = 'Chaussures', icon = 'shoe' },
    { id = 'hat', label = 'Chapeau', icon = 'hat' },
    { id = 'glasses', label = 'Lunettes', icon = 'glasses' }
}

function AltRP.notify(message)
    SendNUIMessage({ type = 'notice', message = message })
end

function AltRP.canAct()
    local ped = PlayerPedId()
    return not busy and not pending and not IsEntityDead(ped)
        and not IsPedInAnyVehicle(ped, true) and not IsPedRagdoll(ped)
        and not IsPedSwimming(ped) and not IsPedFalling(ped) and not IsPedClimbing(ped)
end

local function syncOutfit(ped)
    local model = GetEntityModel(ped)
    if ped ~= outfitPed or model ~= outfitModel then
        outfits = {}
        outfitPed, outfitModel = ped, model
    end
    return Config.Undress[model]
end

local function getComponent(ped, slot)
    return {
        drawable = GetPedDrawableVariation(ped, slot),
        texture = GetPedTextureVariation(ped, slot),
        palette = GetPedPaletteVariation(ped, slot)
    }
end

local function matches(ped, slot, value)
    return GetPedDrawableVariation(ped, slot) == value.drawable
        and GetPedTextureVariation(ped, slot) == value.texture
        and GetPedPaletteVariation(ped, slot) == value.palette
end

local function savedOutfit(ped, action)
    local saved = outfits[action]
    if not saved then return end

    local prop = props[action]
    if prop ~= nil then
        if GetPedPropIndex(ped, prop) == -1 then return saved end
    else
        for slot, value in pairs(saved.removed) do
            if not matches(ped, slot, value) then
                outfits[action] = nil
                return
            end
        end
        return saved
    end

    outfits[action] = nil
end

function AltRP.wheel()
    local ped = PlayerPedId()
    local preset = syncOutfit(ped)
    local actions = {}
    for _, item in ipairs(clothing) do
        local prop = props[item.id]
        local saved = savedOutfit(ped, item.id)
        local enabled = preset ~= nil
        if prop ~= nil then
            enabled = saved ~= nil or GetPedPropIndex(ped, prop) >= 0
        end
        actions[#actions + 1] = {
            id = item.id, icon = item.icon, label = item.label, disabled = not enabled,
            detail = saved and 'Remettre' or 'Retirer'
        }
    end
    actions[#actions + 1] = { id = 'eat', label = 'Manger', icon = 'food', detail = 'Provisions' }
    actions[#actions + 1] = { id = 'drink', label = 'Boire', icon = 'water', detail = 'Provisions' }
    return actions
end

local function changeClothes(ped, action)
    local preset = syncOutfit(ped)
    local saved = savedOutfit(ped, action)
    local prop = props[action]
    if prop ~= nil then
        if saved then
            SetPedPropIndex(ped, prop, saved.drawable, saved.texture, true)
            outfits[action] = nil
        else
            local drawable = GetPedPropIndex(ped, prop)
            if drawable < 0 then return end
            outfits[action] = { drawable = drawable, texture = GetPedPropTextureIndex(ped, prop) }
            ClearPedProp(ped, prop)
        end
        return
    end

    if not preset then return end
    local slots = action == 'top' and preset.top or { [components[action]] = preset[action] }
    if saved then
        for slot, value in pairs(saved.original) do
            SetPedComponentVariation(ped, slot, value.drawable, value.texture, value.palette)
        end
        outfits[action] = nil
        return
    end

    local original, removed = {}, {}
    local alreadyRemoved = true
    for slot, drawable in pairs(slots) do
        if not IsPedComponentVariationValid(ped, slot, drawable, 0) then
            AltRP.notify('Ce vêtement ne peut pas être retiré avec cette tenue.')
            return
        end
        original[slot] = getComponent(ped, slot)
        removed[slot] = { drawable = drawable, texture = 0, palette = 0 }
        alreadyRemoved = alreadyRemoved and matches(ped, slot, removed[slot])
    end
    if alreadyRemoved then return end

    for slot, value in pairs(removed) do
        SetPedComponentVariation(ped, slot, value.drawable, value.texture, value.palette)
    end
    outfits[action] = { original = original, removed = removed }
end

function AltRP.restoreOutfit()
    local ped = PlayerPedId()
    syncOutfit(ped)
    for _, item in ipairs(clothing) do
        if savedOutfit(ped, item.id) then changeClothes(ped, item.id) end
    end
end

function AltRP.play(dict, clip, duration, item, onPlay)
    if not AltRP.canAct() then return end
    local ped = PlayerPedId()
    busy = true
    CreateThread(function()
        RequestAnimDict(dict)
        if item then RequestModel(item.model) end
        local deadline = GetGameTimer() + 1800
        while GetGameTimer() < deadline
            and (not HasAnimDictLoaded(dict) or (item and not HasModelLoaded(item.model))) do
            Wait(0)
        end

        if ped == PlayerPedId() and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, true) then
            if item and HasModelLoaded(item.model) then
                local position = GetEntityCoords(ped)
                heldObject = CreateObjectNoOffset(item.model, position.x, position.y, position.z, false, false, false)
                if heldObject ~= 0 then
                    SetEntityCollision(heldObject, false, false)
                    AttachEntityToEntity(heldObject, ped, GetPedBoneIndex(ped, 57005),
                        item.position.x, item.position.y, item.position.z,
                        item.rotation.x, item.rotation.y, item.rotation.z, false, false, false, true, 2, true)
                end
            end
            if HasAnimDictLoaded(dict) then
                currentAnim = { ped = ped, dict = dict, clip = clip }
                TaskPlayAnim(ped, dict, clip, 4.0, -4.0, duration, 49, 0.0, false, false, false)
            end
            if onPlay then onPlay(ped) end

            local finish = GetGameTimer() + duration
            while GetGameTimer() < finish and ped == PlayerPedId() and not IsEntityDead(ped)
                and not IsPedInAnyVehicle(ped, true) and not IsPedRagdoll(ped) do
                Wait(50)
            end
        end

        AltRP.cleanupAnimation()
        RemoveAnimDict(dict)
        if item then SetModelAsNoLongerNeeded(item.model) end
        busy = false
    end)
end

function AltRP.cleanupAnimation()
    if heldObject and heldObject ~= 0 then DeleteEntity(heldObject) end
    heldObject = nil
    if currentAnim and DoesEntityExist(currentAnim.ped) then
        StopAnimTask(currentAnim.ped, currentAnim.dict, currentAnim.clip, 2.0)
    end
    currentAnim = nil
end

function AltRP.select(action)
    if not AltRP.canAct() then return end
    if consumables[action] then
        local request = { action = action }
        pending = request
        TriggerServerEvent('alt_rp:consume', action)
        SetTimeout(2500, function()
            if pending == request then
                pending = nil
                AltRP.notify('Le serveur ne répond pas.')
            end
        end)
        return
    end
    for _, item in ipairs(clothing) do
        if item.id == action then
            AltRP.play('clothingtie', 'try_tie_positive_a', 950, nil, function(ped)
                changeClothes(ped, action)
            end)
            return
        end
    end
end

RegisterNetEvent('alt_rp:consumeResult', function(action, accepted, message)
    if source ~= 65535 or not pending or pending.action ~= action then return end
    pending = nil
    if accepted and AltRP.canAct() then
        local item = consumables[action]
        AltRP.play(item.dict, item.clip, 3100, item)
    end
    AltRP.notify(message)
end)
