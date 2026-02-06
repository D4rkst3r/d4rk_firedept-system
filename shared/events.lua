-- =============================================================================
-- EVENT REGISTRY - Zentrale Event-Verwaltung
-- =============================================================================

--[[
    WARUM Event Registry?

    PROBLEM:
    TriggerEvent('firedept:client:createFire', data)  // String = Typo möglich!

    LÖSUNG:
    TriggerEvent(Events.Fire.Create, data)  // Lua Error bei Typo!

    VORTEILE:
    ✅ Typo-sicher (Lua Error sofort)
    ✅ Autocomplete in IDE
    ✅ Zentrale Dokumentation
    ✅ Einfaches Refactoring
    ✅ Namespace-Trennung
]]

Events = {}

-- =============================================================================
-- FIRE MODULE EVENTS
-- =============================================================================

Events.Fire = {
    -- Client Events (Server → Client)
    Create = 'firedept:client:fire:create',
    Update = 'firedept:client:fire:update',
    Extinguish = 'firedept:client:fire:extinguish',

    -- Server Events (Client → Server)
    RequestCreate = 'firedept:server:fire:create',
    RequestExtinguish = 'firedept:server:fire:extinguish',
    AttemptExtinguish = 'firedept:server:fire:attemptExtinguish',

    -- Shared Events (beide Richtungen)
    Sync = 'firedept:fire:sync',
}

-- =============================================================================
-- SCBA MODULE EVENTS (Vorbereitung für später)
-- =============================================================================

Events.SCBA = {
    -- Client Events
    Equip = 'firedept:client:scba:equip',
    Unequip = 'firedept:client:scba:unequip',
    UpdateAir = 'firedept:client:scba:updateAir',
    LowAirWarning = 'firedept:client:scba:lowAir',

    -- Server Events
    RequestEquip = 'firedept:server:scba:equip',
    RequestUnequip = 'firedept:server:scba:unequip',
    RequestRefill = 'firedept:server:scba:refill',
}

-- =============================================================================
-- EQUIPMENT MODULE EVENTS (Vorbereitung für später)
-- =============================================================================

Events.Equipment = {
    -- Client Events
    Give = 'firedept:client:equipment:give',
    Remove = 'firedept:client:equipment:remove',
    Use = 'firedept:client:equipment:use',

    -- Server Events
    RequestGive = 'firedept:server:equipment:give',
    RequestRemove = 'firedept:server:equipment:remove',
    RequestUse = 'firedept:server:equipment:use',
}

-- =============================================================================
-- VEHICLE MODULE EVENTS (Vorbereitung für später)
-- =============================================================================

Events.Vehicle = {
    -- Client Events
    UpdatePump = 'firedept:client:vehicle:updatePump',
    UpdateHose = 'firedept:client:vehicle:updateHose',

    -- Server Events
    RequestPump = 'firedept:server:vehicle:pump',
    RequestHose = 'firedept:server:vehicle:hose',
}

-- =============================================================================
-- STATION MODULE EVENTS (Vorbereitung für später)
-- =============================================================================

Events.Station = {
    -- Client Events
    OpenMenu = 'firedept:client:station:openMenu',
    CloseMenu = 'firedept:client:station:closeMenu',

    -- Server Events
    RequestGear = 'firedept:server:station:gear',
    CheckApparatus = 'firedept:server:station:apparatus',
}

-- =============================================================================
-- CORE SYSTEM EVENTS
-- =============================================================================

Events.Core = {
    -- Module Management
    ModuleLoaded = 'firedept:core:moduleLoaded',
    ModuleUnloaded = 'firedept:core:moduleUnloaded',

    -- Permission Events
    PermissionChanged = 'firedept:core:permissionChanged',
    PermissionCheck = 'firedept:core:permissionCheck',

    -- Config Events
    ConfigUpdated = 'firedept:core:configUpdated',
    ConfigSaved = 'firedept:core:configSaved',
}

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

function Events.GetAllEvents()
    --[[
        Gibt alle registrierten Events zurück
        Nützlich für Debugging oder Admin-Panels
    ]]

    local allEvents = {}

    for moduleName, moduleEvents in pairs(Events) do
        if type(moduleEvents) == "table" and moduleName ~= "GetAllEvents" and moduleName ~= "PrintEventList" then
            for eventName, eventString in pairs(moduleEvents) do
                table.insert(allEvents, {
                    module = moduleName,
                    name = eventName,
                    event = eventString
                })
            end
        end
    end

    return allEvents
end

function Events.PrintEventList()
    --[[
        Gibt schöne Liste aller Events in Console aus
        Nützlich für Entwicklung
    ]]

    print("^3========== REGISTERED EVENTS ==========^0")

    for moduleName, moduleEvents in pairs(Events) do
        if type(moduleEvents) == "table" and moduleName ~= "GetAllEvents" and moduleName ~= "PrintEventList" then
            print(string.format("^2[%s Module]^0", moduleName))

            for eventName, eventString in pairs(moduleEvents) do
                print(string.format("  ^3%s^0 → ^7%s^0", eventName, eventString))
            end

            print("")
        end
    end

    print("^3========================================^0")
end

-- =============================================================================
-- VALIDATION (Optional - für Production)
-- =============================================================================

function Events.ValidateEvent(eventString)
    --[[
        Check ob ein Event in der Registry existiert
        Nützlich für extra Sicherheit
    ]]

    for _, moduleEvents in pairs(Events) do
        if type(moduleEvents) == "table" then
            for _, registeredEvent in pairs(moduleEvents) do
                if registeredEvent == eventString then
                    return true
                end
            end
        end
    end

    return false
end

-- =============================================================================
-- DEBUG COMMAND
-- =============================================================================

-- Command um alle Events zu sehen
if not IsDuplicityVersion() then
    -- Client-Side Command
    RegisterCommand('fdevents', function()
        Events.PrintEventList()
    end, false)
end

-- Server-Side Command
if IsDuplicityVersion() then
    RegisterCommand('fdevents', function(source)
        Events.PrintEventList()
    end, false)
end

-- =============================================================================
-- STARTUP
-- =============================================================================

if IsDuplicityVersion() then
    print("^2[Event Registry - Server] Loaded^0")
    print(string.format("^2[Event Registry] %d modules registered^0", Utils.TableCount(Events) - 3))
else
    print("^2[Event Registry - Client] Loaded^0")
end

-- Optional: Event-Liste beim Start anzeigen (für Development)
-- Events.PrintEventList()
