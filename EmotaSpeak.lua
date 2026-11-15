-- EmotaSpeak 0.4.0: standalone character personality for WoW Forever.
-- Native emotes are opt-in and never dispatched in combat.

local addonName = ...
local frame = CreateFrame("Frame")
local settings
local inCombat = false
local combatStarted = 0
local guidToCompanion = {}
local lastAttempt = -1e8
local lastMeaningfulAttempt = -1e8
local lastWaveReply = -1e8
local lastByReason = {}
local lowHPNoted=false
local lastLowHealthFrameState=nil
local lowHealthScanQueued=false
-- Per-login session pacing; intentionally not written to SavedVariables.
local idleSince = nil
local idleAfterSeconds = nil
local sessionJokeCount = 0
local sessionIdleActions = 0
local lastIdleToken, previousIdleToken = nil, nil
local activePose, poseUntil = nil, nil
local idleTicker = nil

-- Blizzard's EMOTE##_TOKEN constants expose this client's native emote list.
-- Triggered emotes stay enabled by default; other entries are opt-in for idle
-- variety, but each can be previewed manually from the native settings page.
local automatic={WAVE=true,JOKE=true,TRAIN=true,CHEER=true,CRY=true,
    MOURN=true,OOM=true,SIGH=true,BOW=true,LAUGH=true,FLEX=true}
-- Intentional, curated *default* idle reactions. They are checked by default in
-- the emote catalog, and each can be disabled independently. Pose actions alter
-- character state: only use them while the player is stationary and safe.
local idlePresets = {
    {token="JOKE", weight=21},
    {token="DANCE", weight=9},
    {token="SIT", weight=4, pose=true},
    {token="SLEEP", weight=3, pose=true},
    {token="LAYDOWN", weight=3, pose=true},
    {token="YAWN", weight=8},
    {token="PONDER", weight=10},
    {token="SHRUG", weight=8},
    {token="FLEX", weight=5},
    {token="ROFL", weight=5},
    {token="SALUTE", weight=4},
    {token="SIGH", weight=6},
    {token="STARE", weight=4},
    {token="CHICKEN", weight=3},
    {token="APPLAUD", weight=3},
    {token="LOOK", weight=4},
}
local idleFeatured, poseTokens = {}, {}
for _,entry in ipairs(idlePresets) do
    idleFeatured[entry.token]=true
    if entry.pose then poseTokens[entry.token]=true end
end
local defaults={"WAVE","JOKE","TRAIN","CHEER","CRY","MOURN","OOM","SIGH",
    "BOW","LAUGH","FLEX","DANCE","SALUTE","KNEEL","THANK","HELLO",
    "GOODBYE","NO","YES","APPLAUD","ROAR","SHY","SLEEP","SIT",
    "LAYDOWN","STAND","YAWN","PONDER","SHRUG","ROFL","STARE","LOOK",
    "POINT","BEG","CHICKEN","TALK","WELCOME","CONGRATULATE"}
local catalog
local function Catalog()
    if catalog then return catalog end
    local found={}
    for _,token in ipairs(defaults) do found[token]=true end
    for name,token in pairs(_G) do
        if type(name)=="string" and name:match("^EMOTE%d+_TOKEN$")
            and type(token)=="string" and token:match("^[A-Z][A-Z0-9_]*$") then
            found[token]=true
        end
    end
    catalog={}
    for token in pairs(found) do
        catalog[#catalog+1]={
            token=token,automatic=automatic[token]==true,idle=idleFeatured[token]==true,manualPose=poseTokens[token]==true
        }
    end
    table.sort(catalog,function(a,b)
        if a.automatic~=b.automatic then return a.automatic end
        if a.idle~=b.idle then return a.idle end
        return a.token<b.token
    end)
    return catalog
end
function EmotaSpeak_EmotaCatalog()
    return Catalog()
end
function EmotaSpeak_EmotaGetEnabled(token)
    if not automatic[token] then
        local found=false
        for _,entry in ipairs(Catalog()) do if entry.token==token then found=true;break end end
        if not found then return false end
    end
    local overrides=settings and settings.allowedEmotes
    if overrides and overrides[token]~=nil then return overrides[token]==true end
    return automatic[token]==true or idleFeatured[token]==true
end
function EmotaSpeak_EmotaSetEnabled(token,value)
    for _,entry in ipairs(Catalog()) do
        if entry.token==token and settings then
            settings.allowedEmotes=settings.allowedEmotes or {}
            settings.allowedEmotes[token]=value==true
            return
        end
    end
end
local function JokeScale()
    local value=settings and settings.jokeFrequency or 50
    if value<50 then return 1+(50-value)*9/50 end
    return 1-(value-50)*0.82/50
end
local function Hidden(value)
    return value ~= nil and type(issecretvalue) == "function" and issecretvalue(value)
end

local function Note(message, always)
    if always or (settings and settings.debug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff77ccffChalkBox Emota|r " .. message)
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
    -- Some Forever clients treat PerformEmote as a protected chat action.
    -- No manual, reactive, or automatic dispatch while combat is active.
    if inCombat or (type(InCombatLockdown)=="function" and
        InCombatLockdown()) then return false end
    if type(UnitAffectingCombat)=="function" then
        local fighting=UnitAffectingCombat("player")
        if Hidden(fighting) or fighting then return false end
    end
    if not C_ChatInfo or not C_ChatInfo.PerformEmote then
        Note("C_ChatInfo.PerformEmote does not exist in this client.", true)
        return false
    end
    if not manual and not (settings and settings.auto) then
        return false
    end
    if not manual and token~="STAND" and not EmotaSpeak_EmotaGetEnabled(token) then
        return false
    end
    -- Automatic sitting/sleeping/standing can interrupt drinking and player
    -- actions even outside combat. Keep pose emotes as manual previews only.
    if not manual and (poseTokens[token] or token=="STAND") then
        return false
    end

    local now = GetTime()
    if not manual then
        -- A single global cooldown and a longer per-trigger lock prevent spam.
        local idleReason=(reason=="idle-joke" or reason=="idle-personality" or
            reason=="idle-variety" or reason=="idle-pose-finish")
        local cooldown=idleReason and 15 or 45
        if now - lastAttempt < cooldown or now - (lastByReason[reason] or -1e8) < cooldown then
            return false
        end
        lastAttempt = now
        if not idleReason then lastMeaningfulAttempt = now end
        lastByReason[reason] = now
    end

    if C_ChatInfo.InChatMessagingLockdown then
        local lockdown = C_ChatInfo.InChatMessagingLockdown()
        if Hidden(lockdown) or lockdown then
            Note("Skipped " .. token .. ": chat messaging is restricted.", true)
            return false
        end
    end
    local _, instanceType = GetInstanceInfo()
    if instanceType == "pvp" or instanceType == "arena" then
        Note("Skipped emote attempt in a PvP instance.")
        return false
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
        return true
    else
        Note(("%s -> %s: API raised an error or restriction"):format(reason, token), true)
    end
    return false
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

-- Idle personality is a weighted, low-frequency rotation, not a
-- time-based chat spammer. It can choose to do nothing, and avoids both of the
-- previous two actions when there are enough enabled choices.
local function NextIdleDelay()
    local baseline
    if sessionIdleActions==0 then baseline=60
    elseif sessionIdleActions==1 then baseline=math.random(90,180)
    elseif sessionIdleActions==2 then baseline=math.random(120,300)
    elseif sessionIdleActions==3 then baseline=math.random(180,420)
    else baseline=math.random(240,600) end
    return math.max(20,math.floor(baseline*JokeScale()+0.5))
end

local function StartIdle()
    idleSince=GetTime()
    idleAfterSeconds=NextIdleDelay()
    Note(("Idle window begins; possible event in %ds (session idle events: %d)"):format(
        idleAfterSeconds,sessionIdleActions))
end

local function EndIdle()
    idleSince=nil
    idleAfterSeconds=nil
    -- Walking or combat naturally breaks sitting/sleeping poses. Never send a
    -- potentially restricted STAND command while moving or in combat.
    activePose=nil
    poseUntil=nil
end

local function IdleIsSafe()
    if type(InCombatLockdown)=="function" and InCombatLockdown() then return false end
    if type(UnitAffectingCombat)=="function" then
        local fighting=UnitAffectingCombat("player")
        if Hidden(fighting) or fighting then return false end
    end
    if type(IsPlayerMoving)=="function" then
        local moving=IsPlayerMoving()
        if Hidden(moving) or moving then return false end
    end
    if type(UnitIsDeadOrGhost)=="function" then
        local dead=UnitIsDeadOrGhost("player")
        if Hidden(dead) or dead then return false end
    end
    if type(UnitIsFeignDeath)=="function" then
        local feign=UnitIsFeignDeath("player")
        if Hidden(feign) or feign then return false end
    end
    if type(UnitIsAFK)=="function" then
        local afk=UnitIsAFK("player")
        if Hidden(afk) or afk then return false end
    end
    if type(IsMounted)=="function" then
        local mounted=IsMounted()
        if Hidden(mounted) or mounted then return false end
    end
    if type(UnitOnTaxi)=="function" then
        local taxi=UnitOnTaxi("player")
        if Hidden(taxi) or taxi then return false end
    end
    for _,fn in ipairs({"UnitCastingInfo","UnitChannelInfo"}) do
        local api=_G[fn]
        if type(api)=="function" then
            local cast=api("player")
            if Hidden(cast) or cast then return false end
        end
    end
    for _,name in ipairs({"MerchantFrame","TradeFrame","BankFrame","MailFrame",
        "AuctionHouseFrame","AuctionFrame"}) do
        local ui=_G[name]
        if ui and ui.IsShown then
            local shown=ui:IsShown()
            if Hidden(shown) or shown then return false end
        end
    end
    return true
end

local function IdlePool()
    local pool={}
    local context=nil
    if settings and settings.contextual~=false and
        type(EmotaSpeak_PersonalityContext)=="function" then
        context=EmotaSpeak_PersonalityContext()
    end
    for _,entry in ipairs(idlePresets) do
        if not entry.pose and EmotaSpeak_EmotaGetEnabled(entry.token) then
            local extra=context and context.weights[entry.token] or 0
            pool[#pool+1]={token=entry.token,weight=entry.weight+extra,pose=entry.pose}
        end
    end
    if context and context.weights then
        for token,weight in pairs(context.weights) do
            if not poseTokens[token] and token~="STAND"
                and EmotaSpeak_EmotaGetEnabled(token) then
                local found=false
                for _,entry in ipairs(pool) do if entry.token==token then found=true;break end end
                if not found then pool[#pool+1]={token=token,weight=weight} end
            end
        end
        if context.petName and EmotaSpeak_EmotaGetEnabled("CHEER") then
            pool[#pool+1]={token="CHEER",weight=5,petName=context.petName}
        end
    end
    if settings and settings.idleVariety then
        -- Explicitly enabled additional emotes can join the pool. The curated
        -- set above remains the primary source of animated behaviors.
        for _,entry in ipairs(Catalog()) do
            if not automatic[entry.token] and not idleFeatured[entry.token]
                and entry.token~="STAND" and not poseTokens[entry.token]
                and EmotaSpeak_EmotaGetEnabled(entry.token) then
                pool[#pool+1]={token=entry.token,weight=2}
            end
        end
    end
    if #pool>2 then
        local filtered={}
        for _,entry in ipairs(pool) do
            if entry.token~=lastIdleToken and entry.token~=previousIdleToken then
                filtered[#filtered+1]=entry
            end
        end
        if #filtered>0 then return filtered end
    end
    return pool
end

local function PickIdle()
    local pool=IdlePool()
    local total=0
    for _,entry in ipairs(pool) do total=total+entry.weight end
    if total<=0 then return nil end
    local pick=math.random(1,total)
    for _,entry in ipairs(pool) do
        pick=pick-entry.weight
        if pick<=0 then return entry end
    end
end

local function CheckIdle()
    if not settings or not settings.auto or not settings.idleAuto then return end
    if not IdleIsSafe() then return end
    local now=GetTime()
    if activePose then
        if poseUntil and now>=poseUntil then
            if NativeEmote("STAND","idle-pose-finish",false) then
                activePose,poseUntil=nil,nil
                StartIdle()
            end
        end
        return
    end
    if not idleSince or not idleAfterSeconds then return end
    if now-idleSince<idleAfterSeconds then return end
    if now-lastMeaningfulAttempt<120 then return end
    -- Quiet roll: even when the timer expires, nothing may happen. At the
    -- center slider 25% of opportunities are skipped; very frequent settings
    -- skip a little less, very rare settings skip a little more.
    local frequency=settings.jokeFrequency or 50
    local chance=75+(frequency-50)*0.30
    if math.random(1,100)>chance then
        StartIdle()
        return
    end
    local selected=PickIdle()
    if not selected then
        StartIdle()
        return
    end
    local token=selected.token
    local reason=token=="JOKE" and "idle-joke" or "idle-personality"
    if NativeEmote(token,reason,false,selected.petName) then
        previousIdleToken,lastIdleToken=lastIdleToken,token
        sessionIdleActions=sessionIdleActions+1
        if token=="JOKE" then sessionJokeCount=sessionJokeCount+1 end
        Note(("Idle personality: %s (event %d)"):format(token,sessionIdleActions))
        if selected.pose then
            -- We only stand the character up again if Emota initiated this pose,
            -- it remained safe, and the player has not moved or entered combat.
            activePose=token
            poseUntil=now+math.random(20,38)
            return
        end
    end
    StartIdle()
end

function EmotaSpeak_EmotaPreviewIdle()
    if not settings then return end
    local picked=PickIdle()
    if not picked then
        Note("Enable at least one idle emote in the Emote Catalog first.",true)
        return
    end
    return NativeEmote(picked.token,"idle-preview",true,picked.petName)
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
        local saved = EmotaSpeakDB
        saved.auto = saved.auto == true
        saved.debug = saved.debug == true
        saved.lowHealthAuto = saved.lowHealthAuto == true
        saved.idleAuto = saved.idleAuto ~= false
        saved.idleVariety = saved.idleVariety == true
        if saved.contextual==nil then saved.contextual=true end
        saved.jokeFrequency = type(saved.jokeFrequency)=="number"
            and math.max(0,math.min(100,math.floor(saved.jokeFrequency+0.5))) or 50
        if type(saved.allowedEmotes)~="table" then saved.allowedEmotes={} end
        settings = saved
        if not idleTicker and C_Timer and C_Timer.NewTicker then
            idleTicker = C_Timer.NewTicker(5, CheckIdle)
        end

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
        local unit=...
        OnHealth(unit)
        if unit=="player" then QueueLowHealthFrameSample() end
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

function EmotaSpeak_EmotaTest(token)
    if type(token)=="string" then
        for _,entry in ipairs(Catalog()) do
            if entry.token==token then return NativeEmote(token,"catalog-preview",true) end
        end
    end
    return false
end
function EmotaSpeak_EmotaSetJokeFrequency(value)
    if not settings or type(value)~="number" then return end
    settings.jokeFrequency=math.max(0,math.min(100,math.floor(value+0.5)))
    EmotaSpeak_EmotaOnSettingChanged("idleAuto")
end

function EmotaSpeak_EmotaTestJoke()
    NativeEmote("JOKE", "manual-settings-joke-test", true)
end

-- Called by both the native settings checkboxes and slash commands.
-- Re-arming from a toggle prevents an immediate joke when the user
-- has been standing still for a long time with reactions disabled.
function EmotaSpeak_EmotaOnSettingChanged(key)
    if key ~= "auto" and key ~= "idleAuto" and key ~= "jokeFrequency" then return end
    EndIdle()
    if settings and settings.auto and settings.idleAuto and type(IsPlayerMoving) == "function" then
        local moving = IsPlayerMoving()
        if not Hidden(moving) and not moving then StartIdle() end
    end
end


function EmotaSpeak_EmotaCommand(message)
    if not settings then return end
    local command,arg=strsplit(" ",string.lower(message or ""))
    if command=="" or command=="settings" or command=="config" then
        if EmotaSpeak_OpenSettings then EmotaSpeak_OpenSettings() else
            Note("Open Options > AddOns > EmotaSpeak.",true) end
    elseif command=="help" then
        Note("Commands: /emota auto on/off | idle on/off/test/preview/reset | variety on/off | context on/off | debug on/off | test | health | lowhealth on/off | status",true)
    elseif command=="auto" and (arg=="on" or arg=="off") then
        settings.auto=arg=="on"; EmotaSpeak_EmotaOnSettingChanged("auto")
        Note("Automatic reactions: "..(settings.auto and "ON" or "OFF"),true)
    elseif command=="debug" and (arg=="on" or arg=="off") then
        settings.debug=arg=="on"; Note("Diagnostics: "..arg,true)
    elseif command=="variety" and (arg=="on" or arg=="off") then
        settings.idleVariety=arg=="on"; Note("Extra idle variety: "..arg,true)
    elseif command=="context" and (arg=="on" or arg=="off") then
        settings.contextual=arg=="on"; Note("Contextual flavor: "..arg,true)
    elseif command=="idle" then
        if arg=="on" or arg=="off" then
            settings.idleAuto=arg=="on"; EmotaSpeak_EmotaOnSettingChanged("idleAuto")
            Note("Idle personality: "..arg.." (also requires /emota auto on)",true)
        elseif arg=="test" then
            EmotaSpeak_EmotaTestJoke()
        elseif arg=="preview" then
            EmotaSpeak_EmotaPreviewIdle()
        elseif arg=="reset" then
            sessionJokeCount,sessionIdleActions=0,0
            previousIdleToken,lastIdleToken=nil,nil
            EndIdle()
            if type(IsPlayerMoving)=="function" then
                local moving=IsPlayerMoving()
                if not Hidden(moving) and not moving then StartIdle() end
            end
            Note("Idle pacing reset.",true)
        else
            local elapsed=idleSince and math.floor(GetTime()-idleSince) or 0
            Note(("Idle %ds; next opportunity after %ss; actions %d; jokes %d"):format(
                elapsed,tostring(idleAfterSeconds or "-"),sessionIdleActions,sessionJokeCount),true)
        end
    elseif command=="health" then ReportHealth()
    elseif command=="lowhealth" then
        if arg=="on" or arg=="off" then
            settings.lowHealthAuto=arg=="on"
            Note("Experimental low-health border response: "..arg,true)
        else
            Note("LowHealthFrame: "..ReadLowHealthFrame()..", enabled="..
                tostring(settings.lowHealthAuto),true)
        end
    elseif command=="status" then
        Note("auto="..tostring(settings.auto)..", idle="..tostring(settings.idleAuto)..
            ", frequency="..tostring(settings.jokeFrequency)..", variety="..
            tostring(settings.idleVariety)..", context="..tostring(settings.contextual)..
            ", debug="..tostring(settings.debug)..", lowHealthAuto="..
            tostring(settings.lowHealthAuto)..", combat="..tostring(inCombat)..
            ", idleEvents="..sessionIdleActions..", jokes="..sessionJokeCount,true)
    elseif command=="test" then EmotaSpeak_EmotaTest("WAVE")
    else Note("Unknown command. Type /emota help.",true) end
end

-- Backwards-compatible entry points.
function EmotaSpeak_TestJoke() EmotaSpeak_EmotaTestJoke() end
function EmotaSpeak_OnSettingChanged(key) EmotaSpeak_EmotaOnSettingChanged(key) end
SLASH_EMOTASPEAK1="/emota"
SlashCmdList.EMOTASPEAK=function(message) EmotaSpeak_EmotaCommand(message) end
