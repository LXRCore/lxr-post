--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-POST — Client: the clerk, the desk, the reader
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local N = Citizen.InvokeNative
local clerks, open, current = {}, false, nil

local function toast(key, kind, vars) LXRCore.Notify(Lang:t(key, vars), kind or 'info') end
local function page(action, payload) SendNUIMessage({ action = action, payload = payload, brand = LXRCore.Brand, lang = Config.Lang, locale = Lang.bundle() }) end
local function close() if not open then return end open = false current = nil SetNuiFocus(false, false) page('close') end
local function openDesk(o)
    if open then return end
    local ok, data = LXR.RPC.Server('lxr-post:open', o.id)
    if not ok then return toast('error.' .. tostring(data), 'error') end
    open = true current = o
    SetNuiFocus(true, true)
    page('open', data)
end
local function relay(name, ...)
    local ok, res, extra = LXR.RPC.Server(name, current and current.id or nil, ...)
    if not ok then toast('error.' .. tostring(res), 'error', { amount = extra and ('%.2f'):format(extra) }) return { ok = false } end
    return { ok = true, data = res }
end

RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('find', function(d, cb) local ok, res = LXR.RPC.Server('lxr-post:find', d.q) cb({ ok = ok, people = ok and res or {} }) end)
RegisterNUICallback('send', function(d, cb) if not current then return cb({ ok = false }) end local r = relay('lxr-post:send', d.kind, d.address, d.toName, d.subject, d.body) if r.ok then toast('info.sent', 'success') end cb(r) end)
RegisterNUICallback('read', function(d, cb) cb(relay('lxr-post:read', d.id)) end)
RegisterNUICallback('collect', function(d, cb) if not current then return cb({ ok = false }) end cb(relay('lxr-post:collect', d.id)) end)
RegisterNUICallback('burn', function(d, cb) cb(relay('lxr-post:burn', d.id)) end)

-- the reader: a letter or telegram item opened from the satchel
local reading = false
RegisterNetEvent('lxr-post:client:read', function(info)
    if open then return end
    reading = true
    SetNuiFocus(true, true)
    page('reader', info)
end)
RegisterNUICallback('closeReader', function(_, cb) reading = false SetNuiFocus(false, false) page('close') cb({ ok = true }) end)

local function spawnClerk(o)
    local model = joaat(o.ped)
    if not IsModelValid(model) then return end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return end
    local ped = CreatePed(model, o.coords.x, o.coords.y, o.coords.z - 1.0, o.heading or 0.0, false, false, false, false)
    N(0x283978A15512B2FE, ped, true)
    SetEntityInvincible(ped, true) SetBlockingOfNonTemporaryEvents(ped, true) FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(model)
    clerks[o.id] = ped
    exports['lxr-interact']:AddEntity('lxr-post:' .. o.id, ped, { label = o.label, distance = Config.Security.promptDistance, options = { { label = Lang:t('ui.the_desk'), key = 'J', onSelect = function() openDesk(o) end } } })
end
local function removeClerk(o)
    local ped = clerks[o.id]
    if not ped then return end
    exports['lxr-interact']:Remove('lxr-post:' .. o.id)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    clerks[o.id] = nil
end

CreateThread(function()
    while GetResourceState('lxr-interact') ~= 'started' do Wait(1000) end
    for _, o in ipairs(Config.Offices) do
        if o.blip then local b = N(0x554D9D53F696D002, 1664425300, o.coords.x, o.coords.y, o.coords.z) if b and b ~= 0 then N(0x74F74D3207ED525C, b, joaat('blip_post_office'), true) N(0x9CB1A1623062F402, b, o.label) end end
    end
    while true do
        if LocalPlayer.state.isLoggedIn then
            local pos = GetEntityCoords(PlayerPedId())
            for _, o in ipairs(Config.Offices) do
                local d = #(pos - o.coords)
                if d < 60.0 and not clerks[o.id] then spawnClerk(o) elseif d > 80.0 and clerks[o.id] then removeClerk(o) end
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent('lxr:client:unloaded', function() close() for _, o in ipairs(Config.Offices) do removeClerk(o) end end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then close() for _, o in ipairs(Config.Offices) do removeClerk(o) end end end)
exports('IsOpen', function() return open or reading end)
exports('Unread', function() return LocalPlayer.state[Config.Inbox.stateBag] or 0 end)
