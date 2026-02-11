-- =============================================================================
-- EQUIPMENT WEAPONS - Custom Weapon Definitions
-- =============================================================================

--[[
    WARUM Shared?
    - Client braucht Hash zum Equippen
    - Server braucht Info für Effectiveness-Berechnung
    - Zentrale Definition = DRY Principle

    WICHTIG:
    - Nutzt jetzt CUSTOM WEAPONS (nicht mehr Tint-basiert!)
    - Jedes Tool hat eigenes Model (.ydr)
]]

EquipmentWeapons = {
    -- ==========================================================================
    -- WASSERLÖSCHER
    -- ==========================================================================
    WATER = {
        hash = GetHashKey('WEAPON_FIREEXTINGUISHER_WATER'),
        name = 'WEAPON_FIREEXTINGUISHER_WATER',
        label = 'Wasserlöscher',
        model = 'w_am_fire_exting_water', -- Custom Model!

        -- Effectiveness gegen Brandklassen
        effectiveness = {
            A = 1.0, -- Perfekt gegen feste Stoffe ✅
            B = 0.3, -- Schlecht gegen Flüssigkeiten ⚠️
            C = 0.0, -- GEFÄHRLICH bei Gas! (Wasser leitet) ❌
            D = 0.0, -- Nicht für Metalle ❌
            F = 0.5  -- OK gegen Speiseöle
        },

        -- Tool Properties
        range = 8.0,          -- Reichweite in Metern
        extinguishRate = 0.3, -- Intensity-Reduktion pro Sekunde
        ammo = 100,           -- Füllmenge
        description = "Klassischer Wasserlöscher. Effektiv gegen brennende feste Stoffe wie Holz, Papier, Textilien."
    },

    -- ==========================================================================
    -- SCHAUMLÖSCHER
    -- ==========================================================================
    FOAM = {
        hash = GetHashKey('WEAPON_FIREEXTINGUISHER_FOAM'),
        name = 'WEAPON_EXTINGUISHER_FOAM',
        label = 'Schaumlöscher',
        model = 'w_am_fire_exting_foam', -- Custom Model!

        effectiveness = {
            A = 0.8, -- Gut gegen feste Stoffe ✅
            B = 1.0, -- Perfekt gegen Flüssigkeiten! ✅
            C = 0.0, -- Nicht für Gase ❌
            D = 0.0, -- Nicht für Metalle ❌
            F = 0.9  -- Sehr gut gegen Fettbrände ✅
        },

        range = 6.0,
        extinguishRate = 0.25,
        ammo = 80,
        description = "Schaumlöscher mit Filmbildung. Ideal für brennende Flüssigkeiten wie Benzin oder Öl."
    },

    -- ==========================================================================
    -- CO2-LÖSCHER
    -- ==========================================================================
    CO2 = {
        hash = GetHashKey('WEAPON_FIREEXTINGUISHER_CO2'),
        name = 'WEAPON_EXTINGUISHER_CO2',
        label = 'CO2-Löscher',
        model = 'w_am_fire_exting_co2', -- Custom Model!

        effectiveness = {
            A = 0.4, -- Mittel gegen feste Stoffe (Rückzündung möglich) ⚠️
            B = 0.9, -- Sehr gut gegen Flüssigkeiten ✅
            C = 0.8, -- Gut gegen Gas ✅
            D = 0.0, -- GEFÄHRLICH bei Metallen! (reagiert) ❌
            F = 0.6  -- Befriedigend gegen Fettbrände
        },

        range = 5.0,
        extinguishRate = 0.35,
        ammo = 60, -- Weniger Kapazität
        description = "Kohlendioxid-Löscher. Erstickt Flammen ohne Rückstände. Ideal für Gasbrände und Elektronik."
    },

    -- ==========================================================================
    -- PULVERLÖSCHER (ABC)
    -- ==========================================================================
    POWDER = {
        hash = GetHashKey('WEAPON_FIREEXTINGUISHER_POWDER'),
        name = 'WEAPON_FIREEXTINGUISHER_POWDER',
        label = 'Pulverlöscher (ABC)',
        model = 'w_am_fire_exting_powder', -- Custom Model!

        effectiveness = {
            A = 0.9, -- Sehr gut gegen feste Stoffe ✅
            B = 0.9, -- Sehr gut gegen Flüssigkeiten ✅
            C = 1.0, -- PERFEKT gegen Gas! ✅
            D = 0.0, -- Nicht für Metalle (braucht D-Pulver) ❌
            F = 0.7  -- Gut gegen Fettbrände
        },

        range = 7.0,
        extinguishRate = 0.4, -- Schnellster Löscher!
        ammo = 90,
        description = "ABC-Pulverlöscher. Universell einsetzbar, auch bei Metallbränden begrenzt wirksam."
    }
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

function GetEquipmentWeapon(weaponHash)
    --[[
        Holt Weapon-Data anhand Hash

        BEISPIEL:
        local weapon = GetEquipmentWeapon(GetHashKey('WEAPON_EXTINGUISHER_WATER'))
        print(weapon.label)  -- "Wasserlöscher"
    ]]

    for _, weapon in pairs(EquipmentWeapons) do
        if weapon.hash == weaponHash then
            return weapon
        end
    end
    return nil
end

function GetEquipmentWeaponByName(weaponName)
    --[[
        Holt Weapon-Data anhand Name (Key)

        BEISPIEL:
        local weapon = GetEquipmentWeaponByName('WATER')
        print(weapon.effectiveness.A)  -- 1.0
    ]]

    return EquipmentWeapons[weaponName]
end

function GetWeaponEffectiveness(weaponHash, fireClass)
    --[[
        Berechnet Effectiveness eines Weapons gegen Brandklasse

        RETURN:
        - 0.0 - 1.0 = Effectiveness (0 = nutzlos, 1 = perfekt)
        - nil = Invalid weapon/class

        BEISPIEL:
        local eff = GetWeaponEffectiveness(waterHash, 'A')
        -- Returns: 1.0 (100% effektiv)
    ]]

    local weapon = GetEquipmentWeapon(weaponHash)
    if not weapon then return nil end

    return weapon.effectiveness[fireClass] or 0.0
end

function IsExtinguisher(weaponHash)
    --[[
        Check ob ein Weapon ein Feuerlöscher ist

        RETURN:
        - true/false
    ]]

    return GetEquipmentWeapon(weaponHash) ~= nil
end

function PrintAllWeapons()
    --[[
        Debug-Funktion: Gibt alle Weapons aus
    ]]

    print("^3========== EQUIPMENT WEAPONS ==========^0")

    for key, weapon in pairs(EquipmentWeapons) do
        print(string.format("^2[%s] %s^0", key, weapon.label))
        print(string.format("  Hash: %s", weapon.hash))
        print(string.format("  Model: %s", weapon.model))
        print(string.format("  Range: %.1fm", weapon.range))
        print(string.format("  Extinguish Rate: %.2f/s", weapon.extinguishRate))

        print("  Effectiveness:")
        for class, value in pairs(weapon.effectiveness) do
            local color = value >= 0.8 and "^2" or (value >= 0.5 and "^3" or "^1")
            print(string.format("    Class %s: %s%.0f%%^0", class, color, value * 100))
        end

        print("")
    end

    print("^3========================================^0")
end

-- =============================================================================
-- EXPORTS (für andere Scripts)
-- =============================================================================

exports('GetEquipmentWeapon', GetEquipmentWeapon)
exports('GetEquipmentWeaponByName', GetEquipmentWeaponByName)
exports('GetWeaponEffectiveness', GetWeaponEffectiveness)
exports('IsExtinguisher', IsExtinguisher)

-- =============================================================================
-- STARTUP
-- =============================================================================

if IsDuplicityVersion() then
    print("^2[Equipment Weapons - Server] Loaded^0")
    print(string.format("^2[Equipment Weapons] %d weapons registered^0", Utils.TableCount(EquipmentWeapons)))
else
    print("^2[Equipment Weapons - Client] Loaded^0")
end
