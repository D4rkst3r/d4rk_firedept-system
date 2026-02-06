-- =============================================================================
-- ERROR HANDLER - Centralized Error Management
-- =============================================================================

ErrorHandler = {}

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

local Config = {
    LogToFile = true,
    LogToConsole = true,
    LogLevel = "INFO", -- DEBUG, INFO, WARNING, ERROR, CRITICAL

    LogLevels = {
        DEBUG = 0,
        INFO = 1,
        WARNING = 2,
        ERROR = 3,
        CRITICAL = 4
    }
}

-- =============================================================================
-- LOGGING
-- =============================================================================

function ErrorHandler.Log(level, module, message, data)
    --[[
        Strukturiertes Logging

        BEISPIEL:
        ErrorHandler.Log('ERROR', 'Fire', 'Failed to create fire', {coords = coords})
    ]]

    -- Check Log Level
    local currentLevel = Config.LogLevels[Config.LogLevel] or 0
    local messageLevel = Config.LogLevels[level] or 0

    if messageLevel < currentLevel then
        return -- Skip wenn unter Log-Level
    end

    -- Formatiere Nachricht
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logMessage = string.format(
        "[%s] [%s] [%s] %s",
        timestamp,
        level,
        module,
        message
    )

    -- Optional: Data anhängen
    if data then
        logMessage = logMessage .. " | Data: " .. json.encode(data)
    end

    -- Console Output mit Farben
    if Config.LogToConsole then
        local color = GetLogColor(level)
        print(color .. logMessage .. "^0")
    end

    -- Optional: File Logging
    if Config.LogToFile then
        SaveLog(logMessage)
    end
end

function GetLogColor(level)
    local colors = {
        DEBUG = "^7",   -- Weiß
        INFO = "^2",    -- Grün
        WARNING = "^3", -- Orange
        ERROR = "^1",   -- Rot
        CRITICAL = "^1" -- Rot + Bold
    }
    return colors[level] or "^7"
end

function SaveLog(message)
    -- Append to log file
    local logFile = "data/logs/" .. os.date("%Y-%m-%d") .. ".log"

    -- Lade existierende Logs
    local existingLogs = LoadResourceFile(GetCurrentResourceName(), logFile) or ""

    -- Append neue Nachricht
    local newLogs = existingLogs .. message .. "\n"

    -- Speichere
    SaveResourceFile(GetCurrentResourceName(), logFile, newLogs, -1)
end

-- =============================================================================
-- SAFE WRAPPERS
-- =============================================================================

function ErrorHandler.SafeCall(func, errorCallback, ...)
    --[[
        Try-Catch Wrapper für Lua

        BEISPIEL:
        ErrorHandler.SafeCall(function()
            local fire = activeFires[fireId]
            fire.intensity = fire.intensity - 0.1
        end, function(err)
            print("Error: " .. err)
        end)
    ]]

    local success, result = pcall(func, ...)

    if not success then
        ErrorHandler.Log('ERROR', 'SafeCall', 'Function failed', { error = result })

        if errorCallback then
            errorCallback(result)
        end

        return nil, result
    end

    return result
end

function ErrorHandler.SafeEventHandler(eventName, handler)
    --[[
        Event Handler mit Error Handling

        BEISPIEL:
        ErrorHandler.SafeEventHandler('firedept:client:createFire', function(data)
            -- Code hier
        end)
    ]]

    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function(...)
        local args = { ... }

        ErrorHandler.SafeCall(function()
            handler(table.unpack(args))
        end, function(err)
            ErrorHandler.Log('ERROR', 'EventHandler', 'Event handler failed', {
                event = eventName,
                error = err
            })
        end)
    end)
end

-- =============================================================================
-- SHORTCUTS
-- =============================================================================

function ErrorHandler.Debug(module, message, data)
    ErrorHandler.Log('DEBUG', module, message, data)
end

function ErrorHandler.Info(module, message, data)
    ErrorHandler.Log('INFO', module, message, data)
end

function ErrorHandler.Warning(module, message, data)
    ErrorHandler.Log('WARNING', module, message, data)
end

function ErrorHandler.Error(module, message, data)
    ErrorHandler.Log('ERROR', module, message, data)
end

function ErrorHandler.Critical(module, message, data)
    ErrorHandler.Log('CRITICAL', module, message, data)
end

-- =============================================================================
-- STARTUP
-- =============================================================================

-- Erstelle logs Ordner
Citizen.CreateThread(function()
    SaveResourceFile(GetCurrentResourceName(), "data/logs/.keep", "", -1)
    print("^2[Error Handler] Initialized^0")
end)
