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

    RegisterNetEvent('firedept:client:createFire')
    AddEventHandler('firedept:client:createFire', CreateFirePoint)

    RegisterNetEvent('firedept:client:extinguishFire')
    AddEventHandler('firedept:client:extinguishFire', ExtinguishFirePoint)

    RegisterNetEvent('firedept:client:updateFire')
    AddEventHandler('firedept:client:updateFire', UpdateFirePoint)

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
    fire.intensity = updatedData.intensity or fire.intensity
    fire.radius = updatedData.radius or fire.radius

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

function CreateSmokeEffect(fireId)
    local fire = activeFires[fireId]
    if not fire then return end

    Citizen.CreateThread(function()
        local particleDict = "core"

        RequestNamedPtfxAsset(particleDict)
        while not HasNamedPtfxAssetLoaded(particleDict) do
            Citizen.Wait(10)
        end

        UseParticleFxAssetNextCall(particleDict)

        local smokeHandle = StartParticleFxLoopedAtCoord(
            "exp_grd_bzgas_smoke",
            fire.coords.x,
            fire.coords.y,
            fire.coords.z + 0.5,
            0.0, 0.0, 0.0,
            fire.intensity * 2.0,
            false, false, false, false
        )

        fire.smokeHandle = smokeHandle
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

            for fireId, fire in pairs(activeFires) do
                local distance = #(playerCoords - fire.coords)

                if distance < 50.0 then
                    table.insert(nearbyFires, { id = fireId, fire = fire, distance = distance })

                    if distance < fire.radius * 3.0 then
                        inSmokeZone = true
                    end

                    if distance < fire.radius then
                        ApplyFireDamage(playerPed, fire, distance)
                    end
                end
            end

            UpdateVisibility(inSmokeZone)

            if #nearbyFires > 0 then
                Citizen.Wait(100)
            else
                Citizen.Wait(1000)
            end
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

    RemoveScriptFire(fire.handle)

    if fire.smokeHandle then
        StopParticleFxLooped(fire.smokeHandle, false)
    end

    activeFires[fireId] = nil

    if Config.Fire.Debug then
        print("^3[Fire Module] Extinguished fire #" .. fireId .. "^0")
    end
end

-- =============================================================================
-- INTERACTION SYSTEM
-- =============================================================================

RegisterKeyMapping('fd_extinguish', 'Feuerwehr: Feuer löschen', 'keyboard', 'E')

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
            TriggerServerEvent('firedept:server:attemptExtinguish', nearFireWithExtinguisher, 'water')
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

            for fireId, fire in pairs(activeFires) do
                local distance = #(playerCoords - fire.coords)

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

                    -- Marker (mit korrigierten Parametern)
                    ClientUtils.DrawMarker(
                        fire.coords,
                        20,
                        { r = 255, g = 0, b = 0, a = 100 },
                        1.5
                    )
                    break
                end
            end

            Citizen.Wait(0)
        end

        print("^1[Fire Module] Interaction Loop stopped^0")
    end)
end
