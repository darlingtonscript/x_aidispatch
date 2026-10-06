--[[
    X AI Dispatch  |  by MR X  |  X Studio
    Framework bridge: QBox / QBCore / ESX / standalone (ACE permissions)
]]

Bridge = {}

local fw, QBCore, ESX

local function started(name)
    return GetResourceState(name) == 'started'
end

local function detect()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if started('qbx_core') then return 'qbox' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    return nil
end

function Bridge.Init()
    local tries = 0
    fw = detect()
    while not fw and tries < 30 do
        Wait(500)
        tries += 1
        fw = detect()
    end
    fw = fw or 'standalone'

    if fw == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif fw == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    end
    return fw
end

function Bridge.Mode()
    return fw or 'standalone'
end

local function getPlayer(src)
    if fw == 'qbox' then return exports.qbx_core:GetPlayer(src) end
    if fw == 'qb' then return QBCore.Functions.GetPlayer(src) end
    if fw == 'esx' then return ESX.GetPlayerFromId(src) end
end

-- returns jobName, onDuty
function Bridge.GetJob(src)
    local p = getPlayer(src)
    if not p then return nil, false end
    if fw == 'qbox' or fw == 'qb' then
        local job = p.PlayerData.job
        return job and job.name, job and job.onduty == true
    elseif fw == 'esx' then
        local name = p.job and p.job.name
        -- ESX has no native duty flag; the common "off<job>" convention marks off duty
        return name, name ~= nil and name:sub(1, 3) ~= 'off'
    end
    return nil, false
end

function Bridge.GetName(src)
    local p = getPlayer(src)
    if p then
        if (fw == 'qbox' or fw == 'qb') and p.PlayerData.charinfo then
            return ('%s %s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname)
        elseif fw == 'esx' then
            return p.getName()
        end
    end
    return GetPlayerName(src) or 'Unit'
end
