-- =============================================================================
-- FIRE MODULE - CONFIGURATION
-- =============================================================================

Config = Config or {}
Config.Fire = {
    -- Modul-Status
    Enabled = true,

    -- Debug-Modus (zeigt zusätzliche Infos)
    Debug = true,

    -- ==========================================================================
    -- BRANDKLASSEN (nach europäischem Standard)
    -- ==========================================================================
    -- WARUM verschiedene Klassen?
    -- Unterschiedliche Feuer brauchen unterschiedliche Löschmittel (Realismus!)
    Classes = {
        ['A'] = {                                          -- Feste Stoffe (Holz, Papier, Textilien)
            name = "Klasse A - Feste Stoffe",
            color = { 255, 150, 0 },                       -- Orange-Gelb
            spreadRate = 1.5,                              -- Wie schnell breitet es sich aus? (Multiplikator)
            smokeIntensity = 0.7,                          -- Wie viel Rauch? (0.0 - 1.0)
            extinguishers = { 'water', 'foam', 'powder' }, -- Was löscht es?
            heatIntensity = 0.6                            -- Hitze-Multiplikator
        },
        ['B'] = {                                          -- Flüssige Stoffe (Benzin, Öl, Alkohol)
            name = "Klasse B - Flüssigkeiten",
            color = { 255, 80, 0 },                        -- Dunkelrot
            spreadRate = 2.5,                              -- Breitet sich SCHNELL aus!
            smokeIntensity = 0.9,                          -- Viel schwarzer Rauch
            extinguishers = { 'foam', 'powder', 'co2' },
            heatIntensity = 0.9
        },
        ['C'] = {                               -- Gasförmige Stoffe (Propan, Methan, Acetylen)
            name = "Klasse C - Gase",
            color = { 100, 150, 255 },          -- Bläulich
            spreadRate = 3.0,                   -- Extrem schnell
            smokeIntensity = 0.4,               -- Weniger sichtbarer Rauch
            extinguishers = { 'powder', 'co2' },
            heatIntensity = 1.2                 -- Sehr heiß!
        },
        ['D'] = {                               -- Metalle (Magnesium, Lithium - selten)
            name = "Klasse D - Metalle",
            color = { 255, 255, 200 },          -- Weiß-glühend
            spreadRate = 0.8,                   -- Langsamer
            smokeIntensity = 0.5,
            extinguishers = { 'metal_powder' }, -- Speziallöschmittel!
            heatIntensity = 1.5                 -- Extrem heiß
        },
        ['F'] = {                               -- Fette/Öle (Küchen)
            name = "Klasse F - Speiseöle",
            color = { 255, 100, 0 },
            spreadRate = 1.8,
            smokeIntensity = 0.8,
            extinguishers = { 'foam', 'fire_blanket' },
            heatIntensity = 0.8
        }
    },

    -- ==========================================================================
    -- FEUER-PHYSICS
    -- ==========================================================================
    SpreadDistance = 5.0,       -- Maximale Ausbreitungsdistanz in Metern
    SpreadCheckInterval = 2000, -- Alle 2 Sekunden prüfen (Performance!)
    MaxActiveFirePoints = 50,   -- Limit für Server-Performance

    -- WARUM Limits?
    -- Ein unkontrolliertes Feuer könnte den ganzen Server lahmlegen
    -- (100+ Feuer-Points = FPS-Drop für alle Spieler)
}
