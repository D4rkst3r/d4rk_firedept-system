-- =============================================================================
-- EQUIPMENT MODULE - SERVER SIDE (WEAPON-BASED)
-- =============================================================================

-- Player Inventories
-- { [source] = { weapons = {itemId = true}, lastUsed = timestamp } }
local playerInventories = {}

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
        Holt oder erstellt Spieler-Inventar
    ]]

    if not playerInventories[source] then
        playerInventories[source] = {
            weapons = {}, -- ✅ RICHTIG!
            lastUsed = 0
        }
    end

    return playerInventories[source]
end

function GiveEquipment(source, itemId)
    if not Config.Equipment.Items[itemId] then
        if Config.Equipment.Debug then
            print(string.format("^1[Equipment] Invalid item: %s^0", tostring(itemId)))
        end
        return false
    end

    local inventory = GetPlayerInventory(source)

    -- ✅ FIX: inventory.weapons statt inventory.tools!
    if inventory.weapons[itemId] then
        if Config.Equipment.Debug then
            print(string.format("^3[Equipment] %s already has %s^0", GetPlayerName(source), itemId))
        end
        return false
    end

    -- ✅ FIX: inventory.weapons!
    inventory.weapons[itemId] = true

    -- Client benachrichtigen
    TriggerClientEvent(Events.Equipment.Give, source, itemId)

    if Config.Equipment.Debug then
        print(string.format("^2[Equipment] Given %s to %s^0", itemId, GetPlayerName(source)))
    end

    return true
end

function RemoveEquipment(source, itemId)
    --[[
        Entfernt Equipment von Spieler
    ]]

    local inventory = GetPlayerInventory(source)

    if not inventory.weapons[itemId] then
        if Config.Equipment.Debug then
            print(string.format(
                "^3[Equipment] Player %s doesn't have %s^0",
                GetPlayerName(source),
                itemId
            ))
        end
        return false
    end

    -- Item entfernen
    inventory.weapons[itemId] = nil

    -- Client benachrichtigen
    TriggerClientEvent(Events.Equipment.Remove, source, itemId)

    if Config.Equipment.Debug then
        print(string.format(
            "^3[Equipment] Removed %s from %s^0",
            itemId,
            GetPlayerName(source)
        ))
    end

    return true
end

function HasEquipment(source, itemId)
    --[[
        Check ob Spieler Equipment hat
    ]]

    local inventory = GetPlayerInventory(source)
    return inventory.weapons[itemId] == true
end

-- =============================================================================
-- EVENTS
-- =============================================================================

RegisterNetEvent(Events.Equipment.RequestGive)
AddEventHandler(Events.Equipment.RequestGive, function(itemId)
    -- Für später: Permission-Check
    -- Aktuell nur via Admin-Command
end)

RegisterNetEvent(Events.Equipment.RequestRemove)
AddEventHandler(Events.Equipment.RequestRemove, function(itemId)
    RemoveEquipment(source, itemId)
end)

-- =============================================================================
-- PLAYER DISCONNECT CLEANUP
-- =============================================================================

AddEventHandler('playerDropped', function(reason)
    local source = source

    if playerInventories[source] then
        -- Optional: Inventar in DB speichern
        -- Storage.SetPlayerData(source, 'equipment_inventory', playerInventories[source])

        playerInventories[source] = nil

        if Config.Equipment.Debug then
            print(string.format(
                "^3[Equipment] Cleaned inventory for %s (disconnected)^0",
                GetPlayerName(source)
            ))
        end
    end
end)

-- =============================================================================
-- ADMIN COMMANDS
-- =============================================================================

-- /giveequip [itemId] - Equipment geben
RegisterCommand('giveequip', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "System", "Keine Berechtigung!" }
        })
        return
    end

    local itemId = args[1]

    if not itemId then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 100, 0 },
            multiline = true,
            args = { "Usage", "/giveequip [itemId]\n\nAvailable:\n" ..
            "extinguisher_water\nextinguisher_foam\nextinguisher_co2\n" ..
            "extinguisher_powder\nfire_axe"
            }
        })
        return
    end

    if GiveEquipment(source, itemId) then
        local item = Config.Equipment.Items[itemId]
        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Equipment", "Erhalten: " .. item.name }
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "Equipment", "Invalid item or already owned!" }
        })
    end
end, false)

-- /equiplist - Inventar anzeigen
RegisterCommand('equiplist', function(source, args, rawCommand)
    local inventory = GetPlayerInventory(source)

    local count = 0
    for _, _ in pairs(inventory.weapons) do
        count = count + 1
    end

    if count == 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            args = { "Equipment", "Dein Inventar ist leer!" }
        })
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 200, 0 },
        args = { "Equipment", string.format("Dein Inventar (%d Items):", count) }
    })

    for itemId, _ in pairs(inventory.weapons) do
        local item = Config.Equipment.Items[itemId]

        if item and item.weapon then
            local weaponData = EquipmentWeapons[item.weapon]

            if weaponData then
                TriggerClientEvent('chat:addMessage', source, {
                    color = { 200, 200, 200 },
                    args = { "  ", string.format("- %s (Tint: %d)", weaponData.label, weaponData.tint or 0) }
                })
            end
        end
    end
end, false)

-- /removeequip [itemId] - Equipment entfernen
RegisterCommand('removeequip', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        return
    end

    local itemId = args[1]

    if not itemId then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 100, 0 },
            args = { "Usage", "/removeequip [itemId]" }
        })
        return
    end

    if RemoveEquipment(source, itemId) then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            args = { "Equipment", "Item entfernt!" }
        })
    end
end, false)

-- /clearequip - Alles entfernen
RegisterCommand('clearequip', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        return
    end

    local inventory = GetPlayerInventory(source)

    local count = 0
    for itemId, _ in pairs(inventory.weapons) do
        RemoveEquipment(source, itemId)
        count = count + 1
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 0, 255, 0 },
        args = { "Equipment", string.format("Inventar geleert! (%d Items entfernt)", count) }
    })
end, false)

-- =============================================================================
-- EXPORTS
-- =============================================================================

exports('GiveEquipment', GiveEquipment)
exports('RemoveEquipment', RemoveEquipment)
exports('HasEquipment', HasEquipment)
exports('GetPlayerInventory', GetPlayerInventory)

print("^2[Equipment Server] Loaded (Weapon-Based)^0")
