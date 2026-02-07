-- =============================================================================
-- EQUIPMENT MODULE - CONFIGURATION (SIMPLIFIED - WEAPON BASED)
-- =============================================================================

Config = Config or {}
Config.Equipment = {
    -- Modul-Status
    Enabled = true,

    -- Debug-Modus
    Debug = true,

    -- ==========================================================================
    -- WEAPON-BASED EQUIPMENT (Viel einfacher!)
    -- ==========================================================================

    -- WICHTIG: Diese IDs matchen mit EquipmentWeapons Keys
    Items = {
        ['extinguisher_water'] = {
            name = "Wasserlöscher",
            weapon = 'WATER', -- ← Referenz zu EquipmentWeapons
        },

        ['extinguisher_foam'] = {
            name = "Schaumlöscher",
            weapon = 'FOAM',
        },

        ['extinguisher_co2'] = {
            name = "CO2-Löscher",
            weapon = 'CO2',
        },

        ['extinguisher_powder'] = {
            name = "Pulverlöscher",
            weapon = 'POWDER',
        },

        ['fire_axe'] = {
            name = "Feuerwehraxt",
            weapon = 'AXE',
        }
    },

    -- ==========================================================================
    -- XP & PROGRESSION
    -- ==========================================================================

    XP = {
        fireExtinguished = 50,
        correctToolBonus = 25,
        wrongToolPenalty = -10,
        teamworkBonus = 10
    }
}
