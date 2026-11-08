-- EmotaSpeak v0.3.0 — WoW Forever contextual emotes
-- Diagnostic-first character-immersion addon. Auto-emotes are OPT-IN.
-- No custom /e, outgoing chat, combat log, or forbidden secret-value calculations.

local addonName = ...
local frame = CreateFrame("Frame")
local settings
local inCombat = false
local combatStarted = 0
local guidToCompanion = {}
local lastAttempt = -1e8
local lastWaveReply = -1e8
local lastByReason = {}
local lowHPNoted = false
local lastLowHealthFrameState = nil
local lowHealthScanQueued = false
-- Per-login session pacing; intentionally not written to SavedVariables.
local idleSince = nil
local idleAfterSeconds = nil
local sessionJokeCount = 0
local idleTicker = nil

local function Hidden(value)
    return value ~= nil and type(issecretvalue) == "function" and issecretvalue(value)
end

local function Note(message, always)
    if always or (settings and settings.debug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff77ccffEmotaSpeak|r " .. message)
    end
end

local function Remember(unit, relation)
    local guid = UnitGUID(unit)
    if guid and not Hidden(guid) then
        guidToCompanion[guid] = relation
    end
end

local function RefreshCompanions()
    wipe(guidToCompanion)
    Remember("pet", "pet")
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            Remember("raid" .. index, "group")
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            Remember("party" .. index, "group")
        end
    end
end

local function ReportHealth()
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    local mana = UnitPower("player", 0)
    local maxMana = UnitPowerMax("player", 0)

    if Hidden(health) or Hidden(maxHealth) then
        Note("Player health is SECRET here; no HP comparison will be made.", true)
    elseif maxHealth and maxHealth > 0 then
        Note(("Readable player HP: %.1f%%"):format(100 * health / maxHealth), true)
    end

    if Hidden(mana) or Hidden(maxMana) then
        Note("Player mana is SECRET here; no mana comparison will be made.", true)
    elseif maxMana and maxMana > 0 then
        Note(("Readable player mana: %.1f%%"):format(100 * mana / maxMana), true)
    end
end

local function NativeEmote(token, reason, manual, targetName)
    if not C_ChatInfo or not C_ChatInfo.PerformEmote then
        Note("C_ChatInfo.PerformEmote does not exist in this client.", true)
        return
    end
    if not manual and not (settings and settings.auto) then
        return
    end

    local now = GetTime()
    if not manual then
        -- A single global cooldown and a longer per-trigger lock prevent spam.
        if now - lastAttempt < 45 or now - (lastByReason[reason] or -1e8) < 120 then
            return
        end
        lastAttempt = now
        lastByReason[reason] = now
    end

    if C_ChatInfo.InChatMessagingLockdown then
        local lockdown = C_ChatInfo.InChatMessagingLockdown()
        if Hidden(lockdown) or lockdown then
            Note("Skipped " .. token .. ": chat messaging is restricted.", true)
            return
        end
    end
    local _, instanceType = GetInstanceInfo()
    if instanceType == "pvp" or instanceType == "arena" then
        Note("Skipped emote attempt in a PvP instance.")
        return
    end

    -- pcall catches a Lua error; it does NOT bypass a protected-action rule.
    local ok, returned
    if targetName then
        ok, returned = pcall(C_ChatInfo.PerformEmote, token, targetName)
    else
        ok, returned = pcall(C_ChatInfo.PerformEmote, token)
    end
    if ok then
        -- A false return was observed even when Forever visibly played WAVE/TRAIN.
        -- Do not label this harmless return as an error or spam it in chat.
        -- It remains an observation, not proof of successful playback.
        Note(("Emote requested: %s (%s)"):format(token, reason), manual)
    else
        Note(("%s -> %s: API raised an error or restriction"):format(reason, token), true)
    end
end

local function React(token, reason, chance, targetName)
    if not settings or not settings.auto then
        return
    end
    if math.random() <= chance then
        NativeEmote(token, reason, false, targetName)
    end
end

-- Only replies to an English /wave clearly directed at our character.
-- No reply to untargeted emotes, our own emotes or another LivingSoul user
-- repeatedly responding: the 5-minute social lock prevents ping-pong loops.

-- Low-frequency idle behavior, driven by movement events rather than HP or combat data.
-- One random roll per stationary period, after a randomized delay.
-- Growing, randomly staggered intervals through a single play session.
-- First joke: ~1 minute. Second: 1–3m. Later: up to 5–10m.
local function NextIdleDelay()
    if sessionJokeCount == 0 then return 60 end
    if sessionJokeCount == 1 then return math.random(60, 180) end
    if sessionJokeCount == 2 then return math.random(90, 240) end
    if sessionJokeCount == 3 then return math.random(150, 360) end
    if sessionJokeCount == 4 then return math.random(240, 480) end
    return math.random(300, 600)
end

local function StartIdle()
    idleSince = GetTime()
    idleAfterSeconds = NextIdleDelay()
    Note(("Idle window begins; next joke in %ds (session jokes: %d)"):format(
        idleAfterSeconds, sessionJokeCount))
end

local function EndIdle()
    idleSince = nil
    idleAfterSeconds = nil
end

local function IdleIsSafe()
    if InCombatLockdown() then return false end

    -- A missed movement event shouldn't cause jokes while actively walking.
    if type(IsPlayerMoving) == "function" then
        local m = IsPlayerMoving()
        if Hidden(m) or m then return false end
    end

    -- No talking while dead, away from the keyboard, mounted or traveling.
    if type(UnitIsDeadOrGhost) == "function" then
        local dead = UnitIsDeadOrGhost("player")
        if Hidden(dead) or dead then return false end
    end
    if type(UnitIsAFK) == "function" then
        local afk = UnitIsAFK("player")
        if Hidden(afk) or afk then return false end
    end
    if type(IsMounted) == "function" then
        local mounted = IsMounted()
        if Hidden(mounted) or mounted then return false end
    end
    if type(UnitOnTaxi) == "function" then
        local onTaxi = UnitOnTaxi("player")
        if Hidden(onTaxi) or onTaxi then return false end
    end

    -- Avoid the immersion gag while dealing with a vendor or another player.
    for _, uiName in ipairs({"MerchantFrame", "TradeFrame", "BankFrame", "MailFrame"}) do
        local ui = _G[uiName]
        if ui and ui.IsShown then
            local visible = ui:IsShown()
            if Hidden(visible) or visible then return false end
        end
    end
    return true
end

local function CheckIdle()
    if not settings or not settings.auto or not settings.idleAuto then return end
    if not idleSince or not idleAfterSeconds then return end
    if GetTime() - idleSince < idleAfterSeconds then return end
    if GetTime() - lastAttempt < 120 then return end
    if not IdleIsSafe() then return end

    -- Blizzard chooses the voiced racial joke itself via JOKE (/silly).
    Note("Idle personality: requesting a voiced joke.")
    NativeEmote("JOKE", "idle-joke", false)
    sessionJokeCount = sessionJokeCount + 1
    -- Still standing? Schedule another with a longer random gap.
    StartIdle()
end

local function MaybeWaveBack(text, sender, target)
    if not settings or not settings.auto or InCombatLockdown() then return end
    if not text or not sender or Hidden(text) or Hidden(sender) or Hidden(target) then return end
    if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end
    local me = UnitName("player")
    if not me or sender == me or sender:match("^[^-]+") == me then return end
    local targetIsMe = target and (target == me or target:match("^[^-]+") == me)
    local isWaveToMe = text:lower():find("waves at you", 1, true)
    if not targetIsMe or not isWaveToMe then return end
    local now = GetTime()
    if now - lastWaveReply < 300 then return end
    lastWaveReply = now
    Note("Targeted /wave from " .. sender .. " detected.")
    React("WAVE", "wave-return", 1.0, sender)
end

local function OnDeath(guid)
    if not guid or Hidden(guid) then
        Note("UNIT_DIED received with unavailable/secret GUID; cannot identify unit.")
        return
    end
    local relation = guidToCompanion[guid]
    if relation == "pet" then
        Note("My pet died.")
        React("CRY", "pet-died", 1.0)
    elseif relation == "group" then
        Note("A party/raid member died.")
        React("MOURN", "group-died", 0.7)
    end
end

local function OnHealth(unit)
    if unit ~= "player" or InCombatLockdown() then
        return -- exact in-combat HP alerts are NOT supported
    end
    local hp = UnitHealth("player")
    local maxHP = UnitHealthMax("player")
    if Hidden(hp) or Hidden(maxHP) or not hp or not maxHP or maxHP <= 0 then
        return
    end
    local ratio = hp / maxHP
    if ratio >= 0.5 then
        lowHPNoted = false
    elseif ratio > 0 and ratio < 0.25 and not lowHPNoted then
        lowHPNoted = true
        Note("Below 25% health (out of combat).")
        React("HEALME", "low-hp-outside-combat", 0.7)
    end
end

-- Blizzard's visual low-health border is managed by LowHealthFrame.
-- The frame may also appear for a fullscreen-edge effect unrelated to low HP.
-- We NEVER call Blizzard's health evaluation functions or compare secret HP.
-- Reading a frame's shown state is only useful when its result is not secret.
local function ReadLowHealthFrame()
    local visual = _G.LowHealthFrame
    if not visual or type(visual.IsShown) ~= "function" then
        return "missing"
    end
    local ok, shown = pcall(visual.IsShown, visual)
    if not ok then
        return "unavailable"
    end
    if Hidden(shown) then
        return "secret"
    end
    if not shown then
        return "hidden"
    end

    -- Blizzard also shows LowHealthFrame in combat when a fullscreen panel
    -- needs an edge flash. Exclude that case rather than mislabel it as low HP.
    if type(GetUIPanel) ~= "function" then
        return "ambiguous"
    end
    local panelOK, panel = pcall(GetUIPanel, "fullscreen")
    if not panelOK or Hidden(panel) then
        return "ambiguous"
    end
    if panel then
        return "fullscreen"
    end
    return "shown"
end

local function SampleLowHealthFrame()
    if not settings then return end
    local state = ReadLowHealthFrame()
    if state ~= lastLowHealthFrameState then
        Note("Native LowHealthFrame state: " .. state)
        local old = lastLowHealthFrameState
        lastLowHealthFrameState = state
        if old == "hidden" and state == "shown" and settings.lowHealthAuto and settings.auto then
            Note("Native low-health border activated; requesting HEALME.")
            React("HEALME", "native-low-health-edge", 1.0)
        end
    end
end

local function QueueLowHealthFrameSample()
    if lowHealthScanQueued or not C_Timer or not C_Timer.After then return end
    lowHealthScanQueued = true
    -- Observe only AFTER Blizzard has had a chance to refresh the native frame.
    C_Timer.After(0, function()
        lowHealthScanQueued = false
        SampleLowHealthFrame()
    end)
end

local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end
        if type(EmotaSpeakDB) ~= "table" then EmotaSpeakDB = {} end
        EmotaSpeakDB.auto = EmotaSpeakDB.auto == true
        EmotaSpeakDB.debug = EmotaSpeakDB.debug == true
        EmotaSpeakDB.lowHealthAuto = EmotaSpeakDB.lowHealthAuto == true
        -- Idle jokes are on when master auto is enabled, unless disabled explicitly.
        EmotaSpeakDB.idleAuto = EmotaSpeakDB.idleAuto ~= false
        settings = EmotaSpeakDB
        if not idleTicker and C_Timer and C_Timer.NewTicker then
            idleTicker = C_Timer.NewTicker(5, CheckIdle)
        end
        Note("EmotaSpeak loaded. /emota help. Automatic emotes: " ..
            (settings.auto and "ON" or "OFF") .. ".", true)

    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        RefreshCompanions()
        QueueLowHealthFrameSample()
        if event == "PLAYER_ENTERING_WORLD" then
            EndIdle()
            if type(IsPlayerMoving) == "function" then
                local moving = IsPlayerMoving()
                if not Hidden(moving) and not moving then StartIdle() end
            end
        end
    elseif event == "PLAYER_STARTED_MOVING" then
        EndIdle()
    elseif event == "PLAYER_STOPPED_MOVING" then
        StartIdle()
    elseif event == "UNIT_PET" then
        local unit = ...
        if unit == "player" then
            local guid = UnitGUID("pet")
            if guid and not Hidden(guid) then
                guidToCompanion[guid] = "pet"
            end
        end
    elseif event == "UNIT_DIED" then
        OnDeath(...)
    elseif event == "UI_ERROR_MESSAGE" then
        local errorID, message = ...
        if message and not Hidden(message) then
            if ERR_OUT_OF_MANA and message == ERR_OUT_OF_MANA then
                Note("A cast failed because there was not enough mana.")
                React("OOM", "oom-cast-error", 1.0)
            elseif ERR_OUT_OF_FOCUS and message == ERR_OUT_OF_FOCUS then
                Note("An ability failed because there was not enough focus.")
                React("SIGH", "focus-cast-error", 0.25)
            elseif ERR_OUT_OF_ENERGY and message == ERR_OUT_OF_ENERGY then
                Note("An ability failed because there was not enough energy.")
                React("SIGH", "energy-cast-error", 0.2)
            end
        end
    elseif event == "UI_INFO_MESSAGE" then
        local infoID, message = ...
        if message and not Hidden(message) then
            if ERR_TRADE_COMPLETE and message == ERR_TRADE_COMPLETE then
                Note("Trade completed successfully.")
                React("BOW", "trade-complete", 0.85)
            elseif ERR_TRADE_CANCELLED and message == ERR_TRADE_CANCELLED then
                Note("Trade was canceled; no emote.")
            end
        end
    elseif event == "UNIT_COMBAT" then
        local unit, combatEvent = ...
        if unit == "player" and not Hidden(combatEvent) then
            if combatEvent == "DODGE" then
                Note("Dodged an attack.")
                React("LAUGH", "dodge", 0.04)
            elseif combatEvent == "PARRY" or combatEvent == "BLOCK" then
                Note("Parried or blocked.")
                React("FLEX", "defense", 0.03)
            end
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" then
            Note("My cast was interrupted.")
            React("SIGH", "interrupted", 0.08)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        combatStarted = GetTime()
        EndIdle()
        QueueLowHealthFrameSample()
        Note("Combat started.")
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        QueueLowHealthFrameSample()
        local duration = GetTime() - combatStarted
        Note(("Combat ended after %.1fs (does not imply kills)."):format(duration))
        if combatStarted > 0 and duration >= 20 then
            React("TRAIN", "long-fight-ended", 0.12)
        end
        combatStarted = 0
        -- The player may be standing still after combat without a STOPPED event.
        -- Start a fresh idle timer only if the movement API confirms stationary.
        if type(IsPlayerMoving) == "function" then
            local moving = IsPlayerMoving()
            if not Hidden(moving) and not moving then StartIdle() end
        end
    elseif event == "UNIT_HEALTH" then
        local unit = ...
        OnHealth(unit)
        if unit == "player" then QueueLowHealthFrameSample() end
    elseif event == "PLAYER_LEVEL_UP" then
        Note("Level up!")
        React("CHEER", "level-up", 1.0)
    elseif event == "QUEST_TURNED_IN" then
        Note("Quest turned in.")
        React("CHEER", "quest-turn-in", 0.12)
    elseif event == "PLAYER_UNGHOST" then
        Note("Returned from ghost form.")
        React("SIGH", "resurrection", 0.65)
    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        local text, sender, _, _, target = ...
        MaybeWaveBack(text, sender, target)
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local sourceAddon, functionName = ...
        if sourceAddon == addonName then
            Note("Blizzard blocked an addon action: " .. (Hidden(functionName) and "(secret)" or tostring(functionName)), true)
        end
    end
end

frame:SetScript("OnEvent", OnEvent)
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_PET",
    "UNIT_DIED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "UNIT_COMBAT", "UNIT_SPELLCAST_INTERRUPTED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_HEALTH",
    "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING",
    "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "PLAYER_UNGHOST",
    "CHAT_MSG_TEXT_EMOTE", "ADDON_ACTION_BLOCKED",
    "ADDON_ACTION_FORBIDDEN",
}) do
    frame:RegisterEvent(event)
end

function EmotaSpeak_TestJoke()
    NativeEmote("JOKE", "manual-settings-joke-test", true)
end

SLASH_EMOTASPEAK1 = "/emota"
SlashCmdList.EMOTASPEAK = function(message)
    if not settings then return end
    local command, arg = strsplit(" ", string.lower(message or ""))
    if command == "" or command == "settings" or command == "config" then
        if EmotaSpeak_OpenSettings then EmotaSpeak_OpenSettings() else
            Note("Settings panel not available; use /emota auto on/off.", true)
        end
    elseif command == "auto" and (arg == "on" or arg == "off") then
        settings.auto = arg == "on"
        Note("Automatic native-emote attempts: " .. (settings.auto and "ON (experimental)" or "OFF"), true)
    elseif command == "debug" and (arg == "on" or arg == "off") then
        settings.debug = arg == "on"
        Note("Local event diagnostics: " .. (settings.debug and "ON" or "OFF"), true)
    elseif command == "status" then
        Note("auto=" .. tostring(settings.auto) .. ", debug=" .. tostring(settings.debug) ..
            ", combat=" .. tostring(inCombat) .. ", lowHealthAuto=" .. tostring(settings.lowHealthAuto) ..
            ", idleAuto=" .. tostring(settings.idleAuto) ..
            ", sessionJokes=" .. sessionJokeCount, true)
    elseif command == "test" then
        NativeEmote("WAVE", "manual-test", true)
    elseif command == "health" then
        ReportHealth()
    elseif command == "idle" then
        if arg == "on" or arg == "off" then
            settings.idleAuto = arg == "on"
            Note("Idle jokes: " .. (settings.idleAuto and "ON" or "OFF") ..
                " (master /emota auto must also be enabled)", true)
        elseif arg == "test" then
            NativeEmote("JOKE", "manual-idle-joke-test", true)
        elseif arg == "reset" then
            sessionJokeCount = 0
            EndIdle()
            if type(IsPlayerMoving) == "function" then
                local moving = IsPlayerMoving()
                if not Hidden(moving) and not moving then StartIdle() end
            end
            Note("Idle personality pacing reset for this session.", true)
        else
            local timer = idleSince and math.floor(GetTime() - idleSince) or 0
            Note(("Idle for %ds; next scheduled after %ss; jokes this session: %d; enabled: %s"):format(
                timer, tostring(idleAfterSeconds or "-"), sessionJokeCount, tostring(settings.idleAuto)), true)
        end
    elseif command == "lowhealth" then
        if arg == "on" or arg == "off" then
            settings.lowHealthAuto = arg == "on"
            Note("Native low-health HEALME reaction: " ..
                (settings.lowHealthAuto and "ON (experimental)" or "OFF"), true)
        else
            Note("Native LowHealthFrame: " .. ReadLowHealthFrame(), true)
            Note("Low-health automatic reaction: " .. tostring(settings.lowHealthAuto) ..
                " (also requires /emota auto on)", true)
        end
    else
        Note("Commands: /emota [settings] | status | debug on/off | auto on/off | idle [on/off/test/reset] | test | health | lowhealth [on/off]", true)
    end
end
