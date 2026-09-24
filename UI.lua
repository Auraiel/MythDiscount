local _, A = ...
local colors = {
    crafted="ffffff", raise="3399ff", max="66ff88", discount="ff5555", below="ff9d35", equal="eeeeee", unknown="aaaaaa",
}
local function Colored(text, color) return "|cff" .. color .. text .. "|r" end
local function Text(parent, x, y, width, font)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT", x, y); t:SetWidth(width); t:SetJustifyH("LEFT")
    return t
end
local function Num(n) return n and tostring(n) or "-" end

local function ItemText(char, slot, item, fresh, inBags)
    local account = A.db.account[slot.key] or {}
    local state = A.ItemState(item, account.value, A.achievementKnown and A.db.achievement, fresh)
    if A.preparation then
        state = A.PreparationState(item)
    elseif state ~= "crafted" and state ~= "max" and A.ItemCanRaise(char, slot, item, account.value, inBags) then
        state = "raise"
    end
    local value = Num(item and item.level) .. (item and item.crafted and A.T(" (крафт)") or "")
    local supported = A.SlotSupported(char, slot) ~= false
    return Colored(value, supported and colors[state] or "666666")
end

local function BagText(char, slot, full)
    local candidates = A.BetterBagItems(char, slot)
    local account = A.db.account[slot.key] or {}
    local live = A.live[slot.key] or {}
    local values = {}
    for i, item in ipairs(candidates) do
        if full or i <= 2 then
            values[#values+1] = ItemText(char, slot, item,
                A.selected == A.guid and live.account and char.bagsFresh, true)
        end
    end
    if not full and #candidates > 2 then values[#values+1] = "+" .. (#candidates-2) end
    local multiline = #values > 1 and (candidates[1].crafted or (candidates[2] and candidates[2].crafted))
    return #values > 0 and table.concat(values, multiline and "\n" or " / ") or "-", multiline
end

local function Tooltip(row)
    local slot = row.slot
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(A.T(slot.name), 1, 0.82, 0)
    if slot.key == "Finger" or slot.key == "Trinket" then
        GameTooltip:AddLine(A.T("Для скидки нужны два предмета нужного илвла на одном персонаже."), 1, 0.82, 0.3, true)
    elseif slot.weapon then
        GameTooltip:AddLine(A.T("Для оружия действуют отдельные пороги: двуручное или комплект одноручного и левой руки."), 1, 0.82, 0.3, true)
    end
    if slot.shield then
        GameTooltip:AddLine(A.T("Щиты: воин, паладин, шаман. Порог общий с предметами для левой руки."), 1, 0.82, 0.3, true)
    end
    local char = A.db.characters[A.selected]
    if char and #A.BetterBagItems(char, slot) > 0 then
        GameTooltip:AddLine(A.T("Есть в сумках: ") .. BagText(char, slot, true), 1, 1, 1, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(A.T("Все персонажи:"), 1, 0.82, 0)
    for _, guid in ipairs(A.CharactersBySlotLevel(A.db, slot.key)) do
        local c = A.db.characters[guid]
        local s = c.slots[slot.key]
        if s and A.Number(s.value) then
            GameTooltip:AddDoubleLine(c.name, Num(s.value), 1, 1, 1, 0.65, 0.85, 1)
        end
    end
    GameTooltip:Show()
end

function A.RefreshUI()
    local f = A.frame
    if not f or not A.db then return end
    local char = A.db.characters[A.selected]
    if not char then A.selected = A.guid; char = A.db.characters[A.guid] end
    if not char then return end
    local offline = A.selected ~= A.guid
    f.character:Update()
    f.title:SetText("MythDiscount")
    f.languageLabel:SetText(A.T("Язык:"))
    for i, label in ipairs({"Слот", "Надето", "Есть в сумках", "Максимум на аккаунте"}) do
        f.headers[i]:SetText(A.T(label))
    end
    local achievement = A.achievementKnown and A.db.achievement
    -- Explicit nil is needed: false is a known, locked achievement.
    if not A.achievementKnown then achievement = nil end
    f.achievement:SetText((A.achievementName or "#62416") .. ": " .. (achievement == true and A.T("|cff66ff88получено|r")
        or achievement == false and A.T("|cffffbb55не получено - подготовка|r") or A.T("статус неизвестен")))
    A.preparation = achievement == false
    local showAccount = achievement == true
    f.headers[4]:SetShown(showAccount)
    f.average:SetText(A.T("Средний илвл (надето): ") .. (char.averageEquipped and string.format("%.2f", char.averageEquipped) or "-")
        .. (offline and A.T(" (снимок)") or ""))
    f.average:SetShown(A.preparation)
    f.raise:SetShown(showAccount)
    f.hideUnavailable:SetChecked(MistDiscountDB.hideUnavailable == true)
    f.hideUnavailableLabel:SetText(A.T("Скрыть недоступные слоты"))
    local legendKeys = A.preparation and
        {"Не на треке «Легенда»", "«Легенда» ниже 334", "Максимум (334+)", "Может поднять лимит скидки уч. записи", "Крафтовый предмет"} or
        {"Не «Легенда» / нет скидки", "Можно улучшить со скидкой", "Максимум (334+)", "Может поднять лимит скидки уч. записи", "Крафтовый предмет"}
    for i, key in ipairs(legendKeys) do
        f.legendEntries[i].text:SetText(A.T(key))
        local shown = not (A.preparation and i == 4)
        f.legendEntries[i].text:SetShown(shown)
        f.legendEntries[i].square:SetShown(shown)
    end
    -- Compact only visible legend entries; preparation has no blue discount key.
    local legendTop = A.preparation and 161 or 139
    local legendCount = 0
    for i, entry in ipairs(f.legendEntries) do
        if not (A.preparation and i == 4) then
            local x = 20 + (legendCount%2)*290
            local y = -legendTop - math.floor(legendCount/2)*21
            entry.square:ClearAllPoints(); entry.square:SetPoint("TOPLEFT", x, y-1)
            entry.text:ClearAllPoints(); entry.text:SetPoint("TOPLEFT", x+17, y)
            legendCount = legendCount + 1
        end
    end
    local tableTop = legendTop + math.ceil(legendCount/2)*21 + 28
    for i, header in ipairs(f.headers) do
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", 20+(i-1)*130, -tableTop+20)
    end
    local rowY, visibleCount = tableTop, 0
    local raises = {}
    local seenRaise = {}
    for i, slot in ipairs(A.visibleSlots) do
        local row = f.rows[i]
        local account = A.db.account[slot.key] or {}
        local live = A.live[slot.key] or {}
        local supported = A.SlotSupported(char, slot) ~= false
        local values = {}
        for _, entry in ipairs(A.RowItems(char, slot)) do
            local item = entry.item
            values[#values+1] = ItemText(char, slot, item, not offline and live.account, false)
        end
        row.cells[1]:SetText(A.T(slot.name))
        row.cells[1]:SetTextColor(supported and 1 or 0.4, supported and 1 or 0.4, supported and 1 or 0.4)
        local craftedPair = #values > 1 and table.concat(values):find(A.T(" (крафт)"), 1, true)
        row.cells[2]:SetText(#values > 0 and table.concat(values, craftedPair and "\n" or " / ") or "-")
        local bagText, bagMultiline = BagText(char, slot)
        row.cells[3]:SetText(bagText)
        local height = (craftedPair or bagMultiline) and 43 or 25
        local visible = not MistDiscountDB.hideUnavailable or supported
        row:SetShown(visible)
        if visible then
            visibleCount = visibleCount + 1
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 18, -rowY)
            row:SetSize(577, height)
            row.bg:SetColorTexture(1, 1, 1, visibleCount % 2 == 0 and 0.04 or 0)
            rowY = rowY + height
        end
        row.cells[4]:SetText(Num(account.value) .. ((account.value and not live.account) and A.T(" (кэш)") or ""))
        row.cells[4]:SetShown(showAccount)
        if supported and A.AccountAtSeasonMax(char, slot, account.value) then
            row.cells[4]:SetTextColor(0.4, 1, 0.53)
        else
            row.cells[4]:SetTextColor(supported and 0.8 or 0.4, supported and 0.9 or 0.4, supported and 1 or 0.4)
        end
        local canRaise, target = A.CanRaise(char, slot, account.value)
        if canRaise and not seenRaise[slot.key] then
            seenRaise[slot.key] = true
            raises[#raises+1] = A.T(slot.name) .. A.T(" до ") .. target
        end
    end
    f.raise:ClearAllPoints()
    f.raise:SetPoint("TOPLEFT", 20, -rowY - 16)
    f:SetHeight(rowY + (showAccount and 90 or 22))
    local prefix = offline and A.T("Может поднять лимит скидки уч. записи (снимок): ") or A.T("Может поднять лимит скидки уч. записи: ")
    f.raise:SetText(prefix .. (#raises > 0 and table.concat(raises, "; ") or A.T("отсутствует")))

end

function A.CreateUI()
    if A.frame then return end
    A.visibleSlots = {}
    for _, slot in ipairs(A.slots) do
        if slot.key ~= "OnehandWeaponSecond" then
            A.visibleSlots[#A.visibleSlots+1] = slot
        end
    end
    local f = CreateFrame("Frame", "MythDiscountFrame", UIParent, "BackdropTemplate")
    A.frame = f
    f:SetSize(615, 715); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16, insets = {left=4,right=4,top=4,bottom=4} })
    f:SetBackdropColor(0.045, 0.06, 0.085, 0.98); f:SetBackdropBorderColor(0.3, 0.4, 0.5)
    f.title = Text(f, 20, -18, 300, "GameFontNormalLarge")
    f.languageLabel = Text(f, 345, -19, 70)
    f.language = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    f.language:SetPoint("TOPLEFT", 420, -12)
    f.language:SetSize(150, 24)
    f.languageLabel:ClearAllPoints()
    f.languageLabel:SetPoint("RIGHT", f.language, "LEFT", -10, 0)
    f.languageLabel:SetJustifyH("RIGHT")
    f.language:SetupMenu(function(_, root)
        for _, option in ipairs({{"auto", A.T("Авто (клиент)")}, {"ruRU", "Русский"}, {"enUS", "English"}}) do
            root:CreateRadio(option[2], function(value) return A.LanguageChoice() == value end,
                function(value) A.SetLanguage(value) end, option[1])
        end
    end)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    f.character = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    f.character:SetPoint("TOPLEFT", 20, -50)
    f.character:SetSize(330, 24)
    f.character:SetupMenu(function(_, root)
        root:SetScrollMode(300)
        for _, guid in ipairs(A.CharacterKeys(A.db)) do
            local character = A.db.characters[guid]
            local label = character.name .. (guid == A.guid and A.T(" (текущий)") or "")
            root:CreateRadio(label, function(value) return A.selected == value end,
                function(value) A.selected = value; A.RefreshUI() end, guid)
        end
    end)
    f.hideUnavailable = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.hideUnavailable:SetPoint("TOPLEFT", 17, -80)
    f.hideUnavailable:SetSize(26, 26)
    f.hideUnavailableLabel = Text(f, 48, -87, 545)
    f.hideUnavailable:SetScript("OnClick", function(self)
        MistDiscountDB.hideUnavailable = self:GetChecked() == true
        GameTooltip:Hide()
        A.RefreshUI()
    end)
    f.achievement = Text(f, 20, -113, 575)
    f.average = Text(f, 20, -135, 575)
    f.legendEntries = {}
    local legendColors = {{1,0.616,0.208}, {1,0.333,0.333}, {0.4,1,0.533}, {0.2,0.6,1}, {1,1,1}}
    for i, color in ipairs(legendColors) do
        local x, y = 20 + ((i-1)%2)*290, -161 - math.floor((i-1)/2)*21
        local square = f:CreateTexture(nil, "ARTWORK")
        square:SetPoint("TOPLEFT", x, y-1); square:SetSize(10,10)
        square:SetColorTexture(unpack(color))
        f.legendEntries[i] = { square=square, text=Text(f,x+17,y,268) }
    end

    local xs = {0, 130, 260, 390}
    local widths = {125, 125, 125, 185}
    local labels = {A.T("Слот"), A.T("Надето"), A.T("Есть в сумках"), A.T("Максимум на аккаунте")}
    f.headers = {}
    for j, label in ipairs(labels) do
        f.headers[j] = Text(f, 20 + xs[j], -232, widths[j], "GameFontNormalSmall")
        f.headers[j]:SetText(label)
    end
    f.rows = {}
    for i, slot in ipairs(A.visibleSlots) do
        local row = CreateFrame("Frame", nil, f)
        row.slot = slot
        row:SetPoint("TOPLEFT", 18, -252 - (i-1)*25); row:SetSize(577, 25); row:EnableMouse(true)
        local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); row.bg = bg
        bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
        row.cells = {}
        for j = 1, 4 do row.cells[j] = Text(row, 2 + xs[j], -6, widths[j]) end
        row:SetScript("OnEnter", Tooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.rows[i] = row
    end
    f.raise = Text(f, 20, -642, 575, "GameFontHighlight")
    f.raise:SetSpacing(3)
    f.raise:SetTextColor(0.2, 0.6, 1)
    tinsert(UISpecialFrames, "MythDiscountFrame")
    f:SetScript("OnShow", A.RefreshUI)
    f:Hide()
    A.RefreshUI()
end
