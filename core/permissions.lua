-- =============================================================================
-- PERMISSIONS SYSTEM - Zentrale Rechteverwaltung
-- =============================================================================

-- WARUM ein eigenes System?
-- 1. Standalone (keine Framework-Abhängigkeit)
-- 2. Erweiterbar (kann später ESX/QBCore integrieren)
-- 3. Einheitlich über alle Module
-- 4. Cached für Performance

Permissions = {}

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

local Config = {
    -- Permission-Hierarchie (je höher die Zahl, desto mehr Rechte)
    Hierarchy = {
        user = 0,        -- Normaler Spieler (default)
        firefighter = 1, -- Fire Department Member (Basiszugriff)
        officer = 2,     -- Officer (erweiterte Commands)
        chief = 3,       -- Fire Chief (fast alles)
        admin = 4        -- Server Admin (ALLES)
    },

    -- ACE Permissions (FiveM native system)
    -- https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/#configuring-server-admins
    UseAce = true,
    AcePermission = "firedept.admin", -- add_ace group.admin firedept.admin allow

    -- Job System Integration (optional)
    UseJobSystem = false, -- Setze auf true für ESX/QBCore
    JobName = "fire",     -- Job-Name im Framework

    -- Cache Settings
    CacheTimeout = 300000, -- 5 Minuten (danach neu prüfen)

    -- Debug
    Debug = false
}

-- =============================================================================
-- INTERNAL STATE
-- =============================================================================

-- Cache: { [source] = { level = "admin", timestamp = 123456 } }
local permissionCache = {}

-- Callbacks: Module können sich registrieren um bei Permission-Änderungen benachrichtigt zu werden
local permissionCallbacks = {}

-- =============================================================================
-- CORE FUNCTIONS
-- =============================================================================

-- WARUM diese Funktion?
-- Zentrale Stelle für alle Permission-Checks
-- ALLE Module nutzen diese Funktion
function Permissions.HasPermission(source, requiredLevel)
    --[[
        PARAMETER:
        - source: Server-seitige Player-ID
        - requiredLevel: String oder Number
          - String: 'admin', 'chief', 'firefighter', etc.
          - Number: 0-4 (direkte Hierarchie)

        RETURN:
        - true/false

        BEISPIEL:
        if Permissions.HasPermission(source, 'admin') then
            -- Admin-nur Code
        end
    ]]

    -- Validierung
    if not source or source == 0 then
        if Config.Debug then
            print("^3[Permissions] Invalid source (0 or nil)^0")
        end
        return false
    end

    -- Hole Permission Level des Spielers
    local playerLevel = Permissions.GetPlayerLevel(source)

    -- Konvertiere zu Hierarchie-Nummer
    local playerHierarchy = Config.Hierarchy[playerLevel] or 0
    local requiredHierarchy = type(requiredLevel) == "string" and Config.Hierarchy[requiredLevel] or requiredLevel

    -- Vergleich
    local hasPermission = playerHierarchy >= requiredHierarchy

    if Config.Debug then
        print(string.format(
            "^3[Permissions] Check: Player %s (%s/%d) vs Required (%s/%d) = %s^0",
            GetPlayerName(source),
            playerLevel,
            playerHierarchy,
            requiredLevel,
            requiredHierarchy,
            hasPermission and "GRANTED" or "DENIED"
        ))
    end

    return hasPermission
end

-- =============================================================================
-- PERMISSION RETRIEVAL
-- =============================================================================

function Permissions.GetPlayerLevel(source)
    --[[
        WARUM Cache?
        - Permission-Checks können 100x pro Sekunde aufgerufen werden
        - ACE/Job-System Abfragen sind langsam
        - Cache = massive Performance-Verbesserung
    ]]

    -- Cache-Check
    local cached = permissionCache[source]
    if cached then
        local now = GetGameTimer()
        if (now - cached.timestamp) < Config.CacheTimeout then
            return cached.level
        end
    end

    -- Neu ermitteln
    local level = DeterminePlayerLevel(source)

    -- Cache speichern
    permissionCache[source] = {
        level = level,
        timestamp = GetGameTimer()
    }

    return level
end

function DeterminePlayerLevel(source)
    --[[
        HIERARCHIE DER CHECKS:
        1. ACE System (FiveM native)
        2. Job System (ESX/QBCore wenn enabled)
        3. Fallback: 'user'
    ]]

    -- CHECK 1: ACE System
    if Config.UseAce then
        if IsPlayerAceAllowed(source, Config.AcePermission) then
            return 'admin'
        end

        -- WARUM zusätzliche ACE-Checks?
        -- Server-Owner können granulare Permissions setzen:
        -- add_ace group.firechiefs firedept.chief allow
        if IsPlayerAceAllowed(source, "firedept.chief") then
            return 'chief'
        end

        if IsPlayerAceAllowed(source, "firedept.officer") then
            return 'officer'
        end

        if IsPlayerAceAllowed(source, "firedept.firefighter") then
            return 'firefighter'
        end
    end

    -- CHECK 2: Job System (ESX/QBCore)
    if Config.UseJobSystem then
        local jobLevel = GetPlayerJobLevel(source)
        if jobLevel then
            return jobLevel
        end
    end

    -- CHECK 3: Fallback
    return 'user'
end

-- =============================================================================
-- JOB SYSTEM INTEGRATION (Optional)
-- =============================================================================

function GetPlayerJobLevel(source)
    --[[
        WARUM optional?
        - Viele Server nutzen kein Framework
        - Standalone = mehr Flexibilität

        SPÄTER IMPLEMENTIEREN:
        - ESX: ESX.GetPlayerFromId(source).job.name
        - QBCore: QBCore.Functions.GetPlayer(source).PlayerData.job.name
    ]]

    -- Placeholder für später
    if GetResourceState('es_extended') == 'started' then
        -- ESX Integration hier
        return nil
    elseif GetResourceState('qb-core') == 'started' then
        -- QBCore Integration hier
        return nil
    end

    return nil
end

-- =============================================================================
-- CACHE MANAGEMENT
-- =============================================================================

function Permissions.InvalidateCache(source)
    --[[
        WARUM diese Funktion?
        - Wenn ein Spieler Job wechselt
        - Wenn Permissions geändert werden
        - Für Admin-Commands (promote/demote)
    ]]

    if permissionCache[source] then
        permissionCache[source] = nil

        if Config.Debug then
            print(string.format("^3[Permissions] Cache invalidated for %s^0", GetPlayerName(source)))
        end

        -- Callbacks benachrichtigen
        TriggerPermissionCallbacks(source, 'cache_invalidated')
    end
end

function Permissions.ClearCache()
    -- Kompletter Cache-Reset
    permissionCache = {}

    if Config.Debug then
        print("^3[Permissions] Complete cache cleared^0")
    end
end

-- Automatischer Cleanup wenn Spieler disconnected
AddEventHandler('playerDropped', function(reason)
    local source = source
    if permissionCache[source] then
        permissionCache[source] = nil
    end
end)

-- =============================================================================
-- CALLBACKS (für Module)
-- =============================================================================

function Permissions.RegisterCallback(moduleName, callback)
    --[[
        WARUM Callbacks?
        - Module können reagieren wenn Permissions sich ändern
        - Z.B. UI neu laden, Commands neu checken, etc.

        BEISPIEL:
        Permissions.RegisterCallback('fire', function(source, event, oldLevel, newLevel)
            print("Fire Module: Player " .. source .. " permission changed!")
        end)
    ]]

    if not permissionCallbacks[moduleName] then
        permissionCallbacks[moduleName] = callback

        if Config.Debug then
            print(string.format("^2[Permissions] Callback registered: %s^0", moduleName))
        end
    end
end

function TriggerPermissionCallbacks(source, event, oldLevel, newLevel)
    for moduleName, callback in pairs(permissionCallbacks) do
        local success, err = pcall(callback, source, event, oldLevel, newLevel)
        if not success then
            print(string.format("^1[Permissions] Callback error in %s: %s^0", moduleName, err))
        end
    end
end

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

function Permissions.GetAllPlayersWithLevel(level)
    --[[
        WARUM nützlich?
        - Admin-Command: Liste alle Admins
        - Event: Benachrichtige alle Chiefs
        - Statistiken
    ]]

    local players = {}
    local allPlayers = GetPlayers()

    for _, source in ipairs(allPlayers) do
        if Permissions.HasPermission(source, level) then
            table.insert(players, {
                source = source,
                name = GetPlayerName(source),
                level = Permissions.GetPlayerLevel(source)
            })
        end
    end

    return players
end

function Permissions.GetHierarchyLevel(levelName)
    -- Utility: Konvertiere Level-Name zu Nummer
    return Config.Hierarchy[levelName] or 0
end

-- =============================================================================
-- ADMIN COMMANDS (für Testing)
-- =============================================================================

RegisterCommand('fdperm', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "System", "Keine Berechtigung!" }
        })
        return
    end

    local subcommand = args[1]

    if subcommand == 'check' then
        local targetId = tonumber(args[2])
        if not targetId then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 100, 0 },
                args = { "Usage", "/fdperm check [playerID]" }
            })
            return
        end

        local level = Permissions.GetPlayerLevel(targetId)
        local hierarchy = Config.Hierarchy[level]

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Permission Check", string.format(
                "%s: %s (Level %d)",
                GetPlayerName(targetId),
                level,
                hierarchy
            ) }
        })
    elseif subcommand == 'clear' then
        Permissions.ClearCache()
        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Permissions", "Cache cleared!" }
        })
    elseif subcommand == 'list' then
        local levelFilter = args[2] or 'admin'
        local players = Permissions.GetAllPlayersWithLevel(levelFilter)

        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            args = { "Players with " .. levelFilter, string.format("Found %d players", #players) }
        })

        for _, player in ipairs(players) do
            TriggerClientEvent('chat:addMessage', source, {
                color = { 200, 200, 200 },
                args = { "  ", string.format("[%d] %s (%s)", player.source, player.name, player.level) }
            })
        end
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            multiline = true,
            args = { "FD Permissions",
                "/fdperm check [id] - Check player permission\n" ..
                "/fdperm clear - Clear permission cache\n" ..
                "/fdperm list [level] - List players with level"
            }
        })
    end
end, false)

-- =============================================================================
-- EXPORTS (für andere Ressourcen)
-- =============================================================================

exports('HasPermission', Permissions.HasPermission)
exports('GetPlayerLevel', Permissions.GetPlayerLevel)
exports('InvalidateCache', Permissions.InvalidateCache)

-- =============================================================================
-- STARTUP
-- =============================================================================

Citizen.CreateThread(function()
    print("^2[Permissions System] Initialized^0")
    print(string.format("^2[Permissions] ACE: %s | Jobs: %s^0",
        Config.UseAce and "enabled" or "disabled",
        Config.UseJobSystem and "enabled" or "disabled"
    ))
end)
