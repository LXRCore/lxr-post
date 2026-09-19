--[[
    ██╗     ██╗  ██╗██████╗       ██████╗  ██████╗ ███████╗████████╗
    ██║     ╚██╗██╔╝██╔══██╗      ██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝
    ██║      ╚███╔╝ ██████╔╝█████╗██████╔╝██║   ██║███████╗   ██║
    ██║      ██╔██╗ ██╔══██╗╚════╝██╔═══╝ ██║   ██║╚════██║   ██║
    ███████╗██╔╝ ██╗██║  ██║      ██║     ╚██████╔╝███████║   ██║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝      ╚═════╝ ╚══════╝   ╚═╝

    LXR Core - Post

    The mail. A letter is written at a post office, costs a stamp, and
    travels — it is waiting at any office after the delay. A telegram
    costs by the word and is there at once. Mail is addressed to a person
    by name, or to a trade's box (the sheriff's office, the doctor's) that
    every member on the roll can read. Collected letters are catalog items
    the reader opens; the unread count sits in a state bag for the frame.

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/GAhk8cgXe9
    GitHub:      https://github.com/LXRCore

    Version: 3.0.0
    Performance Target: 0.00 ms idle (interact points; one minute tick on the server for deliveries)

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

Config = Config or {}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ LANGUAGE ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Lang = 'en'

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ OFFICES ═══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Offices = {
    { id = 'valentine',  label = 'Valentine Post Office',   coords = vector3(-178.30, 630.30, 114.10), heading = 90.0,  ped = 'u_m_m_valpostmaster_01', blip = true },
    { id = 'rhodes',     label = 'Rhodes Post Office',      coords = vector3(1226.60, -1296.30, 76.90), heading = 180.0, ped = 'u_m_m_rhdtrainstationclerk_01', blip = true },
    { id = 'saintdenis', label = 'Saint Denis Post Office', coords = vector3(2748.70, -1399.10, 46.20), heading = 270.0, ped = 'u_m_m_sdtrainstationclerk_01', blip = true },
    { id = 'blackwater', label = 'Blackwater Post Office',  coords = vector3(-873.40, -1332.10, 43.50), heading = 0.0,   ped = 'u_m_m_bwtstablehand_01', blip = true },
    { id = 'strawberry', label = 'Strawberry Post Office',  coords = vector3(-1765.30, -390.80, 156.80), heading = 90.0, ped = 'u_m_m_strwelcomecenter_01', blip = true },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ THE RATES (1899) ══════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Rates = {
    account = 'cash',
    letter = { stamp = 0.02, deliveryMinutes = 30, maxChars = 1200, item = 'letter' },   -- the collected letter is this catalog item
    telegram = { perWord = 0.05, minimum = 0.25, maxWords = 40, item = 'telegram' },
    subjectMax = 48,
}

-- trades with a box on the wall: mail to `job:<name>` is readable by anyone on that job (grade >= minGrade)
Config.Boxes = {
    { job = 'vallaw', label = 'Valentine Sheriff', minGrade = 0 },
    { job = 'rholaw', label = 'Rhodes Sheriff',    minGrade = 0 },
    { job = 'valdoc', label = 'Valentine Doctor',  minGrade = 0 },
}

Config.Inbox = { keep = 200, stateBag = 'mail' }   -- LocalPlayer.state.mail = unread count (the HUD may show it)
Config.Security = { rateLimit = { windowMs = 2000, burst = 6 }, maxDistance = 4.0, promptDistance = 2.5 }
Config.Debug = { printBanner = true, log = true }
