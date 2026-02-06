-- =============================================================================
-- EQUIPMENT MODULE - CONFIGURATION
-- =============================================================================

Config = Config or {}
Config.Equipment = {
    -- Modul-Status
    Enabled = true,

    -- Debug-Modus
    Debug = true,

    -- ==========================================================================
    -- EQUIPMENT DEFINITIONEN
    -- ==========================================================================
    --[[
        WARUM Props definieren?
        - GTA V hat hunderte Props
        - Wir brauchen genau die richtigen für Feuerwehr
        - Hash = Performance-optimiert
    ]]

    Items = {
        -- ==========================================================================
        -- FEUERLÖSCHER (Handheld Extinguishers)
        -- ==========================================================================

        ['extinguisher_water'] = {
            name = "Wasserlöscher",
            description = "Effektiv gegen Brandklasse A",

            -- Prop-Daten
            prop = 'prop_fire_exting_1a',                 -- GTA V Prop-Name
            propHash = GetHashKey('prop_fire_exting_1a'), -- Hash für Performance

            -- Attachment (wo am Spieler?)
            bone = 28422,                        -- BONETAG_R_PH_HAND (Rechte Hand)
            offset = vector3(0.12, 0.0, 0.03),   -- Position-Offset
            rotation = vector3(-90.0, 0.0, 0.0), -- Rotation

            -- Tool-Stats
            effectiveness = {
                A = 1.0, -- 100% effektiv gegen Klasse A
                B = 0.3, -- 30% effektiv gegen Klasse B
                C = 0.0, -- Nicht effektiv gegen Klasse C
                D = 0.0,
                F = 0.5  -- 50% effektiv gegen Klasse F
            },

            -- Gameplay
            range = 5.0,      -- Reichweite in Metern
            cooldown = 1000,  -- 1 Sekunde zwischen Nutzungen
            durability = 100, -- 100 Nutzungen (optional für später)

            -- Animation
            animDict = 'weapons@first_person@aim_rng@generic@projectile@thermal_charge@',
            animName = 'plant_floor',
            animDuration = 3000
        },

        ['extinguisher_foam'] = {
            name = "Schaumlöscher",
            description = "Effektiv gegen Brandklasse A & B",

            prop = 'prop_fire_exting_2a',
            propHash = GetHashKey('prop_fire_exting_2a'),

            bone = 28422,
            offset = vector3(0.12, 0.0, 0.03),
            rotation = vector3(-90.0, 0.0, 0.0),

            effectiveness = {
                A = 0.9, -- 90% effektiv
                B = 1.0, -- 100% effektiv gegen Flüssigkeiten
                C = 0.0,
                D = 0.0,
                F = 0.8
            },

            range = 5.0,
            cooldown = 1000,
            durability = 100,

            animDict = 'weapons@first_person@aim_rng@generic@projectile@thermal_charge@',
            animName = 'plant_floor',
            animDuration = 3000
        },

        ['extinguisher_co2'] = {
            name = "CO2-Löscher",
            description = "Effektiv gegen Brandklasse B & C",

            prop = 'prop_fire_exting_3a',
            propHash = GetHashKey('prop_fire_exting_3a'),

            bone = 28422,
            offset = vector3(0.12, 0.0, 0.03),
            rotation = vector3(-90.0, 0.0, 0.0),

            effectiveness = {
                A = 0.4, -- Schlecht gegen feste Stoffe
                B = 1.0, -- Perfekt gegen Flüssigkeiten
                C = 1.0, -- Perfekt gegen Gase
                D = 0.0,
                F = 0.6
            },

            range = 4.0,     -- Kürzere Reichweite
            cooldown = 1000,
            durability = 80, -- Weniger Kapazität

            animDict = 'weapons@first_person@aim_rng@generic@projectile@thermal_charge@',
            animName = 'plant_floor',
            animDuration = 3000
        },

        ['extinguisher_powder'] = {
            name = "Pulverlöscher",
            description = "Universal-Löscher (A, B, C)",

            prop = 'prop_fire_exting_1b',
            propHash = GetHashKey('prop_fire_exting_1b'),

            bone = 28422,
            offset = vector3(0.12, 0.0, 0.03),
            rotation = vector3(-90.0, 0.0, 0.0),

            effectiveness = {
                A = 0.8, -- Gut gegen alles
                B = 0.8,
                C = 0.8,
                D = 0.6, -- Etwas effektiv gegen Metalle
                F = 0.7
            },

            range = 5.0,
            cooldown = 1000,
            durability = 120, -- Mehr Kapazität

            animDict = 'weapons@first_person@aim_rng@generic@projectile@thermal_charge@',
            animName = 'plant_floor',
            animDuration = 3000
        },

        -- ==========================================================================
        -- TOOLS (für später - Axt, Halligan Bar, etc.)
        -- ==========================================================================

        ['fire_axe'] = {
            name = "Feuerwehraxt",
            description = "Zum Aufbrechen von Türen",

            prop = 'prop_ld_fireaxe',
            propHash = GetHashKey('prop_ld_fireaxe'),

            bone = 28422,
            offset = vector3(0.1, -0.02, 0.0),
            rotation = vector3(-90.0, 0.0, 0.0),

            effectiveness = {}, -- Kein Löschmittel

            range = 2.0,
            cooldown = 2000,

            animDict = 'melee@large_wpn@streamed_core',
            animName = 'ground_attack_on_spot',
            animDuration = 2000
        }
    },

    -- ==========================================================================
    -- XP & PROGRESSION (für später)
    -- ==========================================================================

    XP = {
        fireExtinguished = 50,  -- XP pro gelöschtem Feuer
        correctToolBonus = 25,  -- Bonus für richtiges Tool
        wrongToolPenalty = -10, -- Penalty für falsches Tool
        teamworkBonus = 10      -- Bonus wenn mehrere Spieler helfen
    }
}
