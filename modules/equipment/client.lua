-- =============================================================================
-- EQUIPMENT MODULE - CLIENT SIDE
-- =============================================================================

local playerInventory = {
    currentTool = nil,  -- Aktuell gehaltenes Tool
    tools = {},         -- Verfügbare Tools
    currentProp = nil,  -- Aktuelles Prop-Entity
    isAnimating = false -- Blockiert während Animation
}

-- =============================================================================
-- MODUL REGISTRIERUNG
-- =============================================================================

Citizen.CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(100)
    end

    RegisterModule('equipment', {
        enabled = Config.Equipment.Enabled,
        OnStart = StartEquipmentModule,
        OnStop = StopEquipmentModule
    })
end)

-- =============================================================================
-- MODUL START/STOP
-- =============================================================================

function StartEquipmentModule()
    print("^2[Equipment Module] Starting...^0")

    -- Events registrieren
    RegisterNetEvent(Events.Equipment.Give)
    AddEventHandler(Events.Equipment.Give, OnEquipmentGiven)

    RegisterNetEvent(Events.Equipment.Remove)
    AddEventHandler(Events.Equipment.Remove, OnEquipmentRemoved)

    RegisterNetEvent(Events.Equipment.Use)
    AddEventHandler(Events.Equipment.Use, OnEquipmentUsed)

    print("^2[Equipment Module] Started!^0")
end

function StopEquipmentModule()
    print("^3[Equipment Module] Stopping...^0")

    -- Cleanup: Prop entfernen
    if playerInventory.currentProp then
        RemoveProp()
    end

    playerInventory = {
        currentTool = nil,
        tools = {},
        currentProp = nil,
        isAnimating = false
    }
end

-- =============================================================================
-- EVENT HANDLERS
-- =============================================================================

function OnEquipmentGiven(itemId)
    --[[
        Server hat uns ein Item gegeben
    ]]

    if not Config.Equipment.Items[itemId] then
        print(string.format("^1[Equipment] ERROR: Received invalid item: %s^0", tostring(itemId)))
        return
    end

    playerInventory.tools[itemId] = true

    local item = Config.Equipment.Items[itemId]
    ClientUtils.Notify('success', "Erhalten: " .. item.name)

    if Config.Equipment.Debug then
        print(string.format("^2[Equipment] Received: %s^0", item.name))
    end
end

function OnEquipmentRemoved(itemId)
    --[[
        Server hat ein Item entfernt
    ]]

    -- Wenn gerade gehalten, ablegen
    if playerInventory.currentTool == itemId then
        RemoveProp()
        playerInventory.currentTool = nil
    end

    playerInventory.tools[itemId] = nil

    local item = Config.Equipment.Items[itemId]
    if item then
        ClientUtils.Notify('warning', "Entfernt: " .. item.name)
    end
end

function OnEquipmentUsed(itemId)
    --[[
        Server sagt: Equip dieses Tool!
    ]]

    if not Config.Equipment.Items[itemId] then
        print(string.format("^1[Equipment] ERROR: Cannot use invalid item: %s^0", tostring(itemId)))
        return
    end

    -- Altes Tool ablegen
    if playerInventory.currentTool then
        RemoveProp()
    end

    -- Neues Tool equippen
    playerInventory.currentTool = itemId
    SpawnProp(itemId)

    local item = Config.Equipment.Items[itemId]
    ClientUtils.Notify('info', "Equipped: " .. item.name)

    if Config.Equipment.Debug then
        print(string.format("^2[Equipment] Equipped: %s^0", item.name))
    end
end

-- =============================================================================
-- PROP MANAGEMENT
-- =============================================================================

function SpawnProp(itemId)
    --[[
        Spawnt Prop und attacht es an Spieler

        WARUM kompliziert?
        - Prop muss geladen werden (RequestModel)
        - Muss am richtigen Knochen befestigt werden
        - Position/Rotation muss stimmen
    ]]

    local item = Config.Equipment.Items[itemId]
    if not item then
        print(string.format("^1[Equipment] ERROR: Invalid item ID: %s^0", tostring(itemId)))
        return
    end

    local playerPed = PlayerPedId()

    -- =========================================================================
    -- PROP MODEL LADEN
    -- =========================================================================

    local propModel = item.propHash or GetHashKey(item.prop)

    RequestModel(propModel)
    local timeout = 0
    while not HasModelLoaded(propModel) do
        Citizen.Wait(10)
        timeout = timeout + 10

        -- Timeout nach 5 Sekunden
        if timeout > 5000 then
            print(string.format(
                "^1[Equipment] ERROR: Failed to load prop model: %s (timeout)^0",
                item.prop
            ))
            return
        end
    end

    -- =========================================================================
    -- PROP ERSTELLEN
    -- =========================================================================

    local coords = GetEntityCoords(playerPed)
    local prop = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, true)

    if not prop or prop == 0 then
        print(string.format("^1[Equipment] ERROR: Failed to create prop for: %s^0", item.name))
        SetModelAsNoLongerNeeded(propModel)
        return
    end

    -- =========================================================================
    -- PROP ATTACHEN
    -- =========================================================================

    --[[
        WICHTIG: AttachEntityToEntity Parameter

        1. entity1 = Das Prop
        2. entity2 = Der Spieler (Ped)
        3. boneIndex = Welcher Knochen? (28422 = Rechte Hand)
        4-6. xPos, yPos, zPos = Position-Offset
        7-9. xRot, yRot, zRot = Rotation
        10. p9 = Unknown (false)
        11. useSoftPinning = false
        12. collision = false (kein Collision)
        13. isPed = true
        14. vertexIndex = 0
        15. fixedRot = true (Rotation fixiert)
    ]]

    AttachEntityToEntity(
        prop,
        playerPed,
        GetPedBoneIndex(playerPed, item.bone),
        item.offset.x, item.offset.y, item.offset.z,
        item.rotation.x, item.rotation.y, item.rotation.z,
        false, false, false, true, 0, true
    )

    -- Prop-Handle speichern
    playerInventory.currentProp = prop

    -- Model kann jetzt freigegeben werden (Prop existiert bereits)
    SetModelAsNoLongerNeeded(propModel)

    if Config.Equipment.Debug then
        print(string.format(
            "^2[Equipment] Prop spawned and attached: %s (Entity: %d)^0",
            item.name,
            prop
        ))
    end
end

function RemoveProp()
    --[[
        Entfernt aktuelles Prop
    ]]

    if playerInventory.currentProp then
        local prop = playerInventory.currentProp

        -- Detach first (wichtig!)
        DetachEntity(prop, true, true)

        -- Delete
        DeleteEntity(prop)

        playerInventory.currentProp = nil

        if Config.Equipment.Debug then
            print("^3[Equipment] Prop removed^0")
        end
    end
end

-- =============================================================================
-- TOOL USAGE (Fire Extinguishing)
-- =============================================================================

function UseTool(fireId)
    --[[
        Benutzt aktuelles Tool zum Löschen

        FLOW:
        1. Check ob Tool equipped
        2. Check Cooldown
        3. Spiele Animation
        4. Sende an Server mit Tool-Info
    ]]

    -- Check ob Tool equipped
    if not playerInventory.currentTool then
        ClientUtils.Notify('error', 'Kein Tool equipped!')
        return false
    end

    -- Check ob gerade Animation läuft
    if playerInventory.isAnimating then
        return false
    end

    local item = Config.Equipment.Items[playerInventory.currentTool]
    if not item then
        print(string.format("^1[Equipment] ERROR: Invalid tool: %s^0", tostring(playerInventory.currentTool)))
        return false
    end

    -- Animation starten
    playerInventory.isAnimating = true

    ClientUtils.PlayAnimation(
        item.animDict,
        item.animName,
        item.animDuration,
        16 -- Flag: Cancelable
    )

    -- Sound abspielen (optional)
    PlaySoundFrontend(-1, "PICKUP_WEAPON_BALL", "HUD_FRONTEND_WEAPONS_PICKUPS_SOUNDSET", true)

    -- Nach Animation-Dauer: An Server senden
    Citizen.SetTimeout(item.animDuration, function()
        playerInventory.isAnimating = false

        -- An Server senden mit Tool-Type
        TriggerServerEvent(Events.Fire.AttemptExtinguish, fireId, playerInventory.currentTool)

        if Config.Equipment.Debug then
            print(string.format(
                "^2[Equipment] Used %s on fire #%d^0",
                item.name,
                fireId
            ))
        end
    end)

    return true
end

-- =============================================================================
-- KEY BINDINGS
-- =============================================================================

--[[
    KEY BINDINGS:
    - E = Feuer löschen (wenn nah genug)
    - Z = Tool-Menü öffnen (später)
    - X = Tool ablegen
]]

-- Tool ablegen
RegisterKeyMapping('fd_droptool', 'Equipment: Tool ablegen', 'keyboard', 'X')

RegisterCommand('fd_droptool', function()
    if playerInventory.currentTool then
        RemoveProp()

        local item = Config.Equipment.Items[playerInventory.currentTool]
        ClientUtils.Notify('info', item.name .. " abgelegt")

        playerInventory.currentTool = nil
    end
end, false)

-- =============================================================================
-- CLEANUP ON DEATH/ARREST/etc
-- =============================================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if IsModuleActive('equipment') then
            local playerPed = PlayerPedId()

            -- Check ob Spieler tot ist
            if IsEntityDead(playerPed) then
                if playerInventory.currentProp then
                    RemoveProp()
                    playerInventory.currentTool = nil
                end
            end

            -- Check ob Prop noch existiert
            if playerInventory.currentProp then
                if not DoesEntityExist(playerInventory.currentProp) then
                    -- Prop wurde irgendwie gelöscht, neu spawnen
                    if playerInventory.currentTool then
                        SpawnProp(playerInventory.currentTool)
                    end
                end
            end
        end
    end
end)

-- =============================================================================
-- EXPORTS (für Fire Module)
-- =============================================================================

function GetCurrentTool()
    return playerInventory.currentTool
end

function HasTool()
    return playerInventory.currentTool ~= nil
end

exports('GetCurrentTool', GetCurrentTool)
exports('HasTool', HasTool)



-- =============================================================================
-- INTERNAL EVENTS
-- =============================================================================

RegisterNetEvent('equipment:useTool')
AddEventHandler('equipment:useTool', function(fireId)
    UseTool(fireId)
end)
