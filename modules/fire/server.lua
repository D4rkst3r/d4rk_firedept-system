-- =============================================================================
-- FIRE MODULE - SERVER SIDE
-- =============================================================================
-- WARUM Server-Side?
-- 1. AUTORITÄT: Server entscheidet was "wahr" ist (Anti-Cheat)
-- 2. SYNCHRONISATION: Alle Spieler sehen dasselbe Feuer
-- 3. PERSISTENZ: Feuer bleiben bestehen wenn Spieler disconnecten
-- =============================================================================

-- Lokale Variablen (nur für dieses Script sichtbar)
local activeFires = {}  -- { [fireId] = fireData }
local fireIdCounter = 1 -- Auto-Increment ID Generator
-- Globaler Spread Manager (statt 1 Thread pro Feuer)
local spreadManagerRunning = false

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- WARUM diese Funktion?
-- #table funktioniert NICHT bei non-array Tables!
-- Diese Funktion zählt ALLE Keys richtig
function CountActiveFires()
    local count = 0
    for _, fire in pairs(activeFires) do
        if not fire.extinguished then
            count = count + 1
        end
    end
    return count
end

-- =============================================================================
-- INIT: Wird beim Ressource-Start aufgerufen
-- =============================================================================

Citizen.CreateThread(function()
    print("^2[Fire Module - Server] Initializing...^0")

    -- Lade gespeicherte Feuer (falls vorhanden)
    LoadPersistedFires()

    -- Starte Auto-Save Timer
    StartAutoSave()

    print("^2[Fire Module - Server] Ready!^0")
end)

-- =============================================================================
-- FIRE CREATION - Die Hauptfunktion
-- =============================================================================

-- WARUM RegisterNetEvent + AddEventHandler?
-- Client sendet Event → Server empfängt → verarbeitet → sendet an ALLE Clients
function CreateFire(coords, class, intensity, radius, source)
    --[[
        WICHTIGER KONZEPT: Server-Side Validation
        WARUM? Clients sind NICHT vertrauenswürdig!
        Ein modded Client könnte behaupten: "Spawn 1000 Feuer!"
    ]]

    -- Validierung: Ist der Spieler berechtigt?
    if not Permissions.HasPermission(source, 'admin') then
        print(string.format("^1[Fire Module] Player %s tried to spawn fire without permission!^0", GetPlayerName(source)))
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            multiline = true,
            args = { "System", "Du hast keine Berechtigung dafür!" }
        })
        return false
    end

    -- Validierung: Sind die Koordinaten gültig?
    if not coords or type(coords) ~= "vector3" then
        print("^1[Fire Module] ERROR: Invalid coordinates^0")
        return false
    end

    -- Validierung: Existiert die Brandklasse?
    if not Config.Fire.Classes[class] then
        print(string.format("^3[Fire Module] WARNING: Unknown fire class '%s', using 'A'^0", class))
        class = 'A'
    end

    -- Validierung: Performance-Limit
    if CountActiveFires() >= Config.Fire.MaxActiveFirePoints then
        if source then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 100, 0 },
                multiline = true,
                args = { "System", string.format("Maximale Feueranzahl erreicht (%d)", Config.Fire.MaxActiveFirePoints) }
            })
        end
        print("^3[Fire Module] WARNING: Max fire points reached!^0")
        return false
    end

    -- =============================================================================
    -- STORAGE INTEGRATION
    -- =============================================================================

    -- Zähle total gespawnte Feuer
    local function IncrementFireCounter()
        local current = Storage.GetModuleData('fire', 'total_fires_spawned', 0)
        Storage.SetModuleData('fire', 'total_fires_spawned', current + 1)
    end

    -- In CreateFire() Funktion, NACH dem erfolgreichen Spawn:
    -- (Suche nach "return fireId" und füge DAVOR ein:)

    -- Statistik updaten
    IncrementFireCounter()

    -- ==========================================================================
    -- FEUER ERSTELLEN
    -- ==========================================================================

    local fireId = fireIdCounter
    fireIdCounter = fireIdCounter + 1 -- Nächste ID vorbereiten

    -- Feuer-Datenstruktur
    local fireData = {
        id = fireId,
        coords = coords,
        class = class,
        intensity = intensity or 1.0,
        radius = radius or 2.0,
        createdAt = os.time(),   -- Unix Timestamp
        createdBy = source or 0, -- Wer hat es erstellt? (0 = System)
        extinguished = false     -- Für Statistiken
    }

    -- In Server-Tabelle speichern
    activeFires[fireId] = fireData

    -- ==========================================================================
    -- AN ALLE CLIENTS SENDEN
    -- ==========================================================================
    -- WICHTIG: -1 = ALL CLIENTS
    -- WARUM nicht TriggerClientEvent für jeden Spieler einzeln?
    -- Performance! -1 ist optimiert in der FiveM-Engine

    TriggerClientEvent(Events.Fire.Create, -1, fireData)

    if Config.Fire.Debug then
        print(string.format(
            "^2[Fire Module] Fire #%d created at %s (Class: %s, By: %s)^0",
            fireId,
            tostring(coords),
            class,
            source and GetPlayerName(source) or "System"
        ))
    end

    -- Starte Ausbreitungs-Check für dieses Feuer (nur wenn enabled)
    if Config.Fire.EnableSpreading and not spreadManagerRunning then
        StartGlobalSpreadManager()
    end
    IncrementFireCounter()

    return fireId -- Return ID für weitere Verarbeitung
end

-- Event registrieren
RegisterNetEvent(Events.Fire.RequestCreate)
AddEventHandler(Events.Fire.RequestCreate, function(coords, class, intensity, radius)
    -- source = Der Spieler der das Event gesendet hat (automatisch von FiveM)
    CreateFire(coords, class, intensity, radius, source)
end)

-- =============================================================================
-- FIRE SPREADING - OPTIMIZED (Ersetze das alte System)
-- =============================================================================



function StartGlobalSpreadManager()
    --[[
        WARUM besser?
        - 1 Thread statt 50 Threads
        - Läuft nur wenn Spreading enabled
        - Kann pausiert werden
    ]]

    if spreadManagerRunning then return end
    if not Config.Fire.EnableSpreading then return end

    spreadManagerRunning = true

    Citizen.CreateThread(function()
        print("^2[Fire Module] Spread Manager started^0")

        while spreadManagerRunning and Config.Fire.EnableSpreading do
            -- Check alle aktiven Feuer
            local activeCount = CountActiveFires()

            -- OPTIMIZATION: Skip wenn keine Feuer
            if activeCount == 0 then
                Citizen.Wait(10000) -- 10 Sekunden warten
                goto continue
            end

            -- Check jedes Feuer
            for fireId, fire in pairs(activeFires) do
                if fire.extinguished then
                    goto continue_fire
                end

                -- Max-Feuer erreicht? Skip spreading
                if CountActiveFires() >= Config.Fire.MaxActiveFirePoints then
                    goto continue_fire
                end

                local classData = Config.Fire.Classes[fire.class]
                local spreadChance = classData.spreadRate * 0.1

                if math.random() < spreadChance then
                    -- Spawn neues Feuer
                    local angle = math.random() * 2 * math.pi
                    local distance = math.random() * Config.Fire.SpreadDistance

                    local newCoords = vector3(
                        fire.coords.x + math.cos(angle) * distance,
                        fire.coords.y + math.sin(angle) * distance,
                        fire.coords.z
                    )

                    CreateFire(newCoords, fire.class, fire.intensity * 0.8, fire.radius * 0.9, nil)
                end

                ::continue_fire::
            end

            Citizen.Wait(Config.Fire.SpreadCheckInterval)

            ::continue::
        end

        spreadManagerRunning = false
        print("^3[Fire Module] Spread Manager stopped^0")
    end)
end

function StopGlobalSpreadManager()
    spreadManagerRunning = false
end

-- =============================================================================
-- FIRE EXTINGUISHING
-- =============================================================================

function ExtinguishFire(fireId, source)
    return ErrorHandler.SafeCall(function()
        if not activeFires[fireId] then
            if Config.Fire.Debug then
                print(string.format("^3[Fire Module] Fire #%d doesn't exist or already extinguished^0", fireId))
            end
            return false
        end

        local fire = activeFires[fireId]

        TriggerClientEvent(Events.Fire.Extinguish, -1, fireId)

        if Config.Fire.Debug then
            print(string.format(
                "^3[Fire Module] Fire #%d extinguished (By: %s)^0",
                fireId,
                source and GetPlayerName(source) or "System"
            ))
        end

        activeFires[fireId] = nil

        return true
    end, function(err)
        ErrorHandler.Error('Fire', 'Failed to extinguish fire', { fireId = fireId, error = err })
    end)
end

RegisterNetEvent(Events.Fire.RequestExtinguish)
AddEventHandler(Events.Fire.RequestExtinguish, function(fireId)
    ExtinguishFire(fireId, source)
end)


-- =============================================================================
-- AUTO-EXTINGUISH SERVER UPDATE - Ersetze AttemptExtinguish Event Handler
-- =============================================================================

RegisterNetEvent(Events.Fire.AttemptExtinguish)
AddEventHandler(Events.Fire.AttemptExtinguish, function(fireId, weaponHash)
    ErrorHandler.SafeCall(function()
        local fire = activeFires[fireId]
        if not fire then
            ErrorHandler.Warning('Fire', 'Attempt to extinguish non-existent fire', { fireId = fireId })
            return
        end

        -- =======================================================================
        -- WEAPON EFFECTIVENESS SYSTEM 🔥
        -- =======================================================================

        -- Hol Weapon-Daten
        local weaponData = GetEquipmentWeapon(weaponHash)

        if not weaponData then
            if Config.Fire.Debug then
                print(string.format("^1[Fire] Unknown weapon hash: %s^0", weaponHash))
            end
            return
        end

        -- Hol Brandklassen-Daten
        local fireClass = fire.class
        local effectiveness = weaponData.effectiveness[fireClass] or 0.0

        if Config.Fire.Debug then
            print(string.format(
                "^3[Fire] %s vs Fire #%d (Class %s): %.0f%% effective^0",
                weaponData.label,
                fireId,
                fireClass,
                effectiveness * 100
            ))
        end

        -- =======================================================================
        -- EFFECTIVENESS CHECK
        -- =======================================================================

        if effectiveness <= 0.0 then
            -- WIRKUNGSLOS!
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 50, 50 },
                args = { "Feuerwehr", string.format(
                    "%s ist WIRKUNGSLOS gegen Brandklasse %s!",
                    weaponData.label,
                    fireClass
                ) }
            })
            return
        end

        if effectiveness < 0.5 then
            -- WENIG EFFEKTIV (Warnung)
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 150, 0 },
                args = { "Feuerwehr", string.format(
                    "⚠️ %s ist NICHT optimal für Klasse %s!",
                    weaponData.label,
                    fireClass
                ) }
            })
        end

        -- =======================================================================
        -- FIRE INTENSITY REDUCTION
        -- =======================================================================

        -- Berechne Reduktion basierend auf Effectiveness + ExtinguishRate
        local baseReduction = weaponData.extinguishRate or 0.3
        local effectiveReduction = baseReduction * effectiveness

        -- Alte Intensity speichern für Feedback
        local oldIntensity = fire.intensity

        -- Neue Intensity berechnen
        fire.intensity = fire.intensity - effectiveReduction

        if Config.Fire.Debug then
            print(string.format(
                "^3[Fire] Intensity: %.2f → %.2f (-%0.2f)^0",
                oldIntensity,
                fire.intensity,
                effectiveReduction
            ))
        end

        -- =======================================================================
        -- FIRE GELÖSCHT?
        -- =======================================================================

        if fire.intensity <= 0 then
            -- KOMPLETT GELÖSCHT! 🎉
            ExtinguishFire(fireId, source)

            TriggerClientEvent('chat:addMessage', source, {
                color = { 0, 255, 0 },
                args = { "Feuerwehr", "✅ Feuer erfolgreich gelöscht! +50 XP" }
            })

            -- TODO: XP System hinzufügen
            -- AddPlayerXP(source, 50)
        else
            -- Noch nicht gelöscht, Update senden
            TriggerClientEvent(Events.Fire.Update, -1, fireId, fire)

            -- Feedback
            local percentRemaining = (fire.intensity / oldIntensity) * 100

            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 200, 0 },
                args = { "Feuerwehr", string.format(
                    "Feuer reduziert! Noch %.0f%% übrig",
                    percentRemaining
                ) }
            })
        end
    end, function(err)
        ErrorHandler.Error('Fire', 'Failed to attempt extinguish', { fireId = fireId, error = err })
    end)
end)

-- =============================================================================
-- ADMIN COMMANDS
-- =============================================================================

-- COMMAND: /firespawn
RegisterCommand('firespawn', function(source, args, rawCommand)
    -- Permission-Check
    if not Permissions.HasPermission(source, 'admin') then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 0 },
            args = { "System", "Keine Berechtigung!" }
        })
        return
    end

    --[[
        Usage: /firespawn [class] [intensity] [radius]
        Beispiel: /firespawn B 1.5 5.0
    ]]

    local class = args[1] or 'A'
    local intensity = tonumber(args[2]) or 1.0
    local radius = tonumber(args[3]) or 2.0

    -- Spieler-Position holen
    local playerPed = GetPlayerPed(source)
    local coords = GetEntityCoords(playerPed)

    -- Vor dem Spieler spawnen (nicht auf ihm!)
    local heading = GetEntityHeading(playerPed)
    local forwardVector = vector3(
        math.sin(math.rad(heading)) * 5.0, -- 5 Meter vor dem Spieler
        math.cos(math.rad(heading)) * 5.0,
        0.0
    )

    local spawnCoords = coords + forwardVector

    local fireId = CreateFire(spawnCoords, class, intensity, radius, source)

    if fireId then
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 150, 0 },
            args = { "Fire", string.format("Feuer #%d gespawnt (Klasse: %s)", fireId, class) }
        })
    end
end, false)

-- COMMAND: /fireextinguish [fireId]
RegisterCommand('fireextinguish', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        return
    end

    local fireId = tonumber(args[1])

    if not fireId then
        -- Alle Feuer löschen
        local count = 0
        for id, _ in pairs(activeFires) do
            ExtinguishFire(id, source)
            count = count + 1
        end

        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            args = { "Fire", string.format("Alle Feuer gelöscht (%d)", count) }
        })
    else
        -- Spezifisches Feuer löschen
        if ExtinguishFire(fireId, source) then
            TriggerClientEvent('chat:addMessage', source, {
                color = { 0, 255, 0 },
                args = { "Fire", string.format("Feuer #%d gelöscht", fireId) }
            })
        end
    end
end, false)

-- COMMAND: /firelist
RegisterCommand('firelist', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        return
    end

    local count = 0
    for _, fire in pairs(activeFires) do
        if not fire.extinguished then
            count = count + 1
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 150, 0 },
                args = { "Fire #" .. fire.id, string.format(
                    "Klasse: %s | Intensität: %.1f | Radius: %.1f",
                    fire.class,
                    fire.intensity,
                    fire.radius
                ) }
            })
        end
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 255, 255 },
        args = { "System", string.format("Aktive Feuer: %d / %d", count, Config.Fire.MaxActiveFirePoints) }
    })
end, false)

-- =============================================================================
-- PERSISTENCE - Speichern & Laden (KORRIGIERT)
-- =============================================================================

function SaveFires()
    --[[
        WICHTIG: Nur AKTIVE Feuer speichern!
        Gelöschte Feuer (extinguished = true) werden NICHT gespeichert
        Das verhindert dass die JSON-Datei riesig wird
    ]]

    -- Filtern: Nur aktive Feuer
    local activeFiresToSave = {}
    for fireId, fire in pairs(activeFires) do
        if not fire.extinguished then
            activeFiresToSave[fireId] = fire
        end
    end

    -- Konvertiere zu JSON
    local fireData = json.encode(activeFiresToSave)

    -- Speichere in Ressource-Ordner
    SaveResourceFile(GetCurrentResourceName(), "data/fires.json", fireData, -1)

    if Config.Fire.Debug then
        local totalCount = 0
        local savedCount = 0
        for _, fire in pairs(activeFires) do
            totalCount = totalCount + 1
            if not fire.extinguished then
                savedCount = savedCount + 1
            end
        end
        print(string.format(
            "^2[Fire Module] Saved %d active fires (total: %d, skipped: %d extinguished)^0",
            savedCount,
            totalCount,
            totalCount - savedCount
        ))
    end
end

function LoadPersistedFires()
    local fireData = LoadResourceFile(GetCurrentResourceName(), "data/fires.json")

    if not fireData then
        print("^3[Fire Module] No persisted fires found^0")
        return
    end

    local loadedFires = json.decode(fireData)

    -- WICHTIG: Nur aktive Feuer laden
    local loadedCount = 0
    for fireId, fire in pairs(loadedFires) do
        if not fire.extinguished then
            activeFires[fireId] = fire

            -- An alle verbundene Clients senden
            TriggerClientEvent(Events.Fire.Create, -1, fire)

            -- Spreading (falls enabled)
            if Config.Fire.EnableSpreading and not spreadManagerRunning then
                StartGlobalSpreadManager()
            end

            loadedCount = loadedCount + 1

            -- FireIdCounter anpassen
            if fire.id >= fireIdCounter then
                fireIdCounter = fire.id + 1
            end
        end
    end

    print(string.format("^2[Fire Module] Loaded %d persisted fires^0", loadedCount))
end

function StartAutoSave()
    -- Alle 5 Minuten automatisch speichern
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(300000) -- 5 Minuten
            SaveFires()
        end
    end)
end

-- Beim Ressource-Stop speichern
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SaveFires()
        print("^2[Fire Module] Shutdown complete - fires saved^0")
    end
end)

-- =============================================================================
-- DEBUGGING & ANALYTICS
-- =============================================================================

-- Admin-Command für Statistiken
RegisterCommand('firestats', function(source, args, rawCommand)
    if not Permissions.HasPermission(source, 'admin') then
        return
    end

    local totalFires = 0
    local activeCount = 0
    local extinguishedCount = 0
    local classCounts = {}

    for _, fire in pairs(activeFires) do
        totalFires = totalFires + 1

        if fire.extinguished then
            extinguishedCount = extinguishedCount + 1
        else
            activeCount = activeCount + 1
        end

        classCounts[fire.class] = (classCounts[fire.class] or 0) + 1
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 200, 0 },
        multiline = true,
        args = { "Fire Statistics", string.format(
            "Total: %d | Active: %d | Gelöscht: %d\n" ..
            "Klasse A: %d | Klasse B: %d | Klasse C: %d",
            totalFires, activeCount, extinguishedCount,
            classCounts['A'] or 0,
            classCounts['B'] or 0,
            classCounts['C'] or 0
        ) }
    })
end, false)

-- Admin-Command zum Debuggen
RegisterCommand('firedebug', function(source, args, rawCommand)
    Config.Fire.Debug = not Config.Fire.Debug
    print(string.format("^2[Fire Module] Debugging %s^0", Config.Fire.Debug and "enabled" or "disabled"))
end, false)
