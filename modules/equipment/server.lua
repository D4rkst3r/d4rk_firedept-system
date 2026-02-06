-- =============================================================================
-- EQUIPMENT MODULE - SERVER SIDE
-- =============================================================================

local playerInventories = {} -- { [source] = { currentTool = nil, tools = {} } }

-- =============================================================================
-- INIT
-- =============================================================================

Citizen.CreateThread(function()
    print("^2[Equipment Module - Server] Initializing...^0")
    print("^2[Equipment Module - Server] Ready!^0")
end)

-- =============================================================================
-- INVENTORY MANAGEMENT
-- =============================================================================

function GetPlayerInventory(source)
    --[[
        Holt/Erstellt Spieler-Inventar
    ]]

    if not playerInventories[source] then
        playerInventories[source] = {
            currentTool = nil, -- Aktuell gehaltenes Tool
            tools = {},        -- Verfügbare Tools { itemId = true }
            lastUsed = 0       -- Cooldown-Tracking
        }
    end

    return playerInventories[source]
end

function GiveEquipment(source, itemId)
    --[[
        Gibt Spieler ein Equipment-Item

        BEISPIEL:
        GiveEquipment(source, 'extinguisher_water')
    ]]

    return ErrorHandler.SafeCall(function()
        -- Validierung
        if not Config.Equipment.Items[itemId] then
            ErrorHandler.Warning('Equipment', 'Invalid item ID', { itemId = itemId })
            return false
        end

        local inventory = GetPlayerInventory(source)
        local item = Config.Equipment.Items[itemId]

        -- Check ob Spieler das Item schon hat
        if inventory.tools[itemId] then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 200, 0 },
                args = { "Equipment", "Du hast bereits: " .. item.name }
            })
            return false
        end

        -- Item hinzufügen
        inventory.tools[itemId] = true

        -- Client benachrichtigen
        TriggerClientEvent(Events.Equipment.Give, source, itemId)

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Equipment", "Erhalten: " .. item.name }
        })

        if Config.Equipment.Debug then
            print(string.format(
                "^2[Equipment] %s received: %s^0",
                GetPlayerName(source),
                item.name
            ))
        end

        return true
    end, function(err)
        ErrorHandler.Error('Equipment', 'Failed to give equipment', {
            source = source,
            itemId = itemId,
            error = err
        })
    end)
end

function RemoveEquipment(source, itemId)
    --[[
        Entfernt Equipment von Spieler
    ]]

    return ErrorHandler.SafeCall(function()
        local inventory = GetPlayerInventory(source)

        if not inventory.tools[itemId] then
            return false
        end

        -- Wenn aktuell gehalten, erst ablegen
        if inventory.currentTool == itemId then
            inventory.currentTool = nil
            TriggerClientEvent(Events.Equipment.Remove, source, itemId)
        end

        inventory.tools[itemId] = nil

        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 100, 0 },
            args = { "Equipment", "Entfernt: " .. Config.Equipment.Items[itemId].name }
        })

        return true
    end, function(err)
        ErrorHandler.Error('Equipment', 'Failed to remove equipment', { error = err })
    end)
end

function EquipTool(source, itemId)
    --[[
        Spieler nimmt Tool in die Hand
    ]]

    return ErrorHandler.SafeCall(function()
        local inventory = GetPlayerInventory(source)

        -- Check ob Spieler das Tool hat
        if not inventory.tools[itemId] then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                args = { "Equipment", "Du hast dieses Tool nicht!" }
            })
            return false
        end

        -- Altes Tool ablegen falls vorhanden
        if inventory.currentTool then
            TriggerClientEvent(Events.Equipment.Remove, source, inventory.currentTool)
        end

        -- Neues Tool equippen
        inventory.currentTool = itemId

        TriggerClientEvent(Events.Equipment.Use, source, itemId)

        if Config.Equipment.Debug then
            print(string.format(
                "^2[Equipment] %s equipped: %s^0",
                GetPlayerName(source),
                Config.Equipment.Items[itemId].name
            ))
        end

        return true
    end, function(err)
        ErrorHandler.Error('Equipment', 'Failed to equip tool', { error = err })
    end)
end

-- =============================================================================
-- EVENTS
-- =============================================================================

RegisterNetEvent(Events.Equipment.RequestGive)
AddEventHandler(Events.Equipment.RequestGive, function(itemId)
    GiveEquipment(source, itemId)
end)

RegisterNetEvent(Events.Equipment.RequestRemove)
AddEventHandler(Events.Equipment.RequestRemove, function(itemId)
    RemoveEquipment(source, itemId)
end)

RegisterNetEvent(Events.Equipment.RequestUse)
AddEventHandler(Events.Equipment.RequestUse, function(itemId)
    EquipTool(source, itemId)
end)

-- =============================================================================
-- PLAYER DISCONNECT CLEANUP
-- =============================================================================

AddEventHandler('playerDropped', function(reason)
    local source = source
    if playerInventories[source] then
        playerInventories[source] = nil
    end
end)

-- =============================================================================
-- ADMIN COMMANDS
-- =============================================================================

RegisterCommand('giveequip', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "System", "Keine Berechtigung!" }
        })
        return
    end

    --[[
        Usage: /giveequip [itemId]
        Beispiel: /giveequip extinguisher_water
    ]]

    local itemId = args[1]

    if not itemId then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            multiline = true,
            args = { "Equipment",
                "Verfügbare Items:\n" ..
                "- extinguisher_water (Wasser)\n" ..
                "- extinguisher_foam (Schaum)\n" ..
                "- extinguisher_co2 (CO2)\n" ..
                "- extinguisher_powder (Pulver)\n" ..
                "- fire_axe (Axt)"
            }
        })
        return
    end

    GiveEquipment(source, itemId)
end, false)

RegisterCommand('equiplist', function(source, args, rawCommand)
    local inventory = GetPlayerInventory(source)

    local count = 0
    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 200, 0 },
        args = { "Inventar", "Deine Equipment:" }
    })

    for itemId, _ in pairs(inventory.tools) do
        local item = Config.Equipment.Items[itemId]
        local equipped = inventory.currentTool == itemId and " [EQUIPPED]" or ""

        TriggerClientEvent('chat:addMessage', source, {
            color = { 200, 200, 200 },
            args = { "  ", item.name .. equipped }
        })
        count = count + 1
    end

    if count == 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 200, 200, 200 },
            args = { "  ", "Keine Items" }
        })
    end
end, false)

RegisterCommand('usetool', function(source, args, rawCommand)
    local itemId = args[1]

    if not itemId then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            args = { "Usage", "/usetool [itemId]" }
        })
        return
    end

    EquipTool(source, itemId)
end, false)
