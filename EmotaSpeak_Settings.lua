-- Standalone EmotaSpeak options, adapted from ChalkBox Emota navigation.
local panels,categories={},{}
local rootCategory
local registered=false
local function DB() return _G.EmotaSpeakDB end
local function Note(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff77ccffEmotaSpeak|r "..message) end
end
local function Label(panel,value,style,x,y,width)
    local text=panel:CreateFontString(nil,"ARTWORK",style or "GameFontHighlight")
    text:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
    text:SetWidth(width or 495)
    text:SetJustifyH("LEFT")
    text:SetText(value)
    return text
end
local function Button(panel,caption,x,y,width,callback)
    local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    button:SetSize(width,26)
    button:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
    button:SetText(caption)
    button:SetScript("OnClick",callback)
    return button
end
local function Activate(page)
    local category=categories[page or "home"] or rootCategory
    if category and Settings and type(Settings.OpenToCategory)=="function" then
        local identifier=category.GetID and category:GetID() or category.ID
        Settings.OpenToCategory(identifier or category)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panels[page or "home"] or panels.home)
    else
        Note("Open Options > AddOns > EmotaSpeak.")
    end
end
function EmotaSpeak_OpenSettings(page) Activate(page or "home") end
function EmotaSpeak_OnAddonCompartmentClick() EmotaSpeak_OpenSettings() end
local function Panel(titleText,subtitle)
    local panel=CreateFrame("Frame",nil,UIParent)
    panel:SetSize(560,450)
    panel.name=titleText
    panel:Hide()
    Label(panel,titleText,"GameFontNormalHuge",24,-22,395)
    Label(panel,subtitle,"GameFontHighlightSmall",24,-59,510)
    local divider=panel:CreateTexture(nil,"ARTWORK")
    divider:SetPoint("TOPLEFT",panel,"TOPLEFT",24,-86)
    divider:SetSize(495,1)
    divider:SetColorTexture(0.74,0.56,0.31,0.65)
    local callbacks={}
    function panel:AddRefresh(callback) callbacks[#callbacks+1]=callback end
    local function Refresh()
        for _,callback in ipairs(callbacks) do callback() end
    end
    panel.OnRefresh=Refresh
    panel.OnCommit=function() end
    panel.OnDefault=function() end
    panel:SetScript("OnShow",Refresh)
    if titleText~="EmotaSpeak" then
        local back=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        back:SetSize(105,22)
        back:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-31,-21)
        back:SetText("EmotaSpeak")
        back:SetScript("OnClick",function() Activate("home") end)
    end
    return panel
end
local function Toggle(panel,caption,description,y,value,change,x)
    x=x or 24
    local check=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    check:SetSize(25,25)
    check:SetPoint("TOPLEFT",panel,"TOPLEFT",x,y)
    Label(panel,caption,"GameFontNormal",x+34,y-4,440)
    if description then Label(panel,description,"GameFontHighlightSmall",x+34,y-28,445) end
    check:SetScript("OnClick",function(self)
        change(not not self:GetChecked())
        if panel.OnRefresh then panel.OnRefresh() end
    end)
    panel:AddRefresh(function() check:SetChecked(value()==true) end)
    return check
end

local function MakeEmota()
    local panel=Panel("EmotaSpeak","Optional character reactions and randomized idle personality. All automatic emotes are opt-in.")
    local function Change(key,on)
        if not EmotaSpeak_EmotaCommand then return end
        if key=="idleAuto" then EmotaSpeak_EmotaCommand("idle " .. (on and "on" or "off"))
        elseif key=="idleVariety" then EmotaSpeak_EmotaCommand("variety " .. (on and "on" or "off"))
        elseif key=="contextual" then EmotaSpeak_EmotaCommand("context " .. (on and "on" or "off"))
        else EmotaSpeak_EmotaCommand((key=="auto" and "auto " or "debug ") ..
            (on and "on" or "off")) end
    end
    local opts={
        {"auto","Enable automatic character reactions",-105},
        {"idleAuto","Random idle personality: jokes, dance and other safe emotes",-151},
        {"debug","Show optional local diagnostics",-197},
        {"idleVariety","Also include extra emotes you enable in the catalog",-243},
        {"contextual","Adapt idle behavior to race, class, resting area and pet",-289},
    }
    for _,o in ipairs(opts) do
        local key=o[1]
        Toggle(panel,o[2],nil,o[3],
            function() local db=DB();return db and
                (key=="contextual" and db.contextual~=false or
                db[key]==true) end,
            function(on) Change(key,on) end)
    end
    Label(panel,"Idle frequency: rare  <   normal   >  frequent",
        "GameFontNormal",29,-324,480)
    local slider=CreateFrame("Slider",nil,panel,"OptionsSliderTemplate")
    slider:SetSize(440,18)
    slider:SetPoint("TOPLEFT",panel,"TOPLEFT",39,-350)
    slider:SetMinMaxValues(0,100)
    if slider.SetValueStep then slider:SetValueStep(1) end
    local setting=false
    slider:SetScript("OnValueChanged",function(_,value)
        if not setting and EmotaSpeak_EmotaSetJokeFrequency and type(value)=="number" then
            EmotaSpeak_EmotaSetJokeFrequency(value)
        end
    end)
    panel:AddRefresh(function()
        local db=DB()
        local value=db and db and db.jokeFrequency or 50
        setting=true
        slider:SetValue(value)
        setting=false
    end)
    Button(panel,"Wave",27,-393,67,function()
        if EmotaSpeak_EmotaCommand then EmotaSpeak_EmotaCommand("test") end end)
    Button(panel,"Test Joke",100,-393,86,function()
        if EmotaSpeak_EmotaTestJoke then EmotaSpeak_EmotaTestJoke() end end)
    Button(panel,"Surprise Me",191,-393,108,function()
        if EmotaSpeak_EmotaPreviewIdle then EmotaSpeak_EmotaPreviewIdle() end end)
    Button(panel,"Reset Idle",304,-393,84,function()
        if EmotaSpeak_EmotaCommand then EmotaSpeak_EmotaCommand("idle reset") end end)
    Button(panel,"Catalog",393,-393,66,function() Activate("catalog") end)
    Button(panel,"Races",463,-393,66,function() Activate("races") end)
    return panel
end

local function MakeRacePreferences()
    local panel=Panel("EmotaSpeak Race Behavior",
        "Inspect real racial emote flavor and customize your character's own race.")
    local list=EmotaSpeak_RaceCatalog and EmotaSpeak_RaceCatalog() or {}
    local selectedIndex=1
    local detected
    if type(UnitRace)=="function" then
        local _,token=UnitRace("player")
        if type(token)=="string" then
            detected=token
            for i,row in ipairs(list) do
                if row.token==token then selectedIndex=i;break end
            end
        end
    end
    Label(panel,"RACE TO INSPECT","GameFontNormalLarge",28,-105,420)
    local selectedText=Label(panel,"","GameFontHighlight",29,-149,480)
    local statusText=Label(panel,"","GameFontHighlightSmall",28,-228,492)
    local examples=Label(panel,"","GameFontHighlightSmall",28,-254,492)
    local modeText=Label(panel,"","GameFontHighlight",28,-286,492)
    local function Choose(index)
        if #list==0 then return end
        selectedIndex=(index-1)%#list+1
        if panel.OnRefresh then panel.OnRefresh() end
    end
    local dropdown
    if type(UIDropDownMenu_Initialize)=="function" and
        type(UIDropDownMenu_CreateInfo)=="function" and
        type(UIDropDownMenu_AddButton)=="function" then
        dropdown=CreateFrame("Frame",nil,panel,"UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT",panel,"TOPLEFT",178,-132)
        if type(UIDropDownMenu_SetWidth)=="function" then
            UIDropDownMenu_SetWidth(dropdown,262)
        end
        UIDropDownMenu_Initialize(dropdown,function(_,level)
            for i,item in ipairs(list) do
                local info=UIDropDownMenu_CreateInfo()
                info.text=item.label..(item.implemented and "" or " (planned)")
                info.checked=i==selectedIndex
                local selection=i
                info.func=function() Choose(selection) end
                UIDropDownMenu_AddButton(info,level)
            end
        end)
    end
    Button(panel,"Previous race",28,-183,154,function()
        Choose(selectedIndex-1)
    end)
    Button(panel,"Next race",192,-183,154,function()
        Choose(selectedIndex+1)
    end)
    Button(panel,"My race",356,-183,142,function()
        for i,row in ipairs(list) do
            if row.token==detected then Choose(i);return end
        end
    end)
    Label(panel,"RACIAL FLAVOR INTENSITY","GameFontNormalLarge",28,-318,460)
    for i,item in ipairs({
        {"off","Off"},{"subtle","Subtle"},{"default","Default"},{"expressive","Expressive"},
    }) do
        local behaviorMode=item[1]
        Button(panel,item[2],27+(i-1)*128,-345,114,function()
            local target=list[selectedIndex]
            if target and EmotaSpeak_RaceBehaviorSet then
                EmotaSpeak_RaceBehaviorSet(target.token,behaviorMode)
            end
            if panel.OnRefresh then panel.OnRefresh() end
        end)
    end
    Label(panel,"Only your character's actual race affects live behavior.",
        "GameFontHighlightSmall",28,-396,492)
    Label(panel,"Planned races are visible in the picker, but have no invented behavior.",
        "GameFontHighlightSmall",28,-418,500)
    panel:AddRefresh(function()
        local item=list[selectedIndex]
        if not item then
            selectedText:SetText("Race list unavailable.")
            return
        end
        local status=EmotaSpeak_RaceBehaviorStatus and
            EmotaSpeak_RaceBehaviorStatus(item.token)
        selectedText:SetText(item.label..(item.implemented and
            "  •  Live behavior" or "  •  Planned / placeholder"))
        statusText:SetText(detected==item.token and
            "This is your current race." or
            "Preview only. Selecting this does not change your character's race.")
        examples:SetText(item.implemented and
            ("Signature emotes: "..(status and status.examples or "None")) or
            "No special emote weighting is implemented for this race yet.")
        modeText:SetText(item.implemented and
            ("Current racial flavor: "..(status and status.mode or "default")) or
            "Racial intensity: unavailable until that race is implemented.")
        if dropdown and type(UIDropDownMenu_SetText)=="function" then
            UIDropDownMenu_SetText(dropdown,item.label..
                (item.implemented and "" or " (planned)"))
        end
    end)
    return panel
end

local function MakeCatalog()
    local panel=Panel("Emote Catalog",
        "Enable supported emotes individually and test them without waiting for idle.")
    Label(panel,"Auto reactions are cosmetic. Poses are manual-only for safety.",
        "GameFontHighlightSmall",26,-104,494)
    local page=1
    local rows={}
    local perPage=6
    for i=1,perPage do
        local y=-137-(i-1)*43
        local check=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
        check:SetPoint("TOPLEFT",panel,"TOPLEFT",27,y)
        check:SetSize(23,23)
        local title=Label(panel,"","GameFontHighlightSmall",66,y-4,306)
        local test=Button(panel,"Try",400,y+2,86,function()
            if rows[i] and rows[i].token and EmotaSpeak_EmotaTest then
                EmotaSpeak_EmotaTest(rows[i].token)
            end
        end)
        rows[i]={check=check,title=title,test=test,token=nil}
        check:SetScript("OnClick",function(self)
            local token=rows[i].token
            if token and EmotaSpeak_EmotaSetEnabled then
                EmotaSpeak_EmotaSetEnabled(token,not not self:GetChecked())
            end
            if panel.OnRefresh then panel.OnRefresh() end
        end)
    end
    local pagination=Label(panel,"","GameFontHighlightSmall",27,-419,255)
    Button(panel,"Previous",301,-403,91,function()
        page=math.max(1,page-1)
        if panel.OnRefresh then panel.OnRefresh() end
    end)
    Button(panel,"Next",403,-403,91,function()
        page=page+1
        if panel.OnRefresh then panel.OnRefresh() end
    end)
    panel:AddRefresh(function()
        local available=EmotaSpeak_EmotaCatalog and EmotaSpeak_EmotaCatalog() or {}
        local total=math.max(1,math.ceil(#available/perPage))
        page=math.min(page,total)
        pagination:SetText(("Emotes: %d  |  page %d / %d"):format(#available,page,total))
        for i,row in ipairs(rows) do
            local entry=available[(page-1)*perPage+i]
            row.token=entry and entry.token or nil
            if entry then
                local role=entry.manualPose and "manual pose" or
                    (entry.automatic and "reaction" or (entry.idle and "idle" or "extra"))
                row.title:SetText(entry.token .. "   (" .. role .. ")")
                row.check:SetChecked(EmotaSpeak_EmotaGetEnabled and
                    EmotaSpeak_EmotaGetEnabled(entry.token)==true)
                if entry.manualPose then row.check:Hide()
                else row.check:Show() end
                row.test:Show()
            else
                row.title:SetText("")
                row.check:Hide()
                row.test:Hide()
            end
        end
    end)
    return panel
end


local function Register()
    if registered then return end
    panels.home=MakeEmota()
    panels.races=MakeRacePreferences()
    panels.catalog=MakeCatalog()
    if Settings and type(Settings.RegisterCanvasLayoutCategory)=="function"
        and type(Settings.RegisterAddOnCategory)=="function" then
        rootCategory=Settings.RegisterCanvasLayoutCategory(panels.home,"EmotaSpeak")
        Settings.RegisterAddOnCategory(rootCategory)
        categories.home=rootCategory
        if type(Settings.RegisterCanvasLayoutSubcategory)=="function" then
            categories.races=Settings.RegisterCanvasLayoutSubcategory(
                rootCategory,panels.races,"Race Behavior")
            categories.catalog=Settings.RegisterCanvasLayoutSubcategory(
                rootCategory,panels.catalog,"Emote Catalog")
        else
            for _,entry in ipairs({{"races","Race Behavior"},{"catalog","Emote Catalog"}}) do
                local child=Settings.RegisterCanvasLayoutCategory(
                    panels[entry[1]],"EmotaSpeak - "..entry[2])
                Settings.RegisterAddOnCategory(child)
                categories[entry[1]]=child
            end
        end
        registered=true
    elseif type(InterfaceOptions_AddCategory)=="function" then
        InterfaceOptions_AddCategory(panels.home)
        for _,entry in ipairs({{"races","Race Behavior"},{"catalog","Emote Catalog"}}) do
            local child=panels[entry[1]]
            child.parent="EmotaSpeak"
            InterfaceOptions_AddCategory(child)
        end
        registered=true
    else
        Note("No supported AddOns settings UI API was found.")
    end
end
local loader=CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent",function(self)
    Register()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
