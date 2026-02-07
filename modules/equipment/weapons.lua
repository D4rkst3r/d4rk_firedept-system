-- =============================================================================
-- EQUIPMENT WEAPONS - Custom Weapon Definitions
-- =============================================================================

EquipmentWeapons = {
    -- =========================================================================
    -- WASSERLÖSCHER
    -- =========================================================================
    WATER = {
        hash = GetHashKey('WEAPON_EXTINGUISHER_WATER'),
        name = 'WEAPON_EXTINGUISHER_WATER',
        label = 'Wasserlöscher',
        model = 'w_am_fire_exting_water',

        effectiveness = {
            A = 1.0,
            B = 0.3,
            C = 0.0,
            D = 0.0,
            F = 0.5
        },

        ammo = 100,
        range = 8.0,
        extinguishRate = 0.3
    },

    -- =========================================================================
    -- SCHAUMLÖSCHER
    -- =========================================================================
    FOAM = {
        hash = GetHashKey('WEAPON_EXTINGUISHER_FOAM'),
        name = 'WEAPON_EXTINGUISHER_FOAM',
        label = 'Schaumlöscher',
        model = 'w_am_fire_exting_foam',

        effectiveness = {
            A = 0.9,
            B = 1.0,
            C = 0.0,
            D = 0.0,
            F = 0.8
        },

        ammo = 100,
        range = 7.0,
        extinguishRate = 0.35
    },

    -- =========================================================================
    -- CO2-LÖSCHER
    -- =========================================================================
    CO2 = {
        hash = GetHashKey('WEAPON_EXTINGUISHER_CO2'),
        name = 'WEAPON_EXTINGUISHER_CO2',
        label = 'CO2-Löscher',
        model = 'w_am_fire_exting_co2',

        effectiveness = {
            A = 0.4,
            B = 1.0,
            C = 1.0,
            D = 0.0,
            F = 0.6
        },

        ammo = 80,
        range = 6.0,
        extinguishRate = 0.4
    },

    -- =========================================================================
    -- PULVERLÖSCHER
    -- =========================================================================
    POWDER = {
        hash = GetHashKey('WEAPON_EXTINGUISHER_POWDER'),
        name = 'WEAPON_EXTINGUISHER_POWDER',
        label = 'Pulverlöscher',
        model = 'w_am_fire_exting_powder',

        effectiveness = {
            A = 0.8,
            B = 0.8,
            C = 0.8,
            D = 0.6,
            F = 0.7
        },

        ammo = 120,
        range = 7.0,
        extinguishRate = 0.25
    },

    -- =========================================================================
    -- FEUERWEHRAXT
    -- =========================================================================
    AXE = {
        hash = GetHashKey('WEAPON_HATCHET'),
        name = 'WEAPON_HATCHET',
        label = 'Feuerwehraxt',
        model = 'prop_ld_fireaxe',

        effectiveness = {},

        ammo = 1,
        range = 2.0,
        extinguishRate = 0.0
    }
}

-- Helper Functions
function GetEquipmentWeapon(weaponHash)
    for _, weapon in pairs(EquipmentWeapons) do
        if weapon.hash == weaponHash then
            return weapon
        end
    end
    return nil
end

function GetEquipmentWeaponByItem(itemId)
    if not Config.Equipment.Items[itemId] then
        return nil
    end

    local weaponType = Config.Equipment.Items[itemId].weapon
    return EquipmentWeapons[weaponType]
end
