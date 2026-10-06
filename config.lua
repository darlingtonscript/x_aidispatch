--[[
    X AI Dispatch  |  by MR X  |  X Studio
    Discord: mr_xdev  (https://discord.com/users/1019985047178182758)

    "AI" here is a built-in rule-based engine: triage of 911 messages, call merging,
    nearest-unit auto-assignment and an adaptive incident generator. No external service is used.
]]

Config = {}

Config.Debug = false

-- 'auto' | 'qbox' | 'qb' | 'esx' | 'standalone'
-- standalone has no jobs: grant access with ACE, e.g.  add_ace group.police xdispatch.police allow
Config.Framework = 'auto'

-- Responder services. `jobs` are framework job names; callers are matched to a service by job.
Config.Services = {
    police = { label = 'Police', jobs = { 'police', 'sheriff', 'state' }, requireDuty = true, blipColor = 3 },
    ems    = { label = 'EMS',    jobs = { 'ambulance', 'ems' },           requireDuty = true, blipColor = 1 },
}

Config.Keybind = 'F6'                    -- open the dispatch panel (rebindable in game settings)

Config.AutoAssign = { Enabled = true, MaxPriority = 1 }   -- nearest available unit per service for priority <= MaxPriority
Config.MergeSeconds = 120                -- identical reports within this time and radius merge into one call
Config.MergeRadius = 40.0
Config.CallExpireMinutes = 15            -- unanswered calls expire after this long
Config.MaxCallMinutes = 60               -- hard limit for any call

Config.CallBlip = { sprite = 161, scale = 1.0, radius = 60.0, seconds = 300 }
Config.PriorityBlipColor = { [1] = 1, [2] = 17, [3] = 3 }

Config.UnitBlips = { Enabled = true, IntervalMs = 4000 }  -- show on-duty colleagues on the map

Config.IgnoreOnDutyResponders = true     -- on-duty responders do not trigger automatic crime alerts
Config.WitnessDelay = { min = 4, max = 15 }   -- seconds before an automatic alert reaches dispatch

-- Automatic alerts are triggered by the client but validated and positioned by the server.
Config.Alerts = {
    shooting          = { enabled = true, title = 'Shots fired', desc = 'Reports of gunfire in the area.', priority = 1, services = { 'police' }, cooldown = 30, chance = 90 },
    shooting_silenced = { enabled = true, title = 'Suspicious noises', desc = 'Muffled gunfire reported.', priority = 2, services = { 'police' }, cooldown = 45, chance = 30 },
    carjacking        = { enabled = true, title = 'Carjacking', desc = 'A vehicle was taken by force.', priority = 1, services = { 'police' }, cooldown = 60, chance = 85 },
    fight             = { enabled = true, title = 'Fight in progress', desc = 'People are fighting.', priority = 2, services = { 'police' }, cooldown = 60, chance = 60 },
    speeding          = { enabled = true, title = 'Reckless driver', desc = 'A vehicle is driving at dangerous speed.', priority = 3, services = { 'police' }, cooldown = 90, chance = 40, limit = 170 }, -- km/h
}

Config.IgnoreWeapons = { 'WEAPON_STUNGUN', 'WEAPON_STUNGUN_MP', 'WEAPON_FIREEXTINGUISHER', 'WEAPON_PETROLCAN', 'WEAPON_HAZARDCAN', 'WEAPON_FLARE', 'WEAPON_SNOWBALL', 'WEAPON_BALL' }

-- No alerts inside these zones (shooting ranges etc.). Examples - adjust to your map.
Config.IgnoreZones = {
    { coords = vec3(12.0, -1097.0, 29.8), radius = 50.0 },
}

-- /911 message triage. Keywords decide who is notified and the priority (1 = highest).
Config.Triage = {
    { words = { 'shot', 'shooting', 'gun', 'armed', 'stabbed', 'hostage', 'kidnap' }, services = { 'police' }, priority = 1, title = 'Armed threat' },
    { words = { 'bleeding', 'unconscious', 'overdose', 'heart', 'dying', 'injured', 'hurt' }, services = { 'ems' }, priority = 1, title = 'Medical emergency' },
    { words = { 'accident', 'crash', 'collision' }, services = { 'police', 'ems' }, priority = 2, title = 'Traffic collision' },
    { words = { 'robbery', 'robbing', 'stole', 'theft', 'burglar', 'break-in' }, services = { 'police' }, priority = 2, title = 'Crime in progress' },
}
Config.TriageFallback = { services = { 'police' }, priority = 3, title = 'Citizen call' }
Config.CommandCooldown = 30              -- seconds between /911 or /panic uses

Config.Panic = { Enabled = true, title = 'PANIC BUTTON', desc = 'A responder needs immediate assistance.' }

-- Adaptive incident generator: creates calls while responders are online.
Config.AI = { Enabled = true, MinMinutes = 6, MaxMinutes = 14, MinResponders = 1, MaxOpen = 4 }

Config.Scenarios = {
    {
        id = 'store_robbery', title = 'Store robbery', services = { 'police' }, priority = 1, weight = 3, cooldown = 25,
        descs = { 'Armed suspect demanding cash from the clerk.', 'Clerk activated the silent alarm.' },
        locations = { vec3(25.7, -1347.3, 29.5), vec3(-47.0, -1757.5, 29.4), vec3(1163.4, -323.8, 69.2), vec3(-707.5, -914.3, 19.2) },
    },
    {
        id = 'collision', title = 'Traffic collision', services = { 'police', 'ems' }, priority = 2, weight = 4, cooldown = 15,
        descs = { 'Two vehicles collided, possible injuries.', 'Single vehicle crash, driver still inside.' },
        locations = { vec3(240.0, -760.0, 30.8), vec3(-540.0, -210.0, 37.6), vec3(1140.0, -780.0, 57.6) },
    },
    {
        id = 'collapse', title = 'Person collapsed', services = { 'ems' }, priority = 2, weight = 3, cooldown = 15,
        descs = { 'Bystander reports an unresponsive person.', 'Elderly person fell and cannot get up.' },
        locations = { vec3(195.2, -934.5, 30.7), vec3(-1850.0, -1230.0, 13.0), vec3(1050.0, -250.0, 70.0) },
    },
    {
        id = 'assault', title = 'Assault', services = { 'police', 'ems' }, priority = 2, weight = 2, cooldown = 25,
        descs = { 'Victim attacked outside a bar.', 'Group assault reported, victim injured.' },
        locations = { vec3(118.0, -1950.0, 20.7), vec3(300.0, 180.0, 104.0) },
    },
    {
        id = 'suspicious', title = 'Suspicious person', services = { 'police' }, priority = 3, weight = 4, cooldown = 10,
        descs = { 'Individual looking into parked cars.', 'Person loitering near a closed business.' },
        locations = { vec3(1960.0, 3740.0, 32.3), vec3(-100.0, 6460.0, 31.6), vec3(-1037.0, -2737.0, 20.2) },
    },
    {
        id = 'reckless', title = 'Reckless driver', services = { 'police' }, priority = 2, weight = 3, cooldown = 15,
        descs = { 'Vehicle weaving through traffic at high speed.' },
        locations = { vec3(-1500.0, -600.0, 30.0), vec3(1200.0, -1500.0, 35.0) },
    },
    {
        id = 'noise', title = 'Noise complaint', services = { 'police' }, priority = 3, weight = 3, cooldown = 10,
        descs = { 'Loud party disturbing the neighborhood.' },
        locations = { vec3(118.0, -1950.0, 20.7), vec3(1050.0, -250.0, 70.0) },
    },
}

-- Optional Discord webhook for dispatch logs (leave '' to disable)
Config.Webhook = ''
