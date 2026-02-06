-- =============================================================================
-- STORAGE SYSTEM - Persistente Datenspeicherung
-- =============================================================================

--[[
    WARUM ein Storage System?

    PROBLEM:
    - Config-Änderungen verschwinden bei Restart
    - Spieler-Daten gehen bei Disconnect verloren
    - Keine zentrale Datenverwaltung

    LÖSUNG:
    - JSON-basierte Persistenz
    - Hot-Reload (änderbar ohne Restart)
    - Spieler-Daten bleiben erhalten
    - Modul-spezifische Datenbanken
]]

Storage = {}

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

local Config = {
    -- Speicher-Pfade
    DataPath = "data/",
    ConfigFile = "data/config.json",
    PlayersPath = "data/players/",
    ModulesPath = "data/modules/",

    -- Auto-Save
    AutoSaveEnabled = true,
    AutoSaveInterval = 300000, -- 5 Minuten

    -- Performance
    CacheTimeout = 60000, -- 1 Minute

    -- Debug
    Debug = false
}

-- =============================================================================
-- INTERNAL STATE
-- =============================================================================

-- Runtime-Config (überschreibt Config-Dateien)
local runtimeConfig = {}

-- Player-Data Cache
-- { [identifier] = { data = {...}, timestamp = 123456, dirty = true } }
local playerCache = {}

-- Module-Data Cache
-- { [moduleName] = { data = {...}, timestamp = 123456, dirty = true } }
local moduleCache = {}

-- Dirty Flag (wurde etwas geändert seit letztem Save?)
local configDirty = false

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

function Storage.Initialize()
    --[[
        Erstellt Ordner-Struktur und lädt gespeicherte Daten
    ]]

    print("^2[Storage] Initializing...^0")

    -- Erstelle Ordner (falls nicht vorhanden)
    CreateDirectoryIfNotExists(Config.DataPath)
    CreateDirectoryIfNotExists(Config.PlayersPath)
    CreateDirectoryIfNotExists(Config.ModulesPath)

    -- Lade Runtime-Config
    LoadRuntimeConfig()

    -- Starte Auto-Save
    if Config.AutoSaveEnabled then
        StartAutoSave()
    end

    print("^2[Storage] Ready!^0")
end

function CreateDirectoryIfNotExists(path)
    --[[
        WARUM diese Funktion?
        FiveM erstellt Ordner nicht automatisch
        SaveResourceFile schlägt fehl wenn Ordner nicht existiert
    ]]

    -- Versuche leere Datei zu erstellen (erstellt Ordner dabei)
    local testFile = path .. ".keep"
    SaveResourceFile(GetCurrentResourceName(), testFile, "", -1)
end

-- =============================================================================
-- CONFIG STORAGE
-- =============================================================================

function Storage.SetConfig(module, key, value)
    --[[
        Setzt Config-Wert zur Laufzeit
        Überschreibt Config-Datei-Werte

        BEISPIEL:
        Storage.SetConfig('Fire', 'SpreadDistance', 10.0)
        → Config.Fire.SpreadDistance wird zu 10.0

        WICHTIG: Bleibt nach Restart erhalten!
    ]]

    -- Initialisiere Modul-Config falls nicht vorhanden
    if not runtimeConfig[module] then
        runtimeConfig[module] = {}
    end

    -- Alter Wert für Logging
    local oldValue = runtimeConfig[module][key]

    -- Neuer Wert setzen
    runtimeConfig[module][key] = value
    configDirty = true

    -- Actual Config auch updaten (Hot-Reload)
    if _G.Config and _G.Config[module] then
        _G.Config[module][key] = value
    end

    if Config.Debug then
        print(string.format(
            "^3[Storage] Config changed: %s.%s = %s (was: %s)^0",
            module,
            key,
            tostring(value),
            tostring(oldValue)
        ))
    end

    -- Trigger Event für andere Scripts
    TriggerEvent(Events.Core.ConfigUpdated, module, key, value, oldValue)

    return true
end

function Storage.GetConfig(module, key, defaultValue)
    --[[
        Holt Config-Wert (Runtime hat Priorität)
    ]]

    -- Runtime-Config prüfen
    if runtimeConfig[module] and runtimeConfig[module][key] ~= nil then
        return runtimeConfig[module][key]
    end

    -- Fallback: Original Config
    if _G.Config and _G.Config[module] and _G.Config[module][key] ~= nil then
        return _G.Config[module][key]
    end

    -- Fallback: Default
    return defaultValue
end

function Storage.ResetConfig(module, key)
    --[[
        Setzt Config auf Original-Wert zurück
    ]]

    if not runtimeConfig[module] then
        return false
    end

    local originalValue = nil
    if _G.Config and _G.Config[module] then
        originalValue = _G.Config[module][key]
    end

    runtimeConfig[module][key] = nil
    configDirty = true

    -- Update actual Config
    if _G.Config and _G.Config[module] then
        -- Reload original value (braucht Config-File reload)
    end

    if Config.Debug then
        print(string.format(
            "^3[Storage] Config reset: %s.%s to %s^0",
            module,
            key,
            tostring(originalValue)
        ))
    end

    return true
end

function LoadRuntimeConfig()
    --[[
        Lädt gespeicherte Runtime-Config von Disk
    ]]

    local data = LoadResourceFile(GetCurrentResourceName(), Config.ConfigFile)

    if not data then
        if Config.Debug then
            print("^3[Storage] No runtime config found, using defaults^0")
        end
        return
    end

    local success, decoded = pcall(json.decode, data)

    if not success then
        print("^1[Storage] ERROR: Failed to decode runtime config!^0")
        return
    end

    runtimeConfig = decoded or {}

    -- Apply to actual Config
    for module, moduleConfig in pairs(runtimeConfig) do
        if _G.Config and _G.Config[module] then
            for key, value in pairs(moduleConfig) do
                _G.Config[module][key] = value
            end
        end
    end

    print(string.format("^2[Storage] Runtime config loaded (%d modules)^0", Utils.TableCount(runtimeConfig)))
end

function Storage.SaveConfig()
    --[[
        Speichert Runtime-Config auf Disk
    ]]

    if not configDirty then
        if Config.Debug then
            print("^3[Storage] Config not dirty, skipping save^0")
        end
        return true
    end

    local data = json.encode(runtimeConfig, { indent = true })

    local success = SaveResourceFile(GetCurrentResourceName(), Config.ConfigFile, data, -1)

    if success then
        configDirty = false

        if Config.Debug then
            print("^2[Storage] Runtime config saved^0")
        end

        TriggerEvent(Events.Core.ConfigSaved)
        return true
    else
        print("^1[Storage] ERROR: Failed to save runtime config!^0")
        return false
    end
end

-- =============================================================================
-- PLAYER DATA STORAGE
-- =============================================================================

function Storage.GetPlayerIdentifier(source)
    --[[
        Holt eindeutigen Identifier für Spieler

        PRIORITÄT:
        1. Steam ID (am stabilsten)
        2. License ID (Rockstar)
        3. FiveM License
        4. IP (Fallback, nicht empfohlen)
    ]]

    local identifiers = GetPlayerIdentifiers(source)

    for _, id in ipairs(identifiers) do
        if string.find(id, "steam:") then
            return id
        end
    end

    for _, id in ipairs(identifiers) do
        if string.find(id, "license:") then
            return id
        end
    end

    for _, id in ipairs(identifiers) do
        if string.find(id, "license2:") then
            return id
        end
    end

    -- Fallback: IP (nicht ideal)
    return "ip:" .. GetPlayerEndpoint(source)
end

function Storage.SetPlayerData(source, key, value)
    --[[
        Speichert Spieler-spezifische Daten

        BEISPIEL:
        Storage.SetPlayerData(source, 'scba_certified', true)
        Storage.SetPlayerData(source, 'total_fires_extinguished', 50)
    ]]

    local identifier = Storage.GetPlayerIdentifier(source)

    -- Initialisiere Cache falls nicht vorhanden
    if not playerCache[identifier] then
        playerCache[identifier] = {
            data = {},
            timestamp = GetGameTimer(),
            dirty = false
        }
    end

    -- Alten Wert für Logging
    local oldValue = playerCache[identifier].data[key]

    -- Neuen Wert setzen
    playerCache[identifier].data[key] = value
    playerCache[identifier].dirty = true
    playerCache[identifier].timestamp = GetGameTimer()

    if Config.Debug then
        print(string.format(
            "^3[Storage] Player data changed: %s [%s] = %s (was: %s)^0",
            GetPlayerName(source),
            key,
            tostring(value),
            tostring(oldValue)
        ))
    end

    return true
end

function Storage.GetPlayerData(source, key, defaultValue)
    --[[
        Holt Spieler-Daten
    ]]

    local identifier = Storage.GetPlayerIdentifier(source)

    -- Prüfe Cache
    if playerCache[identifier] and playerCache[identifier].data[key] ~= nil then
        return playerCache[identifier].data[key]
    end

    -- Lade von Disk (falls nicht im Cache)
    LoadPlayerData(identifier)

    if playerCache[identifier] and playerCache[identifier].data[key] ~= nil then
        return playerCache[identifier].data[key]
    end

    -- Fallback: Default
    return defaultValue
end

function LoadPlayerData(identifier)
    --[[
        Lädt Spieler-Daten von Disk in Cache
    ]]

    -- Bereits im Cache?
    if playerCache[identifier] then
        local age = GetGameTimer() - playerCache[identifier].timestamp
        if age < Config.CacheTimeout then
            return -- Cache noch gültig
        end
    end

    -- Sanitize identifier für Dateiname
    local filename = identifier:gsub(":", "_")
    local filepath = Config.PlayersPath .. filename .. ".json"

    local data = LoadResourceFile(GetCurrentResourceName(), filepath)

    if not data then
        -- Keine gespeicherten Daten
        playerCache[identifier] = {
            data = {},
            timestamp = GetGameTimer(),
            dirty = false
        }
        return
    end

    local success, decoded = pcall(json.decode, data)

    if not success then
        print(string.format("^1[Storage] ERROR: Failed to decode player data for %s^0", identifier))
        playerCache[identifier] = {
            data = {},
            timestamp = GetGameTimer(),
            dirty = false
        }
        return
    end

    playerCache[identifier] = {
        data = decoded or {},
        timestamp = GetGameTimer(),
        dirty = false
    }
end

function Storage.SavePlayerData(source)
    --[[
        Speichert Spieler-Daten auf Disk
    ]]

    local identifier = Storage.GetPlayerIdentifier(source)

    if not playerCache[identifier] or not playerCache[identifier].dirty then
        return true -- Nichts zu speichern
    end

    local filename = identifier:gsub(":", "_")
    local filepath = Config.PlayersPath .. filename .. ".json"

    local data = json.encode(playerCache[identifier].data, { indent = true })

    local success = SaveResourceFile(GetCurrentResourceName(), filepath, data, -1)

    if success then
        playerCache[identifier].dirty = false

        if Config.Debug then
            print(string.format("^2[Storage] Player data saved: %s^0", GetPlayerName(source)))
        end

        return true
    else
        print(string.format("^1[Storage] ERROR: Failed to save player data for %s^0", GetPlayerName(source)))
        return false
    end
end

function Storage.SaveAllPlayerData()
    --[[
        Speichert alle Spieler-Daten (für Auto-Save)
    ]]

    local savedCount = 0

    for identifier, cache in pairs(playerCache) do
        if cache.dirty then
            local filename = identifier:gsub(":", "_")
            local filepath = Config.PlayersPath .. filename .. ".json"

            local data = json.encode(cache.data, { indent = true })
            local success = SaveResourceFile(GetCurrentResourceName(), filepath, data, -1)

            if success then
                cache.dirty = false
                savedCount = savedCount + 1
            end
        end
    end

    if savedCount > 0 and Config.Debug then
        print(string.format("^2[Storage] Saved %d player data files^0", savedCount))
    end

    return savedCount
end

-- =============================================================================
-- MODULE DATA STORAGE
-- =============================================================================

function Storage.SetModuleData(moduleName, key, value)
    --[[
        Speichert Modul-spezifische Daten

        BEISPIEL:
        Storage.SetModuleData('fire', 'total_fires_spawned', 1500)
        Storage.SetModuleData('scba', 'total_refills', 300)
    ]]

    if not moduleCache[moduleName] then
        moduleCache[moduleName] = {
            data = {},
            timestamp = GetGameTimer(),
            dirty = false
        }
    end

    moduleCache[moduleName].data[key] = value
    moduleCache[moduleName].dirty = true
    moduleCache[moduleName].timestamp = GetGameTimer()

    if Config.Debug then
        print(string.format(
            "^3[Storage] Module data changed: %s.%s = %s^0",
            moduleName,
            key,
            tostring(value)
        ))
    end

    return true
end

function Storage.GetModuleData(moduleName, key, defaultValue)
    --[[
        Holt Modul-Daten
    ]]

    -- Prüfe Cache
    if moduleCache[moduleName] and moduleCache[moduleName].data[key] ~= nil then
        return moduleCache[moduleName].data[key]
    end

    -- Lade von Disk
    LoadModuleData(moduleName)

    if moduleCache[moduleName] and moduleCache[moduleName].data[key] ~= nil then
        return moduleCache[moduleName].data[key]
    end

    return defaultValue
end

function LoadModuleData(moduleName)
    --[[
        Lädt Modul-Daten von Disk
    ]]

    if moduleCache[moduleName] then
        local age = GetGameTimer() - moduleCache[moduleName].timestamp
        if age < Config.CacheTimeout then
            return -- Cache noch gültig
        end
    end

    local filepath = Config.ModulesPath .. moduleName .. ".json"
    local data = LoadResourceFile(GetCurrentResourceName(), filepath)

    if not data then
        moduleCache[moduleName] = {
            data = {},
            timestamp = GetGameTimer(),
            dirty = false
        }
        return
    end

    local success, decoded = pcall(json.decode, data)

    if not success then
        print(string.format("^1[Storage] ERROR: Failed to decode module data for %s^0", moduleName))
        moduleCache[moduleName] = {
            data = {},
            timestamp = GetGameTimer(),
            dirty = false
        }
        return
    end

    moduleCache[moduleName] = {
        data = decoded or {},
        timestamp = GetGameTimer(),
        dirty = false
    }
end

function Storage.SaveModuleData(moduleName)
    --[[
        Speichert Modul-Daten auf Disk
    ]]

    if not moduleCache[moduleName] or not moduleCache[moduleName].dirty then
        return true
    end

    local filepath = Config.ModulesPath .. moduleName .. ".json"
    local data = json.encode(moduleCache[moduleName].data, { indent = true })

    local success = SaveResourceFile(GetCurrentResourceName(), filepath, data, -1)

    if success then
        moduleCache[moduleName].dirty = false

        if Config.Debug then
            print(string.format("^2[Storage] Module data saved: %s^0", moduleName))
        end

        return true
    else
        print(string.format("^1[Storage] ERROR: Failed to save module data for %s^0", moduleName))
        return false
    end
end

function Storage.SaveAllModuleData()
    --[[
        Speichert alle Modul-Daten
    ]]

    local savedCount = 0

    for moduleName, cache in pairs(moduleCache) do
        if cache.dirty then
            local filepath = Config.ModulesPath .. moduleName .. ".json"
            local data = json.encode(cache.data, { indent = true })
            local success = SaveResourceFile(GetCurrentResourceName(), filepath, data, -1)

            if success then
                cache.dirty = false
                savedCount = savedCount + 1
            end
        end
    end

    if savedCount > 0 and Config.Debug then
        print(string.format("^2[Storage] Saved %d module data files^0", savedCount))
    end

    return savedCount
end

-- =============================================================================
-- AUTO-SAVE SYSTEM
-- =============================================================================

function StartAutoSave()
    --[[
        Speichert periodisch alle Daten
    ]]

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.AutoSaveInterval)

            if Config.Debug then
                print("^3[Storage] Auto-save triggered^0")
            end

            -- Speichere alles
            Storage.SaveConfig()
            Storage.SaveAllPlayerData()
            Storage.SaveAllModuleData()
        end
    end)

    print(string.format("^2[Storage] Auto-save started (every %d seconds)^0", Config.AutoSaveInterval / 1000))
end

-- =============================================================================
-- EVENTS
-- =============================================================================

-- Spieler disconnected = Daten speichern
AddEventHandler('playerDropped', function(reason)
    local source = source
    Storage.SavePlayerData(source)

    -- Cache cleanup (optional)
    local identifier = Storage.GetPlayerIdentifier(source)
    -- playerCache[identifier] = nil  -- Oder behalten für schnelleres Rejoin
end)

-- Resource stop = Alles speichern
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^3[Storage] Shutdown - saving all data...^0")

        Storage.SaveConfig()
        Storage.SaveAllPlayerData()
        Storage.SaveAllModuleData()

        print("^2[Storage] Shutdown complete^0")
    end
end)

-- =============================================================================
-- ADMIN COMMANDS
-- =============================================================================

RegisterCommand('fdconfig', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "System", "Keine Berechtigung!" }
        })
        return
    end

    local subcommand = args[1]

    if subcommand == 'set' then
        local module = args[2]
        local key = args[3]
        local value = args[4]

        if not module or not key or not value then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 100, 0 },
                args = { "Usage", "/fdconfig set [module] [key] [value]" }
            })
            return
        end

        -- Konvertiere value zu richtigem Typ
        local convertedValue = ConvertValue(value)

        Storage.SetConfig(module, key, convertedValue)

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Config", string.format("Set %s.%s = %s", module, key, tostring(convertedValue)) }
        })
    elseif subcommand == 'get' then
        local module = args[2]
        local key = args[3]

        if not module or not key then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 100, 0 },
                args = { "Usage", "/fdconfig get [module] [key]" }
            })
            return
        end

        local value = Storage.GetConfig(module, key, "NOT_SET")

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 255 },
            args = { "Config", string.format("%s.%s = %s", module, key, tostring(value)) }
        })
    elseif subcommand == 'save' then
        Storage.SaveConfig()
        Storage.SaveAllPlayerData()
        Storage.SaveAllModuleData()

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Storage", "All data saved!" }
        })
    elseif subcommand == 'reset' then
        local module = args[2]
        local key = args[3]

        if not module or not key then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 100, 0 },
                args = { "Usage", "/fdconfig reset [module] [key]" }
            })
            return
        end

        Storage.ResetConfig(module, key)

        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            args = { "Config", string.format("Reset %s.%s to default", module, key) }
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 200, 0 },
            multiline = true,
            args = { "FD Config Commands",
                "/fdconfig set [module] [key] [value] - Set config value\n" ..
                "/fdconfig get [module] [key] - Get config value\n" ..
                "/fdconfig save - Save all data\n" ..
                "/fdconfig reset [module] [key] - Reset to default"
            }
        })
    end
end, false)

function ConvertValue(str)
    --[[
        Konvertiert String zu richtigem Datentyp
        "true" → true (boolean)
        "123" → 123 (number)
        "hello" → "hello" (string)
    ]]

    -- Boolean
    if str == "true" then return true end
    if str == "false" then return false end

    -- Number
    local num = tonumber(str)
    if num then return num end

    -- String
    return str
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

exports('SetConfig', Storage.SetConfig)
exports('GetConfig', Storage.GetConfig)
exports('SetPlayerData', Storage.SetPlayerData)
exports('GetPlayerData', Storage.GetPlayerData)
exports('SetModuleData', Storage.SetModuleData)
exports('GetModuleData', Storage.GetModuleData)

-- =============================================================================
-- STARTUP
-- =============================================================================

Citizen.CreateThread(function()
    Storage.Initialize()
end)
