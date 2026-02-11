-- =============================================================================
-- FIRE MODULE - CLIENT SIDE
-- =============================================================================

local activeFires = {}
local playerInSmoke = false
local currentVisibility = 1.0
local nearFireWithExtinguisher = nil

local lastExtinguishAttempt = 0
local extinguishCooldown = 500 -- Millisekunden zwischen Lösch-Checks

-- =============================================================================
-- MODUL REGISTRIERUNG
-- =============================================================================

Citizen.CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(100)
    end

    RegisterModule('fire', {
        enabled = Config.Fire.Enabled,
        OnStart = StartFireModule,
        OnStop = StopFireModule
    })
end)

-- =============================================================================
-- MODUL START/STOP
-- =============================================================================

function StartFireModule()
    print("^2[Fire Module] Starting...^0")

    RegisterNetEvent(Events.Fire.Create)
    AddEventHandler(Events.Fire.Create, CreateFirePoint)

    RegisterNetEvent(Events.Fire.Extinguish)
    AddEventHandler(Events.Fire.Extinguish, ExtinguishFirePoint)

    RegisterNetEvent(Events.Fire.Update)
    AddEventHandler(Events.Fire.Update, UpdateFirePoint)

    StartFireLoop()
    StartAutoExtinguishLoop() -- ✅ DIESE ZEILE HINZUFÜGEN!
    StartInteractionLoop()
end

function StopFireModule()
    print("^3[Fire Module] Stopping...^0")

    -- Cleanup: Alle Feuer löschen
    for fireId, fire in pairs(activeFires) do
        -- Native-Feuer löschen
        if fire.handle then
            RemoveScriptFire(fire.handle)
        end

        -- Rauch-Effect löschen
        if fire.smokeHandle then
            StopParticleFxLooped(fire.smokeHandle, false)
        end
    end

    -- Tabelle leeren
    activeFires = {}
end

-- =============================================================================
-- AUTO-EXTINGUISH SYSTEM 🔥
-- =============================================================================



function StartAutoExtinguishLoop()
    --[[
        HAUPTFUNKTION: Auto-Extinguish System

        WAS MACHT ES?
        1. Check ob Spieler mit Feuerlöscher schießt
        2. Raycast vom Spieler in Blickrichtung
        3. Check ob Raycast ein Feuer trifft
        4. Sende Lösch-Request an Server
    ]]

    Citizen.CreateThread(function()
        print("^2[Fire Module] Auto-Extinguish Loop started^0")

        while IsModuleActive('fire') do
            local playerPed = PlayerPedId()

            -- Check ob Spieler schießt
            if IsPedShooting(playerPed) then
                -- Check ob Feuerlöscher equipped
                local currentWeapon = GetSelectedPedWeapon(playerPed)

                if IsExtinguisher(currentWeapon) then
                    -- Cooldown Check
                    local now = GetGameTimer()
                    if (now - lastExtinguishAttempt) >= extinguishCooldown then
                        -- Raycast zu Feuer
                        local hitFire, fireId = RaycastToFire()

                        if hitFire and fireId then
                            -- TREFFER! Sende an Server
                            if Config.Fire.Debug then
                                local weapon = GetEquipmentWeapon(currentWeapon)
                                print(string.format("^2[Auto-Extinguish] Hit fire #%d with %s^0",
                                    fireId,
                                    weapon and weapon.label or "Unknown"
                                ))
                            end

                            TriggerServerEvent(Events.Fire.AttemptExtinguish, fireId, currentWeapon)
                            lastExtinguishAttempt = now
                        end
                    end
                end
            end

            Citizen.Wait(50) -- 20 FPS
        end

        print("^1[Fire Module] Auto-Extinguish Loop stopped^0")
    end)
end

function RaycastToFire()
    --[[
        RAYCAST: Findet Feuer in Schussrichtung

        RETURN:
        - hitFire (boolean)
        - fireId (number)
    ]]

    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)

    local direction = RotationToDirection(camRot)
    local destination = camCoords + (direction * 50.0)

    -- Check alle Feuer
    for fireId, fire in pairs(activeFires) do
        local distanceToRay = GetDistanceToRay(camCoords, destination, fire.coords)

        if distanceToRay < 1.5 then -- 1.5m Toleranz
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distanceToPlayer = #(playerCoords - fire.coords)

            local currentWeapon = GetSelectedPedWeapon(PlayerPedId())
            local weaponData = GetEquipmentWeapon(currentWeapon)

            if weaponData and distanceToPlayer <= weaponData.range then
                return true, fireId
            end
        end
    end

    return false, nil
end

function RotationToDirection(rotation)
    --[[
        Camera Rotation → Richtungsvektor
    ]]

    local adjustedRotation = vector3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )

    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )

    return direction
end

function GetDistanceToRay(rayStart, rayEnd, point)
    --[[
        Kürzeste Distanz von Punkt zu Linie
    ]]

    local rayDirection = rayEnd - rayStart
    local rayLength = #rayDirection
    rayDirection = rayDirection / rayLength

    local pointToStart = point - rayStart
    local projection = vector3(
        pointToStart.x * rayDirection.x,
        pointToStart.y * rayDirection.y,
        pointToStart.z * rayDirection.z
    )

    local projectionLength = projection.x + projection.y + projection.z
    projectionLength = math.max(0.0, math.min(rayLength, projectionLength))

    local closestPoint = rayStart + (rayDirection * projectionLength)
    local distance = #(point - closestPoint)

    return distance
end

-- =============================================================================
-- FIRE CREATION
-- =============================================================================

function CreateFirePoint(data)
    if not data or not data.id or not data.coords then
        print("^1[Fire Module] ERROR: Invalid fire data received^0")
        return
    end

    if activeFires[data.id] then
        if Config.Fire.Debug then
            print("^3[Fire Module] Fire " .. data.id .. " already exists^0")
        end
        return
    end

    local fireClass = Config.Fire.Classes[data.class] or Config.Fire.Classes['A']

    local fireHandle = StartScriptFire(
        data.coords.x,
        data.coords.y,
        data.coords.z,
        25,
        true
    )

    if fireHandle == 0 then
        print("^1[Fire Module] ERROR: Failed to create fire at " .. tostring(data.coords) .. "^0")
        return
    end

    activeFires[data.id] = {
        handle = fireHandle,
        coords = data.coords,
        class = data.class,
        intensity = data.intensity or 1.0,
        radius = data.radius or 2.0,
        classData = fireClass,
        createdAt = GetGameTimer()
    }

    if Config.Fire.Debug then
        print(string.format(
            "^2[Fire Module] Created fire #%s at %s (Class: %s)^0",
            data.id,
            tostring(data.coords),
            fireClass.name
        ))
    end

    CreateSmokeEffect(data.id)
end

-- =============================================================================
-- FIRE UPDATE (für Intensitäts-Änderungen)
-- =============================================================================

function UpdateFirePoint(fireId, updatedData)
    local fire = activeFires[fireId]
    if not fire then return end

    -- Update Werte
    local oldIntensity = fire.intensity
    fire.intensity = updatedData.intensity or fire.intensity
    fire.radius = updatedData.radius or fire.radius

    -- Update Particle-Effekt Scale
    if fire.smokeHandle and oldIntensity ~= fire.intensity then
        SetParticleFxLoopedScale(fire.smokeHandle, fire.intensity * 1.5)
    end

    if fire.flameHandle and oldIntensity ~= fire.intensity then
        SetParticleFxLoopedScale(fire.flameHandle, fire.intensity * 1.0)
    end

    if Config.Fire.Debug then
        print(string.format(
            "^3[Fire Module] Updated fire #%s (Intensity: %.1f, Radius: %.1f)^0",
            fireId,
            fire.intensity,
            fire.radius
        ))
    end
end

-- =============================================================================
-- SMOKE EFFECT
-- =============================================================================

-- =============================================================================
-- SMOKE & FLAME EFFECTS (IMPROVED)
-- =============================================================================

function CreateSmokeEffect(fireId)
    local fire = activeFires[fireId]
    if not fire then return end

    Citizen.CreateThread(function()
        -- =========================================================================
        -- PARTICLE ASSETS LADEN (wie FireScript)
        -- =========================================================================

        -- Asset 1: Für Rauch
        local smokeAsset = "scr_agencyheistb"
        RequestNamedPtfxAsset(smokeAsset)
        while not HasNamedPtfxAssetLoaded(smokeAsset) do
            Citizen.Wait(10)
        end

        -- Asset 2: Für Flammen
        local flameAsset = "scr_trevor3"
        RequestNamedPtfxAsset(flameAsset)
        while not HasNamedPtfxAssetLoaded(flameAsset) do
            Citizen.Wait(10)
        end

        -- =========================================================================
        -- RAUCH-EFFEKT (Schwarz/Grau)
        -- =========================================================================

        UseParticleFxAssetNextCall(smokeAsset)

        local smokeHandle = StartParticleFxLoopedAtCoord(
            "scr_env_agency3b_smoke", -- Besserer Rauch-Effekt
            fire.coords.x,
            fire.coords.y,
            fire.coords.z + 1.0,  -- Etwas höher
            0.0, 0.0, 0.0,        -- Rotation
            fire.intensity * 1.5, -- Scale basierend auf Intensität
            false, false, false, false
        )

        fire.smokeHandle = smokeHandle

        -- =========================================================================
        -- FLAMMEN-EFFEKT (Orange/Rot Glut)
        -- =========================================================================

        UseParticleFxAssetNextCall(flameAsset)

        local flameHandle = StartParticleFxLoopedAtCoord(
            "scr_trev3_trailer_plume", -- Flammen/Glut-Effekt
            fire.coords.x,
            fire.coords.y,
            fire.coords.z + 1.2,  -- Etwas über Rauch
            0.0, 0.0, 0.0,        -- Rotation
            fire.intensity * 1.0, -- Scale
            false, false, false, false
        )

        fire.flameHandle = flameHandle

        -- =========================================================================
        -- SOUND-EFFEKT (Feuer-Knistern)
        -- =========================================================================

        local soundId = GetSoundId()
        PlaySoundFromCoord(
            soundId,
            "LAMAR1_WAREHOUSE_FIRE", -- Sound-Name
            fire.coords.x,
            fire.coords.y,
            fire.coords.z,
            0,     -- Range (0 = default)
            false, -- Unknown
            0,     -- Unknown
            false  -- Unknown
        )

        fire.soundId = soundId

        if Config.Fire.Debug then
            print(string.format(
                "^2[Fire Module] Effects created for fire #%s (Smoke: %s, Flames: %s, Sound: %s)^0",
                fireId,
                tostring(smokeHandle),
                tostring(flameHandle),
                tostring(soundId)
            ))
        end
    end)
end

-- =============================================================================
-- FIRE LOOP
-- =============================================================================

function StartFireLoop()
    Citizen.CreateThread(function()
        while IsModuleActive('fire') do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            local nearbyFires = {}
            local inSmokeZone = false
            local closestDistance = 999999

            -- OPTIMIZATION: Early-out wenn keine Feuer
            if Utils.TableCount(activeFires) == 0 then
                Citizen.Wait(5000) -- 5 Sekunden warten wenn keine Feuer
                goto continue
            end

            for fireId, fire in pairs(activeFires) do
                local distance = #(playerCoords - fire.coords)

                -- Track closest
                if distance < closestDistance then
                    closestDistance = distance
                end

                -- OPTIMIZATION: Skip wenn zu weit weg (>100m)
                if distance > 100.0 then
                    goto continue_fire
                end

                if distance < 50.0 then
                    table.insert(nearbyFires, { id = fireId, fire = fire, distance = distance })

                    if distance < fire.radius * 3.0 then
                        inSmokeZone = true
                    end

                    if distance < fire.radius then
                        ApplyFireDamage(playerPed, fire, distance)
                    end
                end

                ::continue_fire::
            end

            UpdateVisibility(inSmokeZone)

            -- PERFORMANCE: Dynamisches Wait basierend auf closest fire
            local waitTime
            if closestDistance < 20.0 then
                waitTime = 100  -- Nah = 100ms (10 FPS)
            elseif closestDistance < 100.0 then
                waitTime = 500  -- Mittlere Distanz = 500ms (2 FPS)
            else
                waitTime = 2000 -- Weit weg = 2 Sekunden
            end

            Citizen.Wait(waitTime)

            ::continue::
        end
    end)
end

-- =============================================================================
-- FIRE DAMAGE
-- =============================================================================

function ApplyFireDamage(ped, fire, distance)
    local damageMultiplier = 1.0 - (distance / fire.radius)
    local damage = fire.classData.heatIntensity * damageMultiplier * 0.5

    ApplyDamageToPed(ped, damage, false)
end

-- =============================================================================
-- VISIBILITY SYSTEM
-- =============================================================================

function UpdateVisibility(inSmoke)
    if inSmoke and not playerInSmoke then
        playerInSmoke = true
        StartVisionBlur()
    elseif not inSmoke and playerInSmoke then
        playerInSmoke = false
        StopVisionBlur()
    end
end

function StartVisionBlur()
    SetTimecycleModifier("spectator5")
    SetTimecycleModifierStrength(0.8)
end

function StopVisionBlur()
    ClearTimecycleModifier()
end

-- =============================================================================
-- FIRE EXTINGUISHING
-- =============================================================================

function ExtinguishFirePoint(fireId)
    local fire = activeFires[fireId]
    if not fire then return end

    -- Native-Feuer löschen
    if fire.handle then
        RemoveScriptFire(fire.handle)
    end

    -- Rauch-Effect löschen (mit Fade-Out wie FireScript)
    if fire.smokeHandle then
        local smokeHandle = fire.smokeHandle
        Citizen.SetTimeout(5000, function()
            StopParticleFxLooped(smokeHandle, false)
            Citizen.Wait(1500)
            RemoveParticleFx(smokeHandle, true)
        end)
    end

    -- Flammen-Effect löschen (mit Scaling-Animation wie FireScript)
    if fire.flameHandle then
        local flameHandle = fire.flameHandle
        local soundId = fire.soundId

        Citizen.CreateThread(function()
            -- Scaling-Animation: Flammen werden kleiner
            local scale = 1.0
            while scale > 0.3 do
                scale = scale - 0.01
                SetParticleFxLoopedScale(flameHandle, scale)
                Citizen.Wait(60)
            end

            -- Sound stoppen
            if soundId then
                StopSound(soundId)
                ReleaseSoundId(soundId)
            end

            -- Flammen entfernen
            StopParticleFxLooped(flameHandle, false)
            RemoveParticleFx(flameHandle, true)
        end)
    end

    -- Aus Tabelle entfernen
    activeFires[fireId] = nil

    if Config.Fire.Debug then
        print("^3[Fire Module] Extinguished fire #" .. fireId .. " (with animation)^0")
    end
end

-- =============================================================================
-- INTERACTION SYSTEM
-- =============================================================================

RegisterKeyMapping('fd_extinguish', 'Fire: Feuer löschen', 'keyboard', 'E')

RegisterCommand('fd_extinguish', function()
    if nearFireWithExtinguisher then
        -- ✅ NEUE LOGIK: Check Equipment Module
        if IsModuleActive('equipment') then
            local hasTool = exports[GetCurrentResourceName()]:HasTool()

            if hasTool then
                -- Nutze Equipment Module's UseTool Funktion
                -- (Das Equipment Module handhabt Animation + Server-Call)
                TriggerEvent('equipment:useTool', nearFireWithExtinguisher)
                return
            else
                -- Kein Tool = Warnung
                ClientUtils.Notify('warning', 'Du brauchst ein Tool zum Löschen!')
                return
            end
        end

        -- FALLBACK: Old System (wenn Equipment Module disabled)
        local playerPed = PlayerPedId()
        RequestAnimDict("weapons@first_person@aim_rng@generic@projectile@thermal_charge@")
        while not HasAnimDictLoaded("weapons@first_person@aim_rng@generic@projectile@thermal_charge@") do
            Citizen.Wait(10)
        end
        TaskPlayAnim(playerPed, "weapons@first_person@aim_rng@generic@projectile@thermal_charge@", "plant_floor", 8.0,
            -8.0, 3000, 0, 0, false, false, false)

        -- Nach 3 Sekunden an Server senden
        Citizen.SetTimeout(3000, function()
            TriggerServerEvent(Events.Fire.AttemptExtinguish, nearFireWithExtinguisher, 'water')
        end)
    end
end, false)

function StartInteractionLoop()
    Citizen.CreateThread(function()
        print("^2[Fire Module] Interaction Loop started^0")

        local lastDebugPrint = 0

        while IsModuleActive('fire') do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            nearFireWithExtinguisher = nil
            local closestDistance = 999999 -- Track closest fire

            for fireId, fire in pairs(activeFires) do
                local distance = #(playerCoords - fire.coords)

                -- Update closest distance
                if distance < closestDistance then
                    closestDistance = distance
                end

                if distance < 5.0 then
                    nearFireWithExtinguisher = fireId

                    -- DEBUG: Nur alle 2 Sekunden printen
                    if Config.Fire.Debug then
                        local now = GetGameTimer()
                        if (now - lastDebugPrint) > 2000 then
                            print(string.format("^2[DEBUG] Near fire #%d, distance: %.2fm^0", fireId, distance))
                            lastDebugPrint = now
                        end
                    end

                    -- ✅ NEUE LOGIK: Check ob Equipment Module aktiv
                    local text = "~g~[E]~w~ Feuer löschen"

                    if IsModuleActive('equipment') then
                        -- Check ob Tool equipped
                        local hasTool = exports[GetCurrentResourceName()]:HasTool()

                        if hasTool then
                            text = "~g~[E]~w~ Mit Tool löschen"
                        else
                            text = "~o~[E]~w~ Feuer löschen ~r~(kein Tool!)~w~"
                        end
                    end

                    -- 3D Text
                    ClientUtils.DrawText3D(fire.coords + vector3(0, 0, 1.0), text)

                    -- Marker
                    ClientUtils.DrawMarker(
                        fire.coords,
                        20,
                        { r = 255, g = 0, b = 0, a = 100 },
                        1.5
                    )
                    break
                end
            end

            -- PERFORMANCE: Dynamisches Wait basierend auf Distanz
            local waitTime
            if closestDistance < 10.0 then
                waitTime = 0   -- Sehr nah = jeden Frame (smooth)
            elseif closestDistance < 50.0 then
                waitTime = 100 -- Mittlere Distanz = alle 100ms
            else
                waitTime = 500 -- Weit weg = alle 500ms
            end

            Citizen.Wait(waitTime)
        end

        print("^1[Fire Module] Interaction Loop stopped^0")
    end)
end
