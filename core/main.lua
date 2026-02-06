-- =============================================================================
-- CORE SYSTEM - Module Loader & Manager
-- =============================================================================

-- WARUM lokale Variablen?
-- Performance: Lokale Variablen sind ~2x schneller als globale in Lua
-- Sicherheit: Andere Scripts können sie nicht überschreiben
local ModuleSystem = {
    modules = {},       -- Geladene Module
    activeModules = {}, -- Aktuell aktive Module
    config = {}         -- Runtime-Config
}

-- =============================================================================
-- MODUL REGISTRIERUNG
-- =============================================================================

-- WARUM diese Funktion?
-- Module registrieren sich selbst beim Core (lose Kopplung)
-- Der Core weiß nicht im Voraus, welche Module existieren
function RegisterModule(moduleName, moduleData)
    if not moduleName or not moduleData then
        print("^1[FD-System] ERROR: Module registration failed - missing data^0")
        return false
    end

    -- WARUM diese Prüfung?
    -- Verhindert doppelte Registrierung (Bug-Prevention)
    if ModuleSystem.modules[moduleName] then
        print("^3[FD-System] WARNING: Module '" .. moduleName .. "' already registered^0")
        return false
    end

    ModuleSystem.modules[moduleName] = moduleData
    print("^2[FD-System] Module '" .. moduleName .. "' registered successfully^0")

    -- Modul sofort aktivieren wenn enabled
    if moduleData.enabled then
        ActivateModule(moduleName)
    end

    return true
end

-- =============================================================================
-- MODUL AKTIVIERUNG/DEAKTIVIERUNG
-- =============================================================================

function ActivateModule(moduleName)
    local module = ModuleSystem.modules[moduleName]

    if not module then
        print("^1[FD-System] ERROR: Module '" .. moduleName .. "' not found^0")
        return false
    end

    if ModuleSystem.activeModules[moduleName] then
        print("^3[FD-System] Module '" .. moduleName .. "' already active^0")
        return false
    end

    -- WARUM OnStart Callback?
    -- Module können Initialisierungs-Code ausführen (z.B. Threads starten)
    if module.OnStart and type(module.OnStart) == "function" then
        local success, err = pcall(module.OnStart)

        -- WARUM pcall? (Protected Call)
        -- Fängt Errors ab, verhindert dass ein kaputtes Modul das ganze System crasht
        if not success then
            print("^1[FD-System] ERROR starting module '" .. moduleName .. "': " .. tostring(err) .. "^0")
            return false
        end
    end

    ModuleSystem.activeModules[moduleName] = true
    print("^2[FD-System] Module '" .. moduleName .. "' activated^0")

    return true
end

function DeactivateModule(moduleName)
    if not ModuleSystem.activeModules[moduleName] then
        return false
    end

    local module = ModuleSystem.modules[moduleName]

    -- WARUM OnStop Callback?
    -- Module können Ressourcen freigeben (Threads beenden, Events entfernen)
    if module.OnStop and type(module.OnStop) == "function" then
        pcall(module.OnStop)
    end

    ModuleSystem.activeModules[moduleName] = nil
    print("^3[FD-System] Module '" .. moduleName .. "' deactivated^0")

    return true
end

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

function IsModuleActive(moduleName)
    return ModuleSystem.activeModules[moduleName] ~= nil
end

-- WARUM diese Funktion?
-- Admin-Commands können damit Module zur Laufzeit aktivieren/deaktivieren
function ToggleModule(moduleName)
    if IsModuleActive(moduleName) then
        return DeactivateModule(moduleName)
    else
        return ActivateModule(moduleName)
    end
end

-- =============================================================================
-- EXPORTS (Andere Scripts können diese Funktionen nutzen)
-- =============================================================================

-- WARUM Exports?
-- Andere Ressourcen können unser System erweitern/nutzen
exports('RegisterModule', RegisterModule)
exports('IsModuleActive', IsModuleActive)
exports('ToggleModule', ToggleModule)

-- WARUM exports?
-- Exports sind eine einfache Art, um Daten zu exportieren
-- Die Daten werden von anderen Ressourcen abgerufen
