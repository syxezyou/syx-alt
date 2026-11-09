AltTarget = {}

local ray, hitEntity, hitPosition, hitModel
local entity, options, selected
local lastSignature
local registered = {}

local doors = {
    { index = 0, label = 'Porte avant gauche' },
    { index = 1, label = 'Porte avant droite' },
    { index = 2, label = 'Porte arrière gauche' },
    { index = 3, label = 'Porte arrière droite' },
    { index = 4, label = 'Capot' },
    { index = 5, label = 'Coffre' }
}

local function toggleDoor(vehicle, index)
    CreateThread(function()
        local deadline = GetGameTimer() + 500
        while DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle)
            and not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
            NetworkRequestControlOfEntity(vehicle)
            Wait(0)
        end

        if not DoesEntityExist(vehicle) or not GetIsDoorValid(vehicle, index)
            or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle)) > Config.TargetDistance + 2.0 then
            return
        end
        if NetworkGetEntityIsNetworked(vehicle) and not NetworkHasControlOfEntity(vehicle) then
            AltRP.notify('Le véhicule est occupé ou hors de portée.')
            return
        end
        if GetVehicleDoorLockStatus(vehicle) > 1 then
            AltRP.notify('Ce véhicule est verrouillé.')
            return
        end

        if GetVehicleDoorAngleRatio(vehicle, index) > 0.1 then
            SetVehicleDoorShut(vehicle, index, false)
        else
            SetVehicleDoorOpen(vehicle, index, false, false)
        end
    end)
end

local function updateRay()
    if ray then
        local state, hit, position, _, target = GetShapeTestResult(ray)
        if state == 1 then return end
        ray = nil
        hitEntity, hitPosition, hitModel = nil, nil, nil
        if state == 2 and hit and target ~= 0 and DoesEntityExist(target) then
            hitEntity, hitPosition, hitModel = target, position, GetEntityModel(target)
        end
    end

    local origin = GetFinalRenderedCamCoord()
    local rotation = GetFinalRenderedCamRot(2)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local direction = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local destination = origin + direction * (Config.TargetDistance + 15.0)
    ray = StartShapeTestLosProbe(origin.x, origin.y, origin.z, destination.x, destination.y, destination.z,
        31, PlayerPedId(), 7)
end

local function getOptions(target)
    local available = {}
    if not target or not DoesEntityExist(target) or GetEntityModel(target) ~= hitModel then return available end

    local ped = PlayerPedId()
    local distance = #(GetEntityCoords(ped) - hitPosition)
    if distance > Config.TargetDistance then return available end

    local kind = GetEntityType(target)
    if kind == 2 then
        for _, door in ipairs(doors) do
            local index = door.index
            if GetIsDoorValid(target, index) and not IsVehicleDoorDamaged(target, index) then
                local isOpen = GetVehicleDoorAngleRatio(target, index) > 0.1
                available[#available + 1] = {
                    id = 'door:' .. index,
                    label = (isOpen and 'Fermer · ' or 'Ouvrir · ') .. door.label,
                    run = function(vehicle) toggleDoor(vehicle, index) end
                }
            end
        end
    elseif kind == 1 and not IsPedAPlayer(target) and not IsEntityDead(target) then
        available[1] = {
            id = 'greet', label = 'Saluer',
            run = function()
                AltRP.play('friends@frj@ig_1', 'wave_a', 1600)
            end
        }
    end

    for _, entry in ipairs(registered) do
        if (not entry.model or entry.model == hitModel) and (not entry.kind or entry.kind == kind)
            and distance <= entry.distance then
            available[#available + 1] = entry
        end
    end
    return available
end

local function render()
    local labels = {}
    for index, option in ipairs(options) do labels[index] = option.label end
    local signature = selected .. '|' .. table.concat(labels, '\n')
    if signature == lastSignature then return end
    lastSignature = signature
    SendNUIMessage({ type = 'target', visible = true, options = labels, selected = selected })
end

function AltTarget.start()
    hitEntity, hitPosition, hitModel = nil, nil, nil
    entity, options, selected = nil, {}, 1
    lastSignature = nil
    render()
end

function AltTarget.stop()
    SendNUIMessage({ type = 'target', visible = false })
end

function AltTarget.tick()
    updateRay()
    local previous = options[selected]
    options = getOptions(hitEntity)
    if entity ~= hitEntity or not previous or not options[selected] or options[selected].id ~= previous.id then
        entity, selected = hitEntity, 1
    end

    -- Laisser la caméra et le déplacement actifs, bloquer les commandes de combat.
    DisablePlayerFiring(PlayerId(), true)
    for _, control in ipairs({ 24, 25, 14, 15, 16, 17, 37, 44, 51, 140, 141, 142, 257 }) do
        DisableControlAction(0, control, true)
    end

    if #options > 0 then
        if IsDisabledControlJustPressed(0, 15) then selected = (selected - 2) % #options + 1 end
        if IsDisabledControlJustPressed(0, 14) then selected = selected % #options + 1 end
        if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 51) then
            local option = options[selected]
            option.run(entity)
            return true
        end
    end
    render()
    return false
end

exports('AddTargetOption', function(option)
    local owner = GetInvokingResource()
    if not owner or type(option) ~= 'table' or type(option.name) ~= 'string' or option.name == ''
        or type(option.label) ~= 'string' or option.label == '' or type(option.event) ~= 'string'
        or option.event == '' then
        return false
    end

    local model = type(option.model) == 'string' and joaat(option.model) or option.model
    if model ~= nil and type(model) ~= 'number' then return false end
    local kinds = { ped = 1, vehicle = 2, object = 3 }
    local kind = kinds[option.kind]
    if option.kind ~= nil and not kind then return false end

    local id = owner .. ':' .. option.name
    for _, entry in ipairs(registered) do
        if entry.id == id then return false end
    end

    local event = option.event
    registered[#registered + 1] = {
        id = id, owner = owner, label = option.label, model = model, kind = kind,
        distance = math.max(0.1, math.min(tonumber(option.distance) or Config.TargetDistance, Config.TargetDistance)),
        run = function(target) TriggerEvent(event, target) end
    }
    return true
end)

exports('RemoveTargetOption', function(name)
    local owner = GetInvokingResource()
    if not owner or type(name) ~= 'string' then return false end
    for index, entry in ipairs(registered) do
        if entry.id == owner .. ':' .. name then
            table.remove(registered, index)
            return true
        end
    end
    return false
end)

AddEventHandler('onClientResourceStop', function(resource)
    for index = #registered, 1, -1 do
        if registered[index].owner == resource then table.remove(registered, index) end
    end
end)
