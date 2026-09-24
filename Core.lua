local addonName, A = ...
local events = CreateFrame("Frame")
A.live = {}

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function Initialize()
    MistDiscountDB = MistDiscountDB or { version = 1, contexts = {} }
    if MistDiscountDB.hideUnavailable == nil then MistDiscountDB.hideUnavailable = true end
    MistDiscountDB.contexts = MistDiscountDB.contexts or {}
    -- Isolate future stat squishes and seasons; never compare pre-squish peaks.
    local version = GetBuildInfo() or "12"
    local context = "mist-62416-major-" .. (version:match("^(%d+)") or "12")
    MistDiscountDB.contexts[context] = MistDiscountDB.contexts[context]
        or { characters = {}, account = {} }
    A.db = MistDiscountDB.contexts[context]
    A.guid = UnitGUID("player")
    if not A.guid then return end
    local name, realm = UnitFullName("player")
    realm = realm or GetRealmName()
    local char = A.db.characters[A.guid] or { slots = {}, equipped = {}, observed = {} }
    A.db.characters[A.guid] = char
    char.name = (name or "?") .. "-" .. realm
    if UnitClass then char.class = select(2, UnitClass("player")) end
    A.selected = A.selected or A.guid
end

local function ReadItem(link, tooltipFunction, first, second)
    local record = {
        link = link,
        level = A.Number(Safe(C_Item and C_Item.GetDetailedItemLevelInfo, link)),
        hwmSlot = Safe(C_ItemUpgrade and C_ItemUpgrade.GetHighWatermarkSlotForItem, link),
        upgrade = A.NormalizeUpgrade(Safe(C_Item and C_Item.GetItemUpgradeInfo, link)),
    }
    local tooltip = Safe(tooltipFunction, first, second)
    if not record.upgrade then
        record.upgrade = Safe(A.ParseUpgradeTooltip, tooltip)
    end
    local quality = Safe(C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo, link)
    record.crafted = A.DetectCrafted(quality, tooltip)
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, id, _, _, loc, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, link)
        if ok then
            record.itemID, record.equipLoc = id, loc
            record.itemClassID, record.itemSubClassID = classID, subClassID
        end
    end
    local stats = Safe(C_Item and C_Item.GetItemStats, link)
    if type(stats) == "table" then record.stats = stats end
    return record
end

local function RequestData(link)
    local id = tonumber(link:match("item:(%d+)"))
    if id and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end

function A.ScanBags(char)
    local api = C_Container
    if not api or not api.GetContainerNumSlots or not api.GetContainerItemLink then
        char.bagsFresh = false
        return false
    end
    local items, pending = {}, false
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local size = Safe(api.GetContainerNumSlots, bag)
        if size == nil then char.bagsFresh = false; return false end
        for index = 1, size do
            local link = Safe(api.GetContainerItemLink, bag, index)
            if link then
                local item = ReadItem(link, C_TooltipInfo and C_TooltipInfo.GetBagItem, bag, index)
                if not item.equipLoc or (item.equipLoc ~= "" and not item.level) then
                    RequestData(link); pending = true
                end
                if item.equipLoc and item.equipLoc ~= "" and item.hwmSlot ~= nil then
                    item.bag, item.bagSlot = bag, index
                    if (item.itemClassID == 2 or item.equipLoc == "INVTYPE_SHIELD" or item.equipLoc == "INVTYPE_HOLDABLE") and not item.stats then
                        RequestData(link); pending = true
                    end
                    -- Server usability includes class/level restrictions; unknown is not a recommendation.
                    item.usable = Safe(C_PlayerInfo and C_PlayerInfo.CanUseItem, item.itemID)
                    items[#items+1] = item
                end
            end
        end
    end
    -- Replace the snapshot, so moved/sold/equipped items cannot remain as phantom upgrades.
    char.bags, char.bagsFresh = items, not pending
    return pending
end

function A.Scan()
    if InCombatLockdown() then A.deferred = true; return end
    if not A.db or not A.guid then Initialize() end
    if not A.guid then return end
    local now = time()
    local char = A.db.characters[A.guid]
    char.lastSeen = now
    local _, equippedAverage = Safe(GetAverageItemLevel)
    char.averageEquipped = A.Number(equippedAverage)
    local api = C_ItemUpgrade or {}
    local enums = Enum and Enum.ItemRedundancySlot or {}
    A.live = {}
    for _, slot in ipairs(A.slots) do
        local key = slot.key
        char.slots[key] = char.slots[key] or {}
        A.db.account[key] = A.db.account[key] or {}
        local id = enums[key]
        if id ~= nil then
            local own, account = Safe(api.GetHighWatermarkForSlot, id)
            local ownOK = A.UpdateWatermark(char.slots[key], own, now)
            local accountOK = A.UpdateWatermark(A.db.account[key], account, now)
            A.live[key] = { own = ownOK, account = accountOK }
        end
    end
    local pending = false
    -- Equipped snapshots are separate from server eligibility. An empty slot clears
    -- the current item, but cannot erase its historical observed maximum.
    for _, inv in ipairs({1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}) do
        local link = GetInventoryItemLink("player", inv)
        if link then
            local item = ReadItem(link, C_TooltipInfo and C_TooltipInfo.GetInventoryItem, "player", inv)
            local level, hwmSlot = item.level, item.hwmSlot
            char.equipped[inv] = item
            char.observed[inv] = char.observed[inv] or {}
            A.Remember(char.observed[inv], "peak", level)
            -- Store weapon records by server category, not guessed inventory type.
            if level and hwmSlot ~= nil then
                for _, slot in ipairs(A.slots) do
                    if slot.weapon and enums[slot.key] == hwmSlot then
                        A.Remember(char.slots[slot.key], "observed", level)
                    end
                end
            end
            if not level then
                pending = true
                RequestData(link)
            end
        else
            char.equipped[inv] = nil
        end
    end
    if GetAchievementInfo then
        local id, name, _, completed = GetAchievementInfo(A.achievementID)
        A.achievementName = name
        if id then A.db.achievement = completed == true; A.achievementKnown = true end
    end
    local bagPending = A.ScanBags(char)
    A.pendingItems = pending or bagPending
    if A.RefreshUI then A.RefreshUI() end
end

function A.QueueScan()
    if A.queued then return end
    A.queued = true
    C_Timer.After(0.4, function() A.queued = false; A.Scan() end)
end

function A.Values(char, slot)
    local values, peak, lowest = {}, nil, nil
    local invs = slot.inv or {16,17}
    local enumID = Enum and Enum.ItemRedundancySlot and Enum.ItemRedundancySlot[slot.key]
    for _, inv in ipairs(invs) do
        local item = char.equipped[inv]
        if not slot.weapon or (item and enumID ~= nil and item.hwmSlot == enumID) then
            local level = item and item.level
            values[#values + 1] = level and tostring(level) or "-"
            if level then lowest = math.min(lowest or level, level) end
            local seen = char.observed[inv] and char.observed[inv].peak
            if not slot.weapon and seen then peak = math.max(peak or seen, seen) end
        end
    end
    if slot.weapon then peak = char.slots[slot.key] and char.slots[slot.key].observed end
    return #values > 0 and table.concat(values, " / ") or "-", peak, lowest
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("ITEM_UPGRADE_MASTER_UPDATE")
events:RegisterEvent("ITEM_UPGRADE_MASTER_SET_ITEM")
events:RegisterEvent("ACHIEVEMENT_EARNED")
events:RegisterEvent("CRITERIA_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:SetScript("OnEvent", function(_, event, arg, success)
    if event == "ADDON_LOADED" then
        if arg == addonName then Initialize() end
        return
    end
    if event == "ITEM_DATA_LOAD_RESULT" and (not A.pendingItems or not success) then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if not A.deferred then return end
        A.deferred = false
    end
    A.QueueScan()
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, A.QueueScan)
        C_Timer.After(5, A.QueueScan)
    end
end)

SLASH_MYTHDISCOUNT1 = "/mythdiscount"
SLASH_MYTHDISCOUNT2 = "/md"
SlashCmdList.MYTHDISCOUNT = function(message)
    message = (message or ""):lower():match("^%s*(.-)%s*$")
    if message == "scan" then A.Scan(); return end
    if message == "help" then
        print(A.T("|cff69ccf0MythDiscount|r: /md - окно; /md scan - обновить; /md resetpos - центр окна. Полная команда: /mythdiscount."))
        return
    end
    A.Scan()
    if not A.db then return end
    A.CreateUI()
    if message == "resetpos" then
        A.frame:ClearAllPoints(); A.frame:SetPoint("CENTER"); A.frame:Show()
    else A.frame:SetShown(not A.frame:IsShown()) end
end
