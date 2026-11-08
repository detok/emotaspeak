-- EmotaSpeak settings for WoW Forever.
-- Native Settings category plus Blizzard's built-in addon compartment.
local panel = CreateFrame("Frame", "EmotaSpeakSettingsPanel", UIParent)
panel:SetSize(570, 450)

local category
local controls = {}

local function Database()
    return _G.EmotaSpeakDB
end

local function Refresh()
    local db = Database()
    if not db then return end
    for key, check in pairs(controls) do
        check:SetChecked(db[key] == true)
    end
end

local function Label(text, template, x, y, width)
    local label = panel:CreateFontString(nil, "ARTWORK", template)
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetWidth(width or 490)
    label:SetText(text)
    return label
end

local bannerIcon = panel:CreateTexture(nil, "ARTWORK")
bannerIcon:SetPoint("TOPLEFT", 25, -20)
bannerIcon:SetSize(48, 48)
bannerIcon:SetTexture("Interface\\AddOns\\EmotaSpeak\\assets\\Icon")

Label("EmotaSpeak", "GameFontNormalHuge", 85, -22, 450)
Label("A little personality for every adventure.", "GameFontHighlight", 85, -52, 460)
local divider = panel:CreateTexture(nil, "ARTWORK")
divider:SetPoint("TOPLEFT", 25, -89)
divider:SetSize(510, 1)
divider:SetColorTexture(0.55, 0.42, 0.22, 0.65)

local function Check(key, title, description, y)
    local button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, y)
    button:SetSize(26, 26)
    controls[key] = button

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", button, "RIGHT", 8, 0)
    label:SetText(title)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 60, y - 28)
    hint:SetJustifyH("LEFT")
    hint:SetWidth(450)
    hint:SetText(description)

    button:SetScript("OnClick", function(self)
        local db = Database()
        if not db then return end
        db[key] = not not self:GetChecked()
        Refresh()
    end)
end

Check("auto", "Enable character reactions",
    "Master switch for automatic emotes. You can still use /emota auto on or off.", -111)
Check("idleAuto", "Occasional voiced jokes while idle",
    "First after about 1 minute. Later jokes become less frequent over your play session.", -185)
Check("debug", "Show diagnostic messages",
    "Optional local debug information; normal reactions stay quiet.", -259)

local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
test:SetSize(160, 25)
test:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -337)
test:SetText("Test a voiced joke")
test:SetScript("OnClick", function()
    if EmotaSpeak_TestJoke then
        EmotaSpeak_TestJoke()
    end
end)

local footer = Label("Settings are saved per character. No outgoing chat text, spell casting, or movement automation.",
    "GameFontDisableSmall", 25, -387, 505)
footer:SetJustifyH("LEFT")

panel.OnRefresh = Refresh
panel.OnCommit = function() end
panel.OnDefault = function()
    local db = Database()
    if not db then return end
    db.auto = false
    db.idleAuto = true
    db.debug = false
    db.lowHealthAuto = false
    Refresh()
end
panel:SetScript("OnShow", Refresh)

local function InitializeSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "EmotaSpeak")
        Settings.RegisterAddOnCategory(category)
    end
end

function EmotaSpeak_OpenSettings()
    if category and Settings and Settings.OpenToCategory then
        Refresh()
        Settings.OpenToCategory(category:GetID())
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff77ccffEmotaSpeak|r Settings panel is unavailable; use /emota auto on/off.")
    end
end

function EmotaSpeak_OnAddonCompartmentClick()
    EmotaSpeak_OpenSettings()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    InitializeSettings()
    loader:UnregisterAllEvents()
end)
