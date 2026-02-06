-- =============================================================================
-- CLIENT UTILITIES - NUR für Client-Side
-- =============================================================================

ClientUtils = {}

-- =============================================================================
-- 3D RENDERING
-- =============================================================================

function ClientUtils.DrawText3D(coords, text, scale)
    --[[
        WARUM diese Funktion auslagern?
        - Wird in JEDEM Modul gebraucht
        - 20+ Zeilen Code
        - Einheitliches Aussehen überall

        PARAMETER:
        - coords: vector3 oder {x, y, z}
        - text: String mit GTA-Formatierung (~g~, ~r~, etc.)
        - scale: Optional, default 0.35
    ]]

    scale = scale or 0.35

    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)

    if onScreen then
        -- Distanz-basierte Skalierung
        local camCoords = GetGameplayCamCoords()
        local dist = #(camCoords - coords)
        local scaleFactor = (1 / dist) * 2
        local fov = (1 / GetGameplayCamFov()) * 100
        scaleFactor = scaleFactor * fov

        SetTextScale(0.0 * scaleFactor, scale * scaleFactor)
        SetTextFont(4)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        SetDrawOrigin(coords.x, coords.y, coords.z, 0)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()
    end
end

function ClientUtils.DrawMarker(coords, markerType, color, scale)
    --[[
        Vereinfachter Marker-Wrapper mit Defaults

        PARAMETER:
        - coords: vector3
        - markerType: Number (20 = Circle, 1 = Cylinder, etc.)
        - color: {r, g, b, a} Table
        - scale: Number oder {x, y, z} Table

        Beispiel:
        ClientUtils.DrawMarker(coords, 20, {r=255, g=0, b=0, a=100}, 1.5)
    ]]

    markerType = markerType or 20
    color = color or { r = 255, g = 255, b = 255, a = 100 }

    local scaleX, scaleY, scaleZ
    if type(scale) == "table" then
        scaleX, scaleY, scaleZ = scale.x or scale[1], scale.y or scale[2], scale.z or scale[3]
    else
        scale = scale or 1.0
        scaleX, scaleY, scaleZ = scale, scale, 0.5
    end

    DrawMarker(
        markerType,
        coords.x, coords.y, coords.z - 0.98,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scaleX, scaleY, scaleZ,
        color.r, color.g, color.b, color.a,
        false, true, 2, false,
        nil, nil, false
    )
end

-- =============================================================================
-- NOTIFICATION SYSTEM
-- =============================================================================

function ClientUtils.Notify(type, message, duration)
    --[[
        Einheitliches Notification-System

        TYPES:
        - 'success' = Grün
        - 'error' = Rot
        - 'warning' = Orange
        - 'info' = Blau

        Beispiel:
        ClientUtils.Notify('success', 'Feuer gelöscht!')
        ClientUtils.Notify('error', 'Nicht genug Wasser!')
    ]]

    duration = duration or 3000

    -- Color basierend auf Type
    local colors = {
        success = "~g~",
        error = "~r~",
        warning = "~o~",
        info = "~b~"
    }

    local color = colors[type] or "~w~"
    local formattedMessage = color .. message .. "~w~"

    -- GTA Native Notification
    SetNotificationTextEntry("STRING")
    AddTextComponentString(formattedMessage)
    DrawNotification(false, false)

    -- Optional: Beep Sound
    if type == "error" then
        PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
    elseif type == "success" then
        PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
    end
end

-- =============================================================================
-- ANIMATION HELPERS
-- =============================================================================

function ClientUtils.PlayAnimation(dict, anim, duration, flag)
    --[[
        Spielt Animation mit automatischem Dictionary-Loading

        PARAMETER:
        - dict: Animation Dictionary
        - anim: Animation Name
        - duration: Millisekunden (-1 = bis gestoppt)
        - flag: Animation Flag (0, 1, 16, 49, etc.)

        FLAGS:
        0 = Normal, stoppbar
        1 = Loop, nicht stoppbar
        16 = Cancelable
        49 = Upper body only + cancelable
    ]]

    duration = duration or -1
    flag = flag or 0

    local playerPed = PlayerPedId()

    -- Load Animation Dictionary
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(10)
    end

    -- Play Animation
    TaskPlayAnim(
        playerPed,
        dict,
        anim,
        8.0,  -- Blend-In Speed
        -8.0, -- Blend-Out Speed
        duration,
        flag,
        0,
        false, false, false
    )

    return true
end

function ClientUtils.StopAnimation()
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
end

-- =============================================================================
-- CAMERA & HEADING
-- =============================================================================

function ClientUtils.GetForwardVector(heading, distance)
    --[[
        Berechnet Position VOR dem Spieler

        Beispiel:
        local playerHeading = GetEntityHeading(PlayerPedId())
        local spawnPos = playerCoords + ClientUtils.GetForwardVector(playerHeading, 5.0)
        -- Spawnt 5 Meter vor dem Spieler
    ]]

    distance = distance or 1.0

    local rad = math.rad(heading)
    return vector3(
        -math.sin(rad) * distance,
        math.cos(rad) * distance,
        0.0
    )
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

exports('DrawText3D', ClientUtils.DrawText3D)
exports('DrawMarker', ClientUtils.DrawMarker)
exports('Notify', ClientUtils.Notify)
exports('PlayAnimation', ClientUtils.PlayAnimation)

print("^2[Client Utils] Loaded^0")
