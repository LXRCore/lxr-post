--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-POST — Server: the mail bag
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local P = LXRPost
local RES = GetCurrentResourceName()
local buckets = {}

local function limited(src)
    local b = buckets[src]
    local now = GetGameTimer()
    if not b or now - b.at > Config.Security.rateLimit.windowMs then b = { at = now, n = 0 } buckets[src] = b end
    b.n = b.n + 1
    return b.n > Config.Security.rateLimit.burst
end
local function player(src) return LXRCore.Functions.GetPlayer(src) end
local function near(src, c)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= Config.Security.maxDistance
end
local function nameOf(Pl) local c = Pl.PlayerData.charinfo or {} return ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', '') end
local function decode(s) local ok, t = pcall(json.decode, s or '') return ok and type(t) == 'table' and t or {} end
local function gameDate()
    local cal = GlobalState.calendar
    if cal then return ('%04d-%02d-%02d'):format(cal.year or 1899, cal.month or 1, cal.day or 1) end
    return os.date('1899-%m-%d')
end

LXRCore.DB.RegisterMigration(RES, '0001_post', [[
CREATE TABLE IF NOT EXISTS `lxr_post_mail` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `address` VARCHAR(64) NOT NULL,
  `from_cid` VARCHAR(50) NOT NULL,
  `from_name` VARCHAR(80) NOT NULL,
  `to_name` VARCHAR(80) NOT NULL,
  `kind` VARCHAR(12) NOT NULL,
  `subject` VARCHAR(64) NOT NULL,
  `body` TEXT NOT NULL,
  `sent_at` INT NOT NULL,
  `deliver_at` INT NOT NULL,
  `dated` VARCHAR(12) NOT NULL,
  `read_by` TEXT NULL,
  `collected` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`), KEY `address` (`address`), KEY `from_cid` (`from_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

---addresses a player may read: their own and their trade's box
local function addressesOf(Pl)
    local out = { Pl.PlayerData.citizenid }
    local job = Pl.PlayerData.job
    local box = P.Box(job.name)
    if box and (tonumber(job.grade) or 0) >= (box.minGrade or 0) then out[#out + 1] = 'job:' .. job.name end
    return out
end
local function unread(Pl)
    local n = 0
    for _, a in ipairs(addressesOf(Pl)) do
        local rows = LXRCore.DB.Query('SELECT id, read_by FROM lxr_post_mail WHERE address = ? AND deliver_at <= ? AND collected = 0', { a, os.time() }) or {}
        for _, r in ipairs(rows) do local rb = decode(r.read_by) local seen = false for _, c in ipairs(rb) do if c == Pl.PlayerData.citizenid then seen = true end end if not seen then n = n + 1 end end
    end
    return n
end
local function publish(src)
    local Pl = player(src)
    if Pl then Player(src).state:set(Config.Inbox.stateBag, unread(Pl), true) end
end
local function inbox(Pl)
    local now, out = os.time(), {}
    for _, a in ipairs(addressesOf(Pl)) do
        local rows = LXRCore.DB.Query('SELECT id, address, from_name, to_name, kind, subject, body, sent_at, deliver_at, dated, read_by, collected FROM lxr_post_mail WHERE address = ? AND collected = 0 ORDER BY deliver_at DESC LIMIT ?', { a, Config.Inbox.keep }) or {}
        for _, r in ipairs(rows) do
            local rb = decode(r.read_by) local seen = false for _, c in ipairs(rb) do if c == Pl.PlayerData.citizenid then seen = true end end
            out[#out + 1] = { id = r.id, box = r.address:match('^job:') and P.Box(r.address:sub(5)) and P.Box(r.address:sub(5)).label or nil, from = r.from_name, to = r.to_name, kind = r.kind, subject = r.subject, body = r.deliver_at <= now and r.body or nil, dated = r.dated, arrived = r.deliver_at <= now, arrivesIn = math.max(0, r.deliver_at - now), read = seen }
        end
    end
    table.sort(out, function(x, y) return (x.arrived and 1 or 0) > (y.arrived and 1 or 0) or (x.arrived == y.arrived and x.id > y.id) end)
    return out
end
local function sent(Pl)
    local rows = LXRCore.DB.Query('SELECT id, to_name, kind, subject, sent_at, deliver_at, dated FROM lxr_post_mail WHERE from_cid = ? ORDER BY id DESC LIMIT 60', { Pl.PlayerData.citizenid }) or {}
    local out, now = {}, os.time()
    for _, r in ipairs(rows) do out[#out + 1] = { id = r.id, to = r.to_name, kind = r.kind, subject = r.subject, dated = r.dated, arrived = r.deliver_at <= now, arrivesIn = math.max(0, r.deliver_at - now) } end
    return out
end
local function book(src, office)
    local Pl = player(src)
    local boxes = {}
    for _, b in ipairs(Config.Boxes) do boxes[#boxes + 1] = { address = 'job:' .. b.job, label = b.label } end
    return { office = { id = office.id, label = office.label }, me = nameOf(Pl), inbox = inbox(Pl), sent = sent(Pl), boxes = boxes, rates = { stamp = Config.Rates.letter.stamp, deliveryMinutes = Config.Rates.letter.deliveryMinutes, perWord = Config.Rates.telegram.perWord, minimum = Config.Rates.telegram.minimum, maxWords = Config.Rates.telegram.maxWords, maxChars = Config.Rates.letter.maxChars, subjectMax = Config.Rates.subjectMax }, cash = Pl.PlayerData.money[Config.Rates.account] or 0, date = gameDate() }
end

LXR.RPC.Register('lxr-post:open', function(src, officeId)
    if limited(src) then return false, 'rate' end
    local Pl, office = player(src), P.Office(officeId)
    if not Pl or not office then return false, 'invalid' end
    if not near(src, office.coords) then return false, 'too_far' end
    return true, book(src, office)
end)

---find people by name (three letters at least): the clerk knows the town
LXR.RPC.Register('lxr-post:find', function(src, q)
    if limited(src) then return false, 'rate' end
    q = P.Clean(q, 40)
    if #q < 3 then return true, {} end
    local rows = LXRCore.DB.Query('SELECT citizenid, charinfo FROM players WHERE charinfo LIKE ? LIMIT 12', { '%' .. q .. '%' }) or {}
    local out = {}
    for _, r in ipairs(rows) do local c = decode(r.charinfo) local name = ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', '') if name:lower():find(q:lower(), 1, true) then out[#out + 1] = { citizenid = r.citizenid, name = name } end end
    return true, out
end)

LXR.RPC.Register('lxr-post:send', function(src, officeId, kind, address, toName, subject, body)
    if limited(src) then return false, 'rate' end
    local Pl, office = player(src), P.Office(officeId)
    if not Pl or not office then return false, 'invalid' end
    if not near(src, office.coords) then return false, 'too_far' end
    subject, body = P.Clean(subject, Config.Rates.subjectMax), P.Clean(body)
    local price, why = P.Cost(kind, body)
    if not price then return false, why end
    address = tostring(address or '')
    local label
    if P.BoxOf(address) then label = P.Box(P.BoxOf(address)).label
    else
        local row = LXRCore.DB.Single('SELECT citizenid, charinfo FROM players WHERE citizenid = ?', { address })
        if not row then return false, 'nobody' end
        local c = decode(row.charinfo) label = ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', '')
    end
    if address == Pl.PlayerData.citizenid then return false, 'yourself' end
    if not Pl.Functions.RemoveMoney(Config.Rates.account, price, 'post:' .. kind) then return false, 'no_money', price end
    local now = os.time()
    local id = LXRCore.DB.Insert('INSERT INTO lxr_post_mail (address, from_cid, from_name, to_name, kind, subject, body, sent_at, deliver_at, dated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { address, Pl.PlayerData.citizenid, nameOf(Pl), label, kind, subject, body, now, now + P.Delay(kind), gameDate() })
    if P.Delay(kind) == 0 then
        if P.BoxOf(address) then
            for _, T in pairs(LXRCore.Players) do if T.PlayerData.job.name == P.BoxOf(address) then LXRCore.Notify(T.PlayerData.source, Lang:t('info.telegram_box', { box = label, from = nameOf(Pl) }), 'info', 8000) publish(T.PlayerData.source) end end
        else
            local T = LXRCore.Functions.GetPlayerByCitizenId(address)
            if T then LXRCore.Notify(T.PlayerData.source, Lang:t('info.telegram_in', { from = nameOf(Pl) }), 'info', 8000) publish(T.PlayerData.source) end
        end
    end
    LXRCore.Emit('lxr:post:sent', nil, src, id, kind, address)
    if Config.Debug.log then LXRCore.Log.info('post', ('%s to %s ($%.2f)'):format(kind, label, price), { source = src }) end
    return true, book(src, office)
end)

LXR.RPC.Register('lxr-post:read', function(src, officeId, id)
    if limited(src) then return false, 'rate' end
    local Pl, office = player(src), P.Office(officeId)
    if not Pl or not office then return false, 'invalid' end
    local row = LXRCore.DB.Single('SELECT id, address, read_by, deliver_at FROM lxr_post_mail WHERE id = ?', { tonumber(id) or -1 })
    if not row or row.deliver_at > os.time() then return false, 'invalid' end
    local mine = false for _, a in ipairs(addressesOf(Pl)) do if a == row.address then mine = true end end
    if not mine then return false, 'invalid' end
    local rb = decode(row.read_by) local seen = false for _, c in ipairs(rb) do if c == Pl.PlayerData.citizenid then seen = true end end
    if not seen then rb[#rb + 1] = Pl.PlayerData.citizenid LXRCore.DB.Update('UPDATE lxr_post_mail SET read_by = ? WHERE id = ?', { json.encode(rb), row.id }) end
    publish(src)
    return true
end)

---take a letter home: it becomes the catalog item with the text inside; telegrams the same
LXR.RPC.Register('lxr-post:collect', function(src, officeId, id)
    if limited(src) then return false, 'rate' end
    local Pl, office = player(src), P.Office(officeId)
    if not Pl or not office then return false, 'invalid' end
    if not near(src, office.coords) then return false, 'too_far' end
    local row = LXRCore.DB.Single('SELECT id, address, from_name, to_name, kind, subject, body, dated, deliver_at FROM lxr_post_mail WHERE id = ? AND collected = 0', { tonumber(id) or -1 })
    if not row or row.deliver_at > os.time() or row.address ~= Pl.PlayerData.citizenid then return false, 'invalid' end
    local item = row.kind == 'telegram' and Config.Rates.telegram.item or Config.Rates.letter.item
    if not LXRCore.Inventory.CanCarry(src, item, 1) then return false, 'too_heavy' end
    if not Pl.Functions.AddItem(item, 1, nil, { from = row.from_name, to = row.to_name, subject = row.subject, body = row.body, dated = row.dated, kind = row.kind }, 'post:collected') then return false, 'too_heavy' end
    LXRCore.DB.Update('UPDATE lxr_post_mail SET collected = 1 WHERE id = ?', { row.id })
    publish(src)
    return true, book(src, office)
end)

LXR.RPC.Register('lxr-post:burn', function(src, officeId, id)
    if limited(src) then return false, 'rate' end
    local Pl = player(src)
    if not Pl then return false, 'invalid' end
    local row = LXRCore.DB.Single('SELECT id, address FROM lxr_post_mail WHERE id = ?', { tonumber(id) or -1 })
    if not row or row.address ~= Pl.PlayerData.citizenid then return false, 'invalid' end
    LXRCore.DB.Update('DELETE FROM lxr_post_mail WHERE id = ?', { row.id })
    publish(src)
    local office = P.Office(officeId)
    return true, office and book(src, office) or nil
end)

-- the letter item opens the reader
for _, item in ipairs({ Config.Rates.letter.item, Config.Rates.telegram.item }) do
    LXRCore.Items.RegisterUsable(item, function(src, it) if it.info and it.info.body then TriggerClientEvent('lxr-post:client:read', src, it.info) end end)
end

-- deliveries: once a minute, tell whoever is online that something arrived
CreateThread(function()
    local last = os.time()
    while true do
        Wait(60000)
        local now = os.time()
        local rows = LXRCore.DB.Query('SELECT address, from_name, kind FROM lxr_post_mail WHERE deliver_at > ? AND deliver_at <= ? AND kind = ?', { last, now, 'letter' }) or {}
        last = now
        for _, r in ipairs(rows) do
            if P.BoxOf(r.address) then for _, T in pairs(LXRCore.Players) do if T.PlayerData.job.name == P.BoxOf(r.address) then LXRCore.Notify(T.PlayerData.source, Lang:t('info.letter_box', { box = P.Box(P.BoxOf(r.address)).label }), 'info', 8000) publish(T.PlayerData.source) end end
            else local T = LXRCore.Functions.GetPlayerByCitizenId(r.address) if T then LXRCore.Notify(T.PlayerData.source, Lang:t('info.letter_in', { from = r.from_name }), 'info', 8000) publish(T.PlayerData.source) end end
        end
    end
end)

AddEventHandler('lxr:player:loaded', function(src) Wait(1000) publish(src) end)
AddEventHandler('playerDropped', function() buckets[source] = nil end)
CreateThread(function() if Config.Debug.printBanner then print(('^1[lxr-post]^7 v%s — %d offices, %d trade boxes'):format(GetResourceMetadata(RES, 'version', 0), #Config.Offices, #Config.Boxes)) end end)
exports('Send', function(address, fromName, kind, subject, body) local now = os.time() return LXRCore.DB.Insert('INSERT INTO lxr_post_mail (address, from_cid, from_name, to_name, kind, subject, body, sent_at, deliver_at, dated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { address, 'system', fromName or 'The Post', address, kind or 'telegram', P.Clean(subject, Config.Rates.subjectMax), P.Clean(body), now, now + P.Delay(kind or 'telegram'), gameDate() }) end)
exports('Unread', function(src) local Pl = player(src) return Pl and unread(Pl) or 0 end)
