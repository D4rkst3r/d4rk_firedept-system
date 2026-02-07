-- =============================================================================
-- EQUIPMENT MODULE - CLIENT SIDE (WEAPON-BASED WITH TINTS)
-- =============================================================================

local playerInventory = {
    weapons = {} -- { [weaponHash] = itemId }
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

    print("^2[Equipment Module] Started!^0")
end

function StopEquipmentModule()
    print("^3[Equipment Module] Stopping...^0")

    -- Cleanup: Alle Weapons entfernen
    local playerPed = PlayerPedId()
    for weaponHash, _ in pairs(playerInventory.weapons) do
        RemoveWeaponFromPed(playerPed, weaponHash)
    end

    playerInventory.weapons = {}
end

-- =============================================================================
-- EVENT HANDLERS
-- =============================================================================

function OnEquipmentGiven(itemId)
    --[[
        Server hat uns ein Weapon gegeben
    ]]

    if not Config.Equipment.Items[itemId] then
        print(string.format("^1[Equipment] ERROR: Invalid item: %s^0", tostring(itemId)))
        return
    end

    local item = Config.Equipment.Items[itemId]
    local weaponData = EquipmentWeapons[item.weapon]

    if not weaponData then
        print(string.format("^1[Equipment] ERROR: Invalid weapon: %s^0", tostring(item.weapon)))
        return
    end

    local playerPed = PlayerPedId()

    -- ✅ WEAPON GEBEN
    GiveWeaponToPed(
        playerPed,
        weaponData.hash,
        weaponData.ammo or 100,
        false, -- Hidden
        true   -- Equip now
    )

    -- ✅ TINT SETZEN (um verschiedene Typen zu unterscheiden)
    if weaponData.tint then
        SetPedWeaponTintIndex(playerPed, weaponData.hash, weaponData.tint)

        if Config.Equipment.Debug then
            print(string.format("^2[Equipment] Set tint %d for %s^0", weaponData.tint, weaponData.label))
        end
    end

    -- Merken dass wir diese Waffe haben (mit itemId, nicht Hash!)
    -- WICHTIG: Mehrere Items können gleiche Weapon haben (unterschiedliche Tints)
    playerInventory.weapons[weaponData.hash] = itemId

    ClientUtils.Notify('success', "Erhalten: " .. weaponData.label)

    if Config.Equipment.Debug then
        print(string.format("^2[Equipment] Given weapon: %s (Hash: %s, Tint: %s)^0",
            weaponData.label,
            weaponData.hash,
            tostring(weaponData.tint)
        ))
    end
end

function OnEquipmentRemoved(itemId)
    --[[
        Server hat Weapon entfernt
    ]]

    local item = Config.Equipment.Items[itemId]
    if not item then return end

    local weaponData = EquipmentWeapons[item.weapon]
    if not weaponData then return end

    local playerPed = PlayerPedId()

    -- ✅ WEAPON ENTFERNEN
    RemoveWeaponFromPed(playerPed, weaponData.hash)

    -- Aus Inventar entfernen
    playerInventory.weapons[weaponData.hash] = nil

    ClientUtils.Notify('warning', "Entfernt: " .. weaponData.label)
end

-- =============================================================================
-- TOOL USAGE (Fire Extinguishing)
-- =============================================================================

function UseTool(fireId)
    --[[
        Benutzt aktuelles Weapon zum Löschen
        GTA V handled Animation automatisch!
    ]]

    local playerPed = PlayerPedId()

    -- ✅ CHECK WELCHE WEAPON EQUIPPED
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    -- Check ob es ein Equipment-Weapon ist
    local itemId = playerInventory.weapons[currentWeapon]

    if not itemId then
        ClientUtils.Notify('error', 'Kein Tool equipped! (Waffenrad öffnen mit TAB)')
        return false
    end

    local item = Config.Equipment.Items[itemId]
    local weaponData = EquipmentWeapons[item.weapon]

    -- Sound abspielen
    PlaySoundFrontend(-1, "PICKUP_WEAPON_BALL", "HUD_FRONTEND_WEAPONS_PICKUPS_SOUNDSET", true)

    -- An Server senden
    TriggerServerEvent(Events.Fire.AttemptExtinguish, fireId, itemId)

    ClientUtils.Notify('info', string.format("Benutze %s...", weaponData.label))

    if Config.Equipment.Debug then
        print(string.format(
            "^2[Equipment] Used %s on fire #%d^0",
            weaponData.label,
            fireId
        ))
    end

    return true
end

-- =============================================================================
-- HELPERS
-- =============================================================================

function GetCurrentTool()
    --[[
        Gibt aktuelles Equipment zurück (für Fire Module)
    ]]

    local playerPed = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    return playerInventory.weapons[currentWeapon]
end

function HasTool()
    --[[
        Check ob irgendein Equipment equipped
    ]]

    local playerPed = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    return playerInventory.weapons[currentWeapon] ~= nil
end

function GetInventory()
    --[[
        Gibt komplettes Inventar zurück
        Für UI/Menu später
    ]]

    local inventory = {}

    for weaponHash, itemId in pairs(playerInventory.weapons) do
        local item = Config.Equipment.Items[itemId]
        local weaponData = EquipmentWeapons[item.weapon]

        table.insert(inventory, {
            itemId = itemId,
            weaponHash = weaponHash,
            weaponData = weaponData,
            ammo = GetAmmoInPedWeapon(PlayerPedId(), weaponHash)
        })
    end

    return inventory
end

-- =============================================================================
-- INTERNAL EVENTS
-- =============================================================================

RegisterNetEvent('equipment:useTool')
AddEventHandler('equipment:useTool', function(fireId)
    UseTool(fireId)
end)

-- =============================================================================
-- COMMANDS (für Testing)
-- =============================================================================

RegisterCommand('equipinfo', function()
    local playerPed = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    print("^3========== EQUIPMENT INFO ==========^0")
    print(string.format("^3Current Weapon Hash: %s^0", currentWeapon))

    local itemId = playerInventory.weapons[currentWeapon]
    if itemId then
        local item = Config.Equipment.Items[itemId]
        local weaponData = EquipmentWeapons[item.weapon]

        print(string.format("^2Equipped: %s^0", weaponData.label))
        print(string.format("^2Tint: %s^0", weaponData.tint))
        print(string.format("^2Ammo: %d / %d^0",
            GetAmmoInPedWeapon(playerPed, currentWeapon),
            weaponData.ammo
        ))
        print("^2Effectiveness:^0")
        for class, eff in pairs(weaponData.effectiveness) do
            print(string.format("  ^3%s: %.1f%%^0", class, eff * 100))
        end
    else
        print("^1No equipment weapon equipped^0")
    end

    print("^3Inventory:^0")
    for weaponHash, id in pairs(playerInventory.weapons) do
        local i = Config.Equipment.Items[id]
        local w = EquipmentWeapons[i.weapon]
        print(string.format("  ^2%s (Hash: %s, Tint: %d)^0", w.label, weaponHash, w.tint))
    end

    print("^3=====================================^0")
end, false)


-- =============================================================================
-- DEBUG/TEST COMMANDS
-- =============================================================================

if Config.Equipment.Debug then
    -- Test-Command: Weapon direkt geben
    RegisterCommand('testweapon', function(source, args, rawCommand)
        local weaponName = args[1] or 'WEAPON_EXTINGUISHER_WATER'
        local weaponHash = GetHashKey(weaponName)

        local playerPed = PlayerPedId()

        -- Weapon geben
        GiveWeaponToPed(playerPed, weaponHash, 100, false, true)

        print(string.format("^2[Equipment Test] Given weapon: %s (Hash: %s)^0", weaponName, weaponHash))
        ClientUtils.Notify('success', "Test Weapon: " .. weaponName)
    end, false)

    -- Test-Command: Aktuelles Weapon anzeigen
    RegisterCommand('checkweapon', function()
        local playerPed = PlayerPedId()
        local currentWeapon = GetSelectedPedWeapon(playerPed)

        print(string.format("^3[Equipment Test] Current weapon hash: %s^0", currentWeapon))

        -- Check ob es ein Equipment-Weapon ist
        for weaponType, weaponData in pairs(EquipmentWeapons) do
            if weaponData.hash == currentWeapon then
                print(string.format("^2[Equipment Test] Matched: %s^0", weaponData.label))
                ClientUtils.Notify('info', "Equipped: " .. weaponData.label)
                return
            end
        end

        ClientUtils.Notify('warning', "Kein Equipment equipped")
    end, false)
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

exports('GetCurrentTool', GetCurrentTool)
exports('HasTool', HasTool)
exports('GetInventory', GetInventory)

print("^2[Equipment Client] Loaded (Weapon-Based with Tints)^0")
