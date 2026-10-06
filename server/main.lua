--[[
    X AI Dispatch  |  by MR X  |  X Studio
    Discord: mr_xdev  (https://discord.com/users/1019985047178182758)
    Server logic. Positions always come from the server; every action is role-checked.
]]

local RESOURCE = GetCurrentResourceName()
local Calls, NextId, Units, Cd, Recent, WasResponder = {}, 1, {}, {}, {}, {}
local jobToService = {}
local allServices = {}

for key, s in pairs(Config.Services) do
    allServices[#allServices + 1] = key
    for _, j in ipairs(s.jobs) do jobToService[j] = key end
end

-- ─── Helpers ────────────────────────────────────────────────────────────────

local function log(msg)
    print(('^5[X Studio | %s]^7 %s'):format(RESOURCE, msg))
    if Config.Webhook and Config.Webhook ~= '' then
        PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
            username = 'X AI Dispatch',
            embeds = { { title = 'X AI Dispatch', description = msg, color = 3447003, footer = { text = 'X Studio | MR X' } } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

local function toast(src, kind, key, ...)
    TriggerClientEvent('xdispatch:toast', src, kind, key, { ... })
end

local function serviceOf(src)
    if Bridge.Mode() == 'standalone' then
        for key in pairs(Config.Services) do
            if IsPlayerAceAllowed(src, 'xdispatch.' .. key) then return key end
        end
        return nil
    end
    local job, duty = Bridge.GetJob(src)
    local key = job and jobToService[job]
    if not key then return nil end
    if Config.Services[key].requireDuty and not duty then return nil end
    return key
end

local function getResponders()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local svc = serviceOf(src)
        if svc then
            out[#out + 1] = { src = src, service = svc, coords = GetEntityCoords(GetPlayerPed(src)) }
        end
    end
    return out
end

local function unit(src)
    local u = Units[src]
    if not u then
        u = { status = 'available', callsign = Bridge.GetName(src):sub(1, 24) }
        Units[src] = u
    end
    return u
end

local function hasService(c, svc)
    for _, s in ipairs(c.services) do if s == svc then return true end end
    return false
end

local function pub(c)
    local names = {}
    for _, u in pairs(c.units) do names[#names + 1] = u.callsign end
    return {
        id = c.id, type = c.type, title = c.title, desc = c.desc, coords = c.coords,
        priority = c.priority, services = c.services, created = c.created,
        reports = c.reports, units = names, origin = c.origin,
    }
end

local function inIgnoreZone(coords)
    for _, z in ipairs(Config.IgnoreZones) do
        if #(coords - z.coords) <= z.radius then return true end
    end
    return false
end

local function detach(src)
    local u = Units[src]
    if u and u.call then
        local old = Calls[u.call]
        if old then old.units[src] = nil end
        u.call = nil
    end
end

local function assign(c, src, auto)
    detach(src)
    local u = unit(src)
    c.units[src] = { callsign = u.callsign }
    u.call = c.id
    TriggerClientEvent('xdispatch:assigned', src, pub(c), auto == true)
end

local function autoAssign(c, responders)
    for _, svc in ipairs(c.services) do
        local best, bestDist
        for _, r in ipairs(responders) do
            local u = unit(r.src)
            if r.service == svc and r.src ~= c.exclude and u.status == 'available' and not u.call then
                local d = #(r.coords - c.coords)
                if not bestDist or d < bestDist then best, bestDist = r, d end
            end
        end
        if best then assign(c, best.src, true) end
    end
end

local function logHistory(c, status)
    local n = 0
    for _ in pairs(c.units) do n += 1 end
    MySQL.insert('INSERT INTO x_dispatch_history (call_id, type, title, priority, services, origin, status, reports, units, x, y) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        c.id, c.type, c.title, c.priority, table.concat(c.services, ','), c.origin, status, c.reports, n, c.coords.x, c.coords.y,
    })
end

local function closeCall(c, status)
    if c.status ~= 'open' then return end
    c.status = status
    for src in pairs(c.units) do
        local u = Units[src]
        if u then u.call = nil end
    end
    logHistory(c, status)
    for _, r in ipairs(getResponders()) do
        TriggerClientEvent('xdispatch:removeCall', r.src, c.id)
    end
    Calls[c.id] = nil
end

-- ─── Call creation (merge, broadcast, auto-assign) ──────────────────────────

local function createCall(d)
    local coords = d.coords
    if type(coords) == 'table' and coords.x then coords = vec3(coords.x, coords.y, coords.z or 0.0) end
    if not coords or type(d.title) ~= 'string' then return nil end

    local services = {}
    for _, s in ipairs(d.services or { 'police' }) do
        if Config.Services[s] then services[#services + 1] = s end
    end
    if #services == 0 then return nil end

    local priority = math.min(3, math.max(1, math.floor(tonumber(d.priority) or 2)))
    local now = os.time()
    local responders = getResponders()

    if not d.noMerge then
        for _, c in pairs(Calls) do
            if c.type == d.type and now - c.created < Config.MergeSeconds and #(c.coords - coords) < Config.MergeRadius then
                c.reports += 1
                c.priority = math.min(c.priority, priority)
                for _, r in ipairs(responders) do
                    if hasService(c, r.service) then TriggerClientEvent('xdispatch:updateCall', r.src, pub(c)) end
                end
                return c.id, true
            end
        end
    end

    local c = {
        id = NextId, type = d.type or 'custom', title = d.title:sub(1, 80), desc = tostring(d.desc or ''):sub(1, 200),
        coords = coords, priority = priority, services = services, created = now,
        status = 'open', units = {}, reports = 1, origin = d.origin or 'player', exclude = d.exclude,
    }
    NextId += 1
    Calls[c.id] = c

    for _, r in ipairs(responders) do
        if hasService(c, r.service) then TriggerClientEvent('xdispatch:newCall', r.src, pub(c)) end
    end
    if Config.AutoAssign.Enabled and c.priority <= Config.AutoAssign.MaxPriority then
        autoAssign(c, responders)
    end

    if c.origin ~= 'player' or c.priority == 1 then
        log(('Call #%d [P%d] %s (%s)'):format(c.id, c.priority, c.title, c.origin))
    end
    return c.id
end

-- ─── Startup ────────────────────────────────────────────────────────────────

CreateThread(function()
    local fw = Bridge.Init()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `x_dispatch_history` (
        `id` INT NOT NULL AUTO_INCREMENT, `call_id` INT NOT NULL, `type` VARCHAR(48) NOT NULL,
        `title` VARCHAR(120) NOT NULL, `priority` TINYINT NOT NULL DEFAULT 2, `services` VARCHAR(120) NOT NULL,
        `origin` VARCHAR(16) NOT NULL DEFAULT 'player', `status` VARCHAR(16) NOT NULL,
        `reports` INT NOT NULL DEFAULT 1, `units` INT NOT NULL DEFAULT 0,
        `x` FLOAT NOT NULL DEFAULT 0, `y` FLOAT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    print('^5')
    print('  __  __ ____    __  __')
    print('  \\ \\/ /|  _ \\  \\ \\/ /   X AI Dispatch v' .. GetResourceMetadata(RESOURCE, 'version', 0))
    print('   >  < | |_) |  >  <    by MR X  |  X Studio')
    print('  /_/\\_\\|____/  /_/\\_\\   Discord: mr_xdev')
    print(('  Framework: %s | Services: %s^7'):format(fw, table.concat(allServices, ', ')))
end)

AddEventHandler('playerDropped', function()
    local src = source
    detach(src)
    Units[src], WasResponder[src] = nil, nil
    for k in pairs(Cd) do
        if k:find('^' .. src .. ':') then Cd[k] = nil end
    end
end)

-- ─── Automatic alerts from clients ──────────────────────────────────────────

RegisterNetEvent('xdispatch:report', function(kind)
    local src = source
    local a = type(kind) == 'string' and Config.Alerts[kind]
    if not a or not a.enabled then return end

    local key, now = src .. ':' .. kind, os.time()
    if Cd[key] and now - Cd[key] < a.cooldown then return end
    Cd[key] = now

    if Config.IgnoreOnDutyResponders and serviceOf(src) then return end
    if math.random(100) > a.chance then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    if inIgnoreZone(coords) then return end

    local delay = math.random(Config.WitnessDelay.min, Config.WitnessDelay.max) * 1000
    SetTimeout(delay, function()
        createCall({ type = kind, title = a.title, desc = a.desc, coords = coords, priority = a.priority, services = a.services, origin = 'witness' })
    end)
end)

-- ─── Callbacks for responders ───────────────────────────────────────────────

lib.callback.register('xdispatch:getCalls', function(src)
    local svc = serviceOf(src)
    if not svc then return nil end
    local list = {}
    for _, c in pairs(Calls) do
        if c.status == 'open' and hasService(c, svc) then list[#list + 1] = pub(c) end
    end
    return list, unit(src).status
end)

lib.callback.register('xdispatch:respond', function(src, id)
    local svc = serviceOf(src)
    if not svc then return false, 'err_access' end
    local c = Calls[tonumber(id)]
    if not c or c.status ~= 'open' or not hasService(c, svc) then return false, 'err_notfound' end
    assign(c, src, false)
    return true, 'ok_responding', { c.id }
end)

lib.callback.register('xdispatch:close', function(src, id)
    local svc = serviceOf(src)
    if not svc then return false, 'err_access' end
    local c = Calls[tonumber(id)]
    if not c or not hasService(c, svc) then return false, 'err_notfound' end
    if not c.units[src] then return false, 'err_assigned' end
    local cid = c.id
    closeCall(c, 'closed')
    return true, 'ok_closed', { cid }
end)

lib.callback.register('xdispatch:setStatus', function(src, status)
    if not serviceOf(src) then return false, 'err_access' end
    if status ~= 'available' and status ~= 'busy' then return false, 'err_generic' end
    unit(src).status = status
    return true, 'ok_status', { status }
end)

lib.callback.register('xdispatch:setCallsign', function(src, callsign)
    if not serviceOf(src) then return false, 'err_access' end
    callsign = type(callsign) == 'string' and callsign:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #callsign < 1 or #callsign > 12 or callsign:find('[^%w%- ]') then return false, 'err_callsign' end
    unit(src).callsign = callsign
    return true, 'ok_callsign', { callsign }
end)

-- ─── Commands ───────────────────────────────────────────────────────────────

local function cooldown(src, name)
    local key, now = src .. ':cmd:' .. name, os.time()
    if Cd[key] and now - Cd[key] < Config.CommandCooldown then return true end
    Cd[key] = now
    return false
end

local function triage(message)
    local text = message:lower()
    local services, set, priority, title = {}, {}, 4, nil
    for _, rule in ipairs(Config.Triage) do
        for _, w in ipairs(rule.words) do
            if text:find(w, 1, true) then
                for _, s in ipairs(rule.services) do
                    if not set[s] then set[s] = true; services[#services + 1] = s end
                end
                if rule.priority < priority then priority, title = rule.priority, rule.title end
                break
            end
        end
    end
    if #services == 0 then
        local f = Config.TriageFallback
        return f.services, f.priority, f.title
    end
    return services, priority, title
end

lib.addCommand('911', {
    help = 'Call emergency services',
    params = { { name = 'message', type = 'longString', help = 'Describe the emergency' } },
}, function(source, args)
    if source == 0 then return end
    local message = tostring(args.message or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #message < 3 then return toast(source, 'error', 'err_empty') end
    if cooldown(source, '911') then return toast(source, 'error', 'err_cooldown') end

    local services, priority, title = triage(message:sub(1, 200))
    createCall({
        type = '911', title = title, desc = message, coords = GetEntityCoords(GetPlayerPed(source)),
        priority = priority, services = services, origin = '911', noMerge = true,
    })
    toast(source, 'success', 'ok_911')
end)

if Config.Panic.Enabled then
    lib.addCommand('panic', { help = 'Responder panic button' }, function(source)
        if source == 0 then return end
        if not serviceOf(source) then return toast(source, 'error', 'err_access') end
        if cooldown(source, 'panic') then return toast(source, 'error', 'err_cooldown') end
        createCall({
            type = 'panic', title = Config.Panic.title, desc = Config.Panic.desc,
            coords = GetEntityCoords(GetPlayerPed(source)), priority = 1, services = allServices,
            origin = 'panic', exclude = source, noMerge = true,
        })
        toast(source, 'success', 'ok_panic')
    end)
end

lib.addCommand('dispatchclear', { help = 'Clear all dispatch calls', restricted = 'group.admin' }, function()
    for _, c in pairs(Calls) do closeCall(c, 'cleared') end
    log('Admin cleared all dispatch calls')
end)

-- ─── Maintenance, unit blips and the incident generator ─────────────────────

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, c in pairs(Calls) do
            local age = now - c.created
            if age > Config.MaxCallMinutes * 60 or (next(c.units) == nil and age > Config.CallExpireMinutes * 60) then
                closeCall(c, 'expired')
            end
        end
    end
end)

CreateThread(function()
    if not Config.UnitBlips.Enabled then return end
    while true do
        Wait(Config.UnitBlips.IntervalMs)
        local responders = getResponders()
        local byService, now = {}, {}
        for _, r in ipairs(responders) do
            local u = unit(r.src)
            byService[r.service] = byService[r.service] or {}
            table.insert(byService[r.service], { src = r.src, coords = r.coords, callsign = u.callsign, service = r.service, status = u.status })
        end
        for _, r in ipairs(responders) do
            now[r.src] = true
            TriggerClientEvent('xdispatch:units', r.src, byService[r.service])
        end
        for src in pairs(WasResponder) do
            if not now[src] and GetPlayerName(src) then TriggerClientEvent('xdispatch:units', src, {}) end
        end
        WasResponder = now
    end
end)

local function pickScenario(responders)
    local counts = {}
    for _, r in ipairs(responders) do counts[r.service] = (counts[r.service] or 0) + 1 end
    local pool, total, now = {}, 0, os.time()
    for _, s in ipairs(Config.Scenarios) do
        if (counts[s.services[1]] or 0) >= Config.AI.MinResponders then
            local w = s.weight
            if Recent[s.id] and now - Recent[s.id] < s.cooldown * 60 then w = w * 0.15 end -- adaptive: avoid repeats
            pool[#pool + 1] = { s = s, w = w }
            total += w
        end
    end
    if total <= 0 then return nil end
    local roll = math.random() * total
    for _, p in ipairs(pool) do
        roll -= p.w
        if roll <= 0 then return p.s end
    end
    return pool[#pool].s
end

local function generate()
    local open = 0
    for _, c in pairs(Calls) do if c.origin == 'ai' then open += 1 end end
    if open >= Config.AI.MaxOpen then return end

    local s = pickScenario(getResponders())
    if not s then return end
    Recent[s.id] = os.time()

    local loc = s.locations[math.random(#s.locations)]
    local jitter = vec3(math.random(-15, 15), math.random(-15, 15), 0.0)
    createCall({
        type = 'ai_' .. s.id, title = s.title, desc = s.descs[math.random(#s.descs)],
        coords = loc + jitter, priority = s.priority, services = s.services, origin = 'ai',
    })
end

CreateThread(function()
    while Config.AI.Enabled do
        Wait(math.floor((math.random() * (Config.AI.MaxMinutes - Config.AI.MinMinutes) + Config.AI.MinMinutes) * 60000))
        generate()
    end
end)

-- ─── Exports ────────────────────────────────────────────────────────────────

exports('CreateCall', createCall) -- { type, title, desc, coords, priority, services, origin }
exports('GetCalls', function()
    local list = {}
    for _, c in pairs(Calls) do list[#list + 1] = pub(c) end
    return list
end)
exports('CloseCall', function(id)
    local c = Calls[tonumber(id)]
    if c then closeCall(c, 'closed') return true end
    return false
end)
