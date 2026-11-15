-- All-race/all-class Emota context. Forever starts with Dwarf Hunter,
-- but the same data-driven lookup applies to any playable race and class.
-- Only harmless native emote tokens; no action-bar, targeting or combat logic.
local function Safe(x)
    return x~=nil and (type(issecretvalue)~="function" or not issecretvalue(x))
end
local raceWeights={
    Dwarf={FLEX=4, SALUTE=3, PONDER=3, DANCE=2, DRINK=3},
    Human={SALUTE=3, PONDER=2, DANCE=2},
    NightElf={DANCE=4, PONDER=2, KNEEL=2},
    Gnome={LAUGH=4, PONDER=3, DANCE=2},
    Orc={ROAR=4, FLEX=4, SALUTE=2},
    Troll={DANCE=4, LAUGH=3, CHICKEN=2},
    Tauren={KNEEL=3, PONDER=3, SALUTE=2},
    Scourge={SIGH=3, LAUGH=2, STARE=3},
    BloodElf={DANCE=3, PONDER=3, SALUTE=2},
    Draenei={SALUTE=3, KNEEL=3, PONDER=2},
    Worgen={ROAR=3, PONDER=2},
    Goblin={LAUGH=4, SHRUG=3},
    Pandaren={SIT=3, PONDER=3},
    Earthen={FLEX=3, SALUTE=2},
}
-- Races with actual weights are LIVE. Additional playable-race names below
-- are labeled previews/placeholders until an intentional behavior set is written.
local raceLabels={
    {token="Dwarf",label="Dwarf"}, {token="Human",label="Human"},
    {token="NightElf",label="Night Elf"}, {token="Gnome",label="Gnome"},
    {token="Orc",label="Orc"}, {token="Troll",label="Troll"},
    {token="Tauren",label="Tauren"}, {token="Scourge",label="Undead"},
    {token="BloodElf",label="Blood Elf"}, {token="Draenei",label="Draenei"},
    {token="Worgen",label="Worgen"}, {token="Goblin",label="Goblin"},
    {token="Pandaren",label="Pandaren"}, {token="Earthen",label="Earthen"},
    {token="VoidElf",label="Void Elf"}, {token="LightforgedDraenei",label="Lightforged Draenei"},
    {token="HighmountainTauren",label="Highmountain Tauren"},
    {token="Nightborne",label="Nightborne"}, {token="MagharOrc",label="Mag'har Orc"},
    {token="DarkIronDwarf",label="Dark Iron Dwarf"},
    {token="KulTiran",label="Kul Tiran"}, {token="ZandalariTroll",label="Zandalari Troll"},
    {token="Mechagnome",label="Mechagnome"}, {token="Vulpera",label="Vulpera"},
    {token="Dracthyr",label="Dracthyr"},
}
local raceInfo={}
for _,item in ipairs(raceLabels) do raceInfo[item.token]=item end
local modes={default=true,subtle=true,expressive=true,off=true}
local function RaceModes()
    if type(EmotaSpeakDB)~="table" then return end
    local settings=EmotaSpeakDB
    if type(settings.raceModes)~="table" then settings.raceModes={} end
    return settings.raceModes
end
function EmotaSpeak_RaceCatalog()
    local list={}
    for _,item in ipairs(raceLabels) do
        list[#list+1]={token=item.token,label=item.label,
            implemented=raceWeights[item.token]~=nil}
    end
    return list
end
function EmotaSpeak_RaceBehaviorStatus(token)
    if not raceInfo[token] then return end
    local names=raceWeights[token] or {}
    local rank={}
    for emote,weight in pairs(names) do
        rank[#rank+1]={emote=emote,weight=weight}
    end
    table.sort(rank,function(a,b)
        if a.weight==b.weight then return a.emote<b.emote end
        return a.weight>b.weight
    end)
    local top={}
    for i=1,math.min(4,#rank) do top[i]=rank[i].emote end
    local saved=RaceModes()
    return {token=token,label=raceInfo[token].label,implemented=raceWeights[token]~=nil,
        mode=saved and modes[saved[token]] and saved[token] or "default",
        examples=table.concat(top,", ")}
end
function EmotaSpeak_RaceBehaviorSet(token,mode)
    -- Future races are shown in the chooser, but deliberately do not pretend
    -- to have unique flavor until a real weight profile is implemented.
    if not raceWeights[token] or not modes[mode] then return false end
    local saved=RaceModes()
    if not saved then return false end
    saved[token]=mode
    return true
end

local classWeights={
    HUNTER={PONDER=2, SALUTE=2, CHEER=3, LOOK=2},
    WARRIOR={FLEX=4, ROAR=2, SALUTE=3},
    MAGE={PONDER=4, SHRUG=2, YAWN=2},
    PRIEST={KNEEL=3, PONDER=4, SALUTE=2},
    DRUID={SIT=3, YAWN=3, PONDER=2},
    ROGUE={LOOK=3, STARE=3, SHRUG=2},
    PALADIN={SALUTE=3, KNEEL=3, FLEX=2},
    SHAMAN={PONDER=3, KNEEL=3, ROAR=2},
    WARLOCK={LAUGH=3, STARE=3, PONDER=2},
    DEATHKNIGHT={STARE=3, ROAR=2},
    MONK={KNEEL=3, SIT=3},
    DEMONHUNTER={STARE=3, ROAR=2},
    EVOKER={PONDER=3, SALUTE=2},
}
local function Class()
    if type(UnitClass)~="function" then return end
    local _,token=UnitClass("player")
    return Safe(token) and type(token)=="string" and token or nil
end
local function Race()
    if type(UnitRace)~="function" then return end
    local _,token=UnitRace("player")
    return Safe(token) and type(token)=="string" and token or nil
end
function EmotaSpeak_PersonalityContext()
    local race,class=Race(),Class()
    local result={race=race or "Unknown",class=class or "Unknown",
        weights={},resting=false,petName=nil}
    local preferences=RaceModes()
    local mode=preferences and preferences[race] or "default"
    local multiplier=mode=="off" and 0 or
        (mode=="subtle" and 0.5 or (mode=="expressive" and 2 or 1))
    for token,w in pairs(raceWeights[race] or {}) do
        result.weights[token]=(result.weights[token] or 0)+math.floor(w*multiplier+0.5)
    end
    for token,w in pairs(classWeights[class] or {}) do result.weights[token]=(result.weights[token] or 0)+w end
    if type(IsResting)=="function" then
        local state=IsResting()
        if Safe(state) and state==true then
            result.resting=true
            result.weights.SIT=(result.weights.SIT or 0)+4
            result.weights.SLEEP=(result.weights.SLEEP or 0)+2
            result.weights.DANCE=(result.weights.DANCE or 0)+1
        end
    end
    if class=="HUNTER" and type(UnitExists)=="function" then
        local pet=UnitExists("pet")
        if Safe(pet) and pet then
            local name=type(UnitName)=="function" and UnitName("pet")
            if Safe(name) and type(name)=="string" and name~="" then
                result.petName=name
                result.weights.CHEER=(result.weights.CHEER or 0)+3
            end
        end
    end
    return result
end
