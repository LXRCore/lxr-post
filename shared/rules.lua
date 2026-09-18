--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-POST — Shared rules: rates, words, addresses
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

LXRPost = LXRPost or {}
local P = LXRPost

function P.Office(id) for _, o in ipairs(Config.Offices) do if o.id == id then return o end end end
function P.Box(job) for _, b in ipairs(Config.Boxes) do if b.job == job then return b end end end

---Word count of a body.
function P.Words(body)
    local n = 0
    for _ in tostring(body or ''):gmatch('%S+') do n = n + 1 end
    return n
end

---What a piece of mail costs; returns price or nil, reason.
function P.Cost(kind, body)
    body = tostring(body or '')
    if kind == 'letter' then
        if #body == 0 or #body > Config.Rates.letter.maxChars then return nil, 'too_long' end
        return Config.Rates.letter.stamp
    elseif kind == 'telegram' then
        local w = P.Words(body)
        if w == 0 or w > Config.Rates.telegram.maxWords then return nil, 'too_long' end
        return math.max(Config.Rates.telegram.minimum, math.floor(w * Config.Rates.telegram.perWord * 100 + 0.5) / 100)
    end
    return nil, 'invalid'
end

---Seconds until delivery.
function P.Delay(kind) return kind == 'letter' and Config.Rates.letter.deliveryMinutes * 60 or 0 end

---Clean a subject / body: no markup, trimmed.
function P.Clean(s, max)
    s = tostring(s or ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if max and #s > max then s = s:sub(1, max) end
    return s
end

---Is an address a trade box? Returns the job or nil.
function P.BoxOf(address)
    local job = tostring(address or ''):match('^job:([%w_]+)$')
    return job and P.Box(job) and job or nil
end
