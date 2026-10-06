--[[
    X AI Dispatch  |  by MR X  |  X Studio
    Client: crime detection, call blips, unit blips and the dispatch panel (ox_lib).
]]

lib.locale()

local CallBlips, UnitBlips = {}, {}
local ignoredWeapons = {}
for _, name in ipairs(Config.IgnoreWeapons) do ignoredWeapons[joaat(name)] = true end

local function notifyKey(kind, key, args)
    lib.notify({
        title = locale('title'),
        type = kind,
        description = locale(key or 'err_generic', table.unpack(args or {})),
    })
end

RegisterNetEvent('xdispatch:toast', notifyKey)

local function act(name, ...)
    local ok, key, args = lib.callback.await(name, false, ...)
    if key then notifyKey(ok and 'success' or 'error', key, args) end
    return ok
end

local function streetAt(c)
    return GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
end

-- ─── Call blips ─────────────────────────────────────────────────────────────

local function removeCallBlips(id)
    local b = CallBlips[id]
    if not b then return end
    if DoesBlipExist(b.blip) then RemoveBlip(b.blip) end
    if DoesBlipExist(b.radius) then RemoveBlip(b.radius) end
    CallBlips[id] = nil
end

local function addCallBlips(c)
    removeCallBlips(c.id)
    local color = Config.PriorityBlipColor[c.priority] or 1

    local blip = AddBlipForCoord(c.coords.x, c.coords.y, c.coords.z)
    SetBlipSprite(blip, Config.CallBlip.sprite)
    SetBlipScale(blip, Config.CallBlip.scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, c.priority == 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('[P%d] %s'):format(c.priority, c.title))
    EndTextCommandSetBlipName(blip)

    local radius
    if Config.CallBlip.radius and Config.CallBlip.radius > 0 then
        radius = AddBlipForRadius(c.coords.x, c.coords.y, c.coords.z, Config.CallBlip.radius)
        SetBlipColour(radius, color)
        SetBlipAlpha(radius, 90)
    end

    CallBlips[c.id] = { blip = blip, radius = radius }
    SetTimeout(Config.CallBlip.seconds * 1000, function() removeCallBlips(c.id) end)
end

RegisterNetEvent('xdispatch:newCall', function(c)
    addCallBlips(c)
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
    lib.notify({
        title = locale('new_call', c.priority, c.title),
        description = ('%s — %s'):format(streetAt(c.coords), c.desc),
        type = c.priority == 1 and 'error' or 'inform',
        icon = 'tower-broadcast',
        duration = 8000,
    })
end)

RegisterNetEvent('xdispatch:updateCall', function(c)
    if CallBlips[c.id] then addCallBlips(c) end
end)

RegisterNetEvent('xdispatch:removeCall', removeCallBlips)

RegisterNetEvent('xdispatch:assigned', function(c, auto)
    SetNewWaypoint(c.coords.x, c.coords.y)
    if auto then notifyKey('inform', 'auto_assigned', { c.id }) end
end)

-- ─── Unit blips ─────────────────────────────────────────────────────────────

RegisterNetEvent('xdispatch:units', function(list)
    local me, seen = GetPlayerServerId(PlayerId()), {}
    for _, u in ipairs(list or {}) do
        if u.src ~= me then
            seen[u.src] = true
            local b = UnitBlips[u.src]
            if not b or not DoesBlipExist(b) then
                b = AddBlipForCoord(u.coords.x, u.coords.y, u.coords.z)
                SetBlipSprite(b, 1)
                SetBlipScale(b, 0.7)
                SetBlipAsShortRange(b, false)
                UnitBlips[u.src] = b
            end
            SetBlipCoords(b, u.coords.x, u.coords.y, u.coords.z)
            SetBlipColour(b, (Config.Services[u.service] or {}).blipColor or 3)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(u.callsign or 'Unit')
            EndTextCommandSetBlipName(b)
        end
    end
    for src, b in pairs(UnitBlips) do
        if not seen[src] then
            if DoesBlipExist(b) then RemoveBlip(b) end
            UnitBlips[src] = nil
        end
    end
end)

-- ─── Dispatch panel ─────────────────────────────────────────────────────────

local openMenu

local function callMenu(c)
    local pos = GetEntityCoords(cache.ped)
    local dist = math.floor(#(pos - vec3(c.coords.x, c.coords.y, c.coords.z)))
    lib.registerContext({
        id = 'xdispatch_call',
        title = locale('call_title', c.priority, c.title),
        menu = 'xdispatch_list',
        options = {
            { title = locale('meta_details'), description = c.desc, icon = 'circle-info', readOnly = true, metadata = {
                { label = locale('meta_location'), value = ('%s • %sm'):format(streetAt(c.coords), dist) },
                { label = locale('meta_units'), value = #c.units > 0 and table.concat(c.units, ', ') or locale('meta_none') },
                { label = locale('meta_reports'), value = c.reports },
            } },
            { title = locale('action_respond'), icon = 'truck-fast', onSelect = function()
                if act('xdispatch:respond', c.id) then SetNewWaypoint(c.coords.x, c.coords.y) end
            end },
            { title = locale('action_waypoint'), icon = 'location-dot', onSelect = function()
                SetNewWaypoint(c.coords.x, c.coords.y)
            end },
            { title = locale('action_close'), icon = 'check', onSelect = function()
                act('xdispatch:close', c.id)
            end },
        },
    })
    lib.showContext('xdispatch_call')
end

local function statusMenu(current)
    lib.registerContext({
        id = 'xdispatch_status',
        title = locale('menu_status'),
        menu = 'xdispatch_list',
        options = {
            { title = locale('status_available'), icon = 'circle-check', disabled = current == 'available', onSelect = function()
                act('xdispatch:setStatus', 'available')
            end },
            { title = locale('status_busy'), icon = 'circle-minus', disabled = current == 'busy', onSelect = function()
                act('xdispatch:setStatus', 'busy')
            end },
        },
    })
    lib.showContext('xdispatch_status')
end

local function setCallsign()
    local input = lib.inputDialog(locale('menu_callsign'), { { type = 'input', label = locale('callsign_label'), max = 12, required = true } })
    if input then act('xdispatch:setCallsign', input[1]) end
end

openMenu = function()
    local list, status = lib.callback.await('xdispatch:getCalls', false)
    if not list then return notifyKey('error', 'err_access') end

    local pos = GetEntityCoords(cache.ped)
    for _, c in ipairs(list) do
        c.dist = #(pos - vec3(c.coords.x, c.coords.y, c.coords.z))
    end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.dist < b.dist
    end)

    local options = {
        { title = locale('menu_status'), description = locale('menu_status_desc', locale('status_' .. status)), icon = 'user-clock', onSelect = function() statusMenu(status) end },
        { title = locale('menu_callsign'), icon = 'id-badge', onSelect = setCallsign },
    }
    if #list == 0 then
        options[#options + 1] = { title = locale('menu_empty'), icon = 'inbox', readOnly = true }
    end
    for _, c in ipairs(list) do
        options[#options + 1] = {
            title = locale('call_title', c.priority, c.title),
            description = locale('call_desc', streetAt(c.coords), math.floor(c.dist)),
            icon = c.priority == 1 and 'triangle-exclamation' or 'tower-broadcast',
            iconColor = c.priority == 1 and '#e03131' or (c.priority == 2 and '#f59f00' or '#3b82f6'),
            onSelect = function() callMenu(c) end,
        }
    end

    lib.registerContext({ id = 'xdispatch_list', title = locale('menu_title'), options = options })
    lib.showContext('xdispatch_list')
end

RegisterCommand('dispatch', function() openMenu() end, false)
RegisterCommand('dstatus', function()
    local list, status = lib.callback.await('xdispatch:getCalls', false)
    if not list then return notifyKey('error', 'err_access') end
    statusMenu(status)
end, false)
RegisterCommand('callsign', function() setCallsign() end, false)

lib.addKeybind({
    name = 'xdispatch_menu',
    description = 'Open X AI Dispatch',
    defaultKey = Config.Keybind,
    onPressed = function() openMenu() end,
})

-- ─── Automatic crime detection (server validates and positions every report) ─

local last = {}

local function fire(kind)
    local a = Config.Alerts[kind]
    if not a or not a.enabled then return end
    local now = GetGameTimer()
    if last[kind] and now - last[kind] < a.cooldown * 1000 then return end
    last[kind] = now
    TriggerServerEvent('xdispatch:report', kind)
end

CreateThread(function()
    while true do
        local ped = cache.ped
        local armed = IsPedArmed(ped, 4)
        Wait(armed and 50 or 250)

        if armed and IsPedShooting(ped) then
            if not ignoredWeapons[GetSelectedPedWeapon(ped)] then
                fire(IsPedCurrentWeaponSilenced(ped) and 'shooting_silenced' or 'shooting')
            end
        elseif IsPedJacking(ped) then
            fire('carjacking')
        elseif IsPedInMeleeCombat(ped) then
            fire('fight')
        elseif Config.Alerts.speeding and Config.Alerts.speeding.enabled and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped and GetVehicleClass(veh) ~= 18
                and GetEntitySpeed(veh) * 3.6 > Config.Alerts.speeding.limit then
                fire('speeding')
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(CallBlips) do removeCallBlips(id) end
    for _, b in pairs(UnitBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
