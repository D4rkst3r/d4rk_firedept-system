-- =============================================================================
-- FIRE MODULE - CLIENT SIDE
-- =============================================================================

local activeFires = {}
local playerInSmoke = false
local currentVisibility = 1.0
local nearFireWithExtinguisher = nil

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
        -- Animation abspielen
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

                    -- 3D Text
                    ClientUtils.DrawText3D(fire.coords + vector3(0, 0, 1.0), "~g~[E]~w~ Feuer löschen")

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
