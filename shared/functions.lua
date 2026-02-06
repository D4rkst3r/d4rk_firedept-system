-- =============================================================================
-- SHARED UTILITIES - Funktionen die ÜBERALL gebraucht werden
-- =============================================================================

-- WARUM shared?
-- Diese Funktionen laufen sowohl auf Client ALS AUCH Server
-- Z.B. Table/Math Helpers werden überall gebraucht

Utils = {}

-- =============================================================================
-- TABLE UTILITIES
-- =============================================================================

-- WARUM diese Funktionen?
-- Lua's Standard-Library ist sehr minimalistisch
-- Diese Helpers machen dein Leben VIEL einfacher

function Utils.TableCount(tbl)
    --[[
        Problem: #table funktioniert nur bei Arrays
        Lösung: Zählt ALLE Keys (auch non-numeric)

        Beispiel:
        local t = {[1] = "a", [5] = "b", name = "test"}
        print(#t)                    -- Könnte 0, 1, oder 5 sein! Unvorhersehbar
        print(Utils.TableCount(t))   -- Immer 3!
    ]]

    if not tbl or type(tbl) ~= "table" then
        return 0
    end

    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Utils.TableContains(tbl, value)
    --[[
        Check ob ein Wert in einer Table ist

        Beispiel:
        local tools = {'water', 'foam', 'co2'}
        if Utils.TableContains(tools, 'water') then
            print("Wasser verfügbar!")
        end
    ]]

    if not tbl then return false end

    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function Utils.TableCopy(orig)
    --[[
        WARUM wichtig?
        In Lua sind Tables IMMER Referenzen!

        Problem:
        local a = {x = 1}
        local b = a
        b.x = 2
        print(a.x)  -- 2! a wurde auch verändert!

        Lösung:
        local a = {x = 1}
        local b = Utils.TableCopy(a)
        b.x = 2
        print(a.x)  -- 1 (unverändert)
    ]]

    if type(orig) ~= 'table' then return orig end

    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = type(v) == 'table' and Utils.TableCopy(v) or v
    end
    return copy
end

function Utils.TableMerge(t1, t2)
    --[[
        Kombiniert zwei Tables
        t2 überschreibt Werte von t1
    ]]

    local result = Utils.TableCopy(t1)
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

-- =============================================================================
-- MATH UTILITIES
-- =============================================================================

function Utils.Round(num, decimals)
    --[[
        Rundet auf N Dezimalstellen

        Beispiel:
        Utils.Round(3.14159, 2)  -- 3.14
        Utils.Round(123.456, 0)  -- 123
    ]]

    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

function Utils.Clamp(value, min, max)
    --[[
        Begrenzt einen Wert zwischen min und max

        Beispiel:
        Utils.Clamp(150, 0, 100)  -- 100 (nicht höher als max)
        Utils.Clamp(-5, 0, 100)   -- 0 (nicht niedriger als min)
        Utils.Clamp(50, 0, 100)   -- 50 (innerhalb range)
    ]]

    return math.max(min, math.min(max, value))
end

function Utils.Distance(coords1, coords2)
    --[[
        Berechnet Distanz zwischen zwei Punkten
        Funktioniert mit vector3 oder {x, y, z} Tables

        WARUM eigene Funktion?
        Manchmal haben wir vector3, manchmal tables
        Diese Funktion funktioniert mit beiden!
    ]]

    if not coords1 or not coords2 then return 0 end

    local x1 = coords1.x or coords1[1]
    local y1 = coords1.y or coords1[2]
    local z1 = coords1.z or coords1[3]

    local x2 = coords2.x or coords2[1]
    local y2 = coords2.y or coords2[2]
    local z2 = coords2.z or coords2[3]

    return math.sqrt(
        (x2 - x1) ^ 2 +
        (y2 - y1) ^ 2 +
        (z2 - z1) ^ 2
    )
end

function Utils.Distance2D(coords1, coords2)
    -- Wie Distance, aber ignoriert Z-Achse (Höhe)
    -- Nützlich für "ist Spieler auf gleicher Ebene?"

    if not coords1 or not coords2 then return 0 end

    local x1 = coords1.x or coords1[1]
    local y1 = coords1.y or coords1[2]

    local x2 = coords2.x or coords2[1]
    local y2 = coords2.y or coords2[2]

    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- =============================================================================
-- STRING UTILITIES
-- =============================================================================

function Utils.Trim(str)
    -- Entfernt Leerzeichen am Anfang/Ende
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end

function Utils.Split(str, delimiter)
    --[[
        Teilt String an delimiter

        Beispiel:
        Utils.Split("apple,banana,orange", ",")
        -- {"apple", "banana", "orange"}
    ]]

    if not str then return {} end

    delimiter = delimiter or ","
    local result = {}

    for part in string.gmatch(str, "([^" .. delimiter .. "]+)") do
        table.insert(result, Utils.Trim(part))
    end

    return result
end

function Utils.StartsWith(str, prefix)
    if not str or not prefix then return false end
    return str:sub(1, #prefix) == prefix
end

function Utils.EndsWith(str, suffix)
    if not str or not suffix then return false end
    return str:sub(- #suffix) == suffix
end

-- =============================================================================
-- TIME UTILITIES
-- =============================================================================

function Utils.FormatTime(seconds)
    --[[
        Konvertiert Sekunden zu lesbarem Format

        Beispiel:
        Utils.FormatTime(90)    -- "1:30"
        Utils.FormatTime(3665)  -- "1:01:05"
    ]]

    if not seconds or seconds < 0 then return "0:00" end

    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, mins, secs)
    else
        return string.format("%d:%02d", mins, secs)
    end
end

function Utils.GetTimestamp()
    -- Unix Timestamp (Sekunden seit 1970)
    return os.time()
end

function Utils.GetGameTime()
    -- FiveM Game Timer (Millisekunden seit Script-Start)
    -- NUR CLIENT-SIDE verfügbar!
    if IsDuplicityVersion() then -- Server check
        return 0
    end
    return GetGameTimer()
end

-- =============================================================================
-- VALIDATION UTILITIES
-- =============================================================================

function Utils.IsVector3(value)
    -- Check ob etwas ein vector3 ist
    return type(value) == "vector3" or
        (type(value) == "table" and value.x and value.y and value.z)
end

function Utils.IsValidCoords(coords)
    -- Check ob Koordinaten gültig sind
    if not Utils.IsVector3(coords) then return false end

    local x = coords.x or coords[1]
    local y = coords.y or coords[2]
    local z = coords.z or coords[3]

    -- GTA5 Map ist ca. -4000 bis +8000
    return x and y and z and
        x >= -4000 and x <= 8000 and
        y >= -4000 and y <= 8000 and
        z >= -500 and z <= 1500
end

-- =============================================================================
-- DEBUG UTILITIES
-- =============================================================================

function Utils.DumpTable(tbl, indent)
    --[[
        Gibt Table-Inhalt in Console aus
        EXTREM nützlich für Debugging!

        Beispiel:
        local myData = {name = "Test", values = {1, 2, 3}}
        Utils.DumpTable(myData)

        Output:
        {
          name = "Test",
          values = {
            [1] = 1,
            [2] = 2,
            [3] = 3
          }
        }
    ]]

    if type(tbl) ~= "table" then
        print(tostring(tbl))
        return
    end

    indent = indent or 0
    local indentStr = string.rep("  ", indent)

    print(indentStr .. "{")
    for k, v in pairs(tbl) do
        local keyStr = type(k) == "number" and "[" .. k .. "]" or k

        if type(v) == "table" then
            print(indentStr .. "  " .. keyStr .. " = ")
            Utils.DumpTable(v, indent + 1)
        else
            local valueStr = type(v) == "string" and '"' .. v .. '"' or tostring(v)
            print(indentStr .. "  " .. keyStr .. " = " .. valueStr)
        end
    end
    print(indentStr .. "}")
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

-- Für andere Ressourcen
if IsDuplicityVersion() then
    -- Server
    exports('TableCount', Utils.TableCount)
    exports('Round', Utils.Round)
    exports('Distance', Utils.Distance)
else
    -- Client
    exports('TableCount', Utils.TableCount)
    exports('Round', Utils.Round)
    exports('Distance', Utils.Distance)
end

-- =============================================================================
-- STARTUP
-- =============================================================================

if IsDuplicityVersion() then
    print("^2[Utils - Server] Loaded^0")
else
    print("^2[Utils - Client] Loaded^0")
end
