--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-POST — Offline tests: rates, words, addresses, cleaning, locale parity
     Usage (from the lxr-post folder):  lua tests/run.lua [--mock out.js en|ka]
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local CORE = os.getenv('LXR_CORE_PATH') or '../lxr-core'
package.path = CORE .. '/?.lua;' .. package.path
local ok = pcall(function() require('tests.lib.fxshim') end)
if not ok then print('lxr-core shim not found at ' .. CORE) os.exit(2) end
local Shim = require('tests.lib.fxshim')
for _, f in ipairs({ 'shared/main.lua', 'shared/locale.lua', 'locales/en.lua', 'config.lua', 'shared/catalog.lua', 'shared/items.lua', 'shared/prices.lua', 'shared/jobs.lua' }) do Shim.load(CORE .. '/' .. f) end
Config = nil Locale = nil
Shim.load('shared/locale.lua') Shim.load('locales/en.lua') Shim.load('locales/ka.lua') Shim.load('config.lua') Shim.load('shared/rules.lua')
local P = LXRPost

local passed, failed = 0, 0
local function test(name, fn) local okT, err = xpcall(fn, debug.traceback) if okT then passed = passed + 1 print('  ^ ok   ' .. name) else failed = failed + 1 print('  x FAIL ' .. name .. '\n' .. err) end end
local function eq(a, b, msg) if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ' got ' .. tostring(a), 2) end end

print('lxr-post offline tests')
test('offices, items and boxes are real', function()
    for _, o in ipairs(Config.Offices) do assert(P.Office(o.id) == o) assert(o.ped and o.coords) end
    assert(LXRShared.Items[Config.Rates.letter.item] and LXRShared.Items[Config.Rates.telegram.item])
    for _, b in ipairs(Config.Boxes) do assert(LXRShared.Jobs[b.job], b.job) assert(P.Box(b.job) == b) end
end)
test('rates: a stamp for a letter, by the word for a telegram, bounds', function()
    eq(P.Cost('letter', 'Dear Nino, the cows are fine.'), Config.Rates.letter.stamp)
    local c, why = P.Cost('letter', '') assert(c == nil) eq(why, 'too_long')
    eq(P.Words('COME HOME STOP MOTHER ILL STOP'), 6)
    eq(P.Cost('telegram', 'COME HOME STOP MOTHER ILL STOP'), math.max(Config.Rates.telegram.minimum, math.floor(6 * Config.Rates.telegram.perWord * 100 + 0.5) / 100))
    local long = string.rep('word ', Config.Rates.telegram.maxWords + 1)
    local c2, why2 = P.Cost('telegram', long) assert(c2 == nil) eq(why2, 'too_long')
    assert(P.Cost('note', 'x') == nil)
    eq(P.Delay('letter'), Config.Rates.letter.deliveryMinutes * 60) eq(P.Delay('telegram'), 0)
end)
test('addresses and cleaning', function()
    eq(P.BoxOf('job:vallaw'), 'vallaw') assert(P.BoxOf('job:nothing') == nil) assert(P.BoxOf('LXR123') == nil)
    eq(P.Clean('  <b>hi</b>  ', 10), 'bhi/b') eq(P.Clean('abcdefghijk', 5), 'abcde')
end)
test('locale parity', function()
    local en, ka = Locale.Bundles.en, Locale.Bundles.ka
    local missing = {}
    for k in pairs(en) do if ka[k] == nil then missing[#missing + 1] = k end end
    eq(#missing, 0, 'ka missing: ' .. table.concat(missing, ', '))
end)
print(('%d passed, %d failed'):format(passed, failed))
if arg and arg[1] == '--mock' and arg[2] then
    Config.Lang = arg[3] or 'en'
    local inbox = {
        { id = 12, from = 'Nino Kvaratskhelia', to = 'Sadie Adler', kind = 'letter', subject = 'The cows', body = 'Dear Sadie,\n\nThe cows are fine and the fence is not. Come by when the rain stops; the doctor says the leg will hold.\n\nYours,\nNino', dated = '1899-05-11', arrived = true, arrivesIn = 0, read = false },
        { id = 11, from = 'Tomas Reyes', to = 'Sadie Adler', kind = 'telegram', subject = 'RHODES', body = 'COME TO RHODES STOP BRING THE PAPERS STOP', dated = '1899-05-12', arrived = true, arrivesIn = 0, read = true },
        { id = 13, from = 'Grace Delacroix', to = 'Valentine Sheriff', box = 'Valentine Sheriff', kind = 'letter', subject = 'Complaint', body = 'Sheriff, the drunks again.', dated = '1899-05-12', arrived = true, arrivesIn = 0, read = false },
        { id = 14, from = 'Cole Bennett', to = 'Sadie Adler', kind = 'letter', subject = 'Later', body = nil, dated = '1899-05-12', arrived = false, arrivesIn = 1140, read = false },
    }
    local sent = { { id = 9, to = 'Nino Kvaratskhelia', kind = 'letter', subject = 'About the fence', dated = '1899-05-10', arrived = true, arrivesIn = 0 }, { id = 10, to = 'Valentine Doctor', kind = 'telegram', subject = 'LEG', dated = '1899-05-11', arrived = true, arrivesIn = 0 } }
    local boxes = {}
    for _, b in ipairs(Config.Boxes) do boxes[#boxes + 1] = { address = 'job:' .. b.job, label = b.label } end
    local f = assert(io.open(arg[2], 'w'))
    f:write('window.__LXR_MOCK__ = ' .. json.encode({ action = 'open', payload = { office = { id = 'valentine', label = 'Valentine Post Office' }, me = 'Sadie Adler', inbox = inbox, sent = sent, boxes = boxes, rates = { stamp = Config.Rates.letter.stamp, deliveryMinutes = Config.Rates.letter.deliveryMinutes, perWord = Config.Rates.telegram.perWord, minimum = Config.Rates.telegram.minimum, maxWords = Config.Rates.telegram.maxWords, maxChars = Config.Rates.letter.maxChars, subjectMax = Config.Rates.subjectMax }, cash = 4.35, date = '1899-05-12' }, lang = Config.Lang, locale = Lang.bundle(), brand = { name = 'The Land of Wolves', theme = 'night' } }) .. ';\n')
    f:close()
    print('mock written to ' .. arg[2])
end
os.exit(failed == 0 and 0 or 1)
