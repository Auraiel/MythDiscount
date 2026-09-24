local _, A = ...
A.achievementID = 62416
A.upgradeCap = 334
A.slots = {
    { key = "Head", name = "Голова", inv = {1} },
    { key = "Neck", name = "Шея", inv = {2} },
    { key = "Shoulder", name = "Плечи", inv = {3} },
    { key = "Cloak", name = "Спина", inv = {15} },
    { key = "Chest", name = "Грудь", inv = {5} },
    { key = "Wrist", name = "Запястья", inv = {9} },
    { key = "Hand", name = "Кисти", inv = {10} },
    { key = "Waist", name = "Пояс", inv = {6} },
    { key = "Legs", name = "Ноги", inv = {7} },
    { key = "Feet", name = "Ступни", inv = {8} },
    { key = "Finger", name = "Кольца", inv = {11, 12} },
    { key = "Trinket", name = "Аксессуары", inv = {13, 14} },
    { key = "Twohand", name = "Двуручное", weapon = true },
    { key = "MainhandWeapon", name = "Правая рука (инт)", weapon = true },
    { key = "OnehandWeapon", name = "Одноручное", weapon = true },
    { key = "OnehandWeaponSecond", name = "Второе одноруч.", weapon = true },
    { key = "Offhand", name = "Левая рука", weapon = true, equipLoc = "INVTYPE_HOLDABLE" },
    { key = "Offhand", name = "Щит", weapon = true, equipLoc = "INVTYPE_SHIELD", shield = true },
}

function A.Number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "number" and value == value and value > 0 and value < 100000 then
        return value
    end
end

-- Practical equipment across all specs of a class, not mere proficiency.
-- Onehand includes weapon + shield (Protection), not only dual wield.
A.classWeapons = {
    WARRIOR = { twohand=true, onehand=true, dual=true, main=false, held=false, shield=true },
    PALADIN = { twohand=true, onehand=true, dual=false, main=true, held=false, shield=true },
    HUNTER = { twohand=true, onehand=true, dual=true, main=false, held=false, shield=false },
    ROGUE = { twohand=false, onehand=true, dual=true, main=false, held=false, shield=false },
    PRIEST = { twohand=true, onehand=false, dual=false, main=true, held=true, shield=false },
    DEATHKNIGHT = { twohand=true, onehand=true, dual=true, main=false, held=false, shield=false },
    SHAMAN = { twohand=false, onehand=true, dual=true, main=true, held=false, shield=true },
    MAGE = { twohand=true, onehand=false, dual=false, main=true, held=true, shield=false },
    WARLOCK = { twohand=true, onehand=false, dual=false, main=true, held=true, shield=false },
    MONK = { twohand=true, onehand=true, dual=true, main=true, held=true, shield=false },
    DRUID = { twohand=true, onehand=false, dual=false, main=true, held=true, shield=false },
    DEMONHUNTER = { twohand=false, onehand=true, dual=true, main=true, held=false, shield=false },
    EVOKER = { twohand=true, onehand=false, dual=false, main=true, held=true, shield=false },
}

function A.SlotSupported(char, slot)
    local caps = A.classWeapons[char.class]
    if not caps then return nil end
    if slot.shield then return caps.shield end
    if slot.equipLoc == "INVTYPE_HOLDABLE" then return caps.held end
    if slot.key == "Twohand" then return caps.twohand end
    if slot.key == "MainhandWeapon" then return caps.main end
    if slot.key == "OnehandWeapon" then return caps.onehand end
    if slot.key == "OnehandWeaponSecond" then return caps.dual end
    return true
end

local function Types(...)
    local result = {}
    for _, id in ipairs({...}) do result[id] = true end
    return result
end
-- Weapon subclass IDs: axe 0/1, bow 2, gun 3, mace 4/5, polearm 6,
-- sword 7/8, glaive 9, staff 10, fist 13, dagger 15, crossbow 18, wand 19.
-- Stat-specific sets prevent, for example, an Agility dagger for Feral or
-- an Intellect sword for a Warrior. Hybrid classes retain off-spec gear.
A.weaponProfiles = {
    WARRIOR = { STR=Types(0,1,4,5,6,7,8) },
    PALADIN = { STR=Types(0,1,4,5,6,7,8), INT=Types(0,4,7) },
    HUNTER = { AGI=Types(0,1,2,3,6,7,8,10,13,15,18) },
    ROGUE = { AGI=Types(0,4,7,13,15) },
    PRIEST = { INT=Types(4,10,15,19) },
    DEATHKNIGHT = { STR=Types(0,1,4,5,6,7,8) },
    SHAMAN = { AGI=Types(0,4,13), INT=Types(0,4,13,15) },
    MAGE = { INT=Types(7,10,15,19) },
    WARLOCK = { INT=Types(7,10,15,19) },
    MONK = { AGI=Types(0,4,6,7,10,13), INT=Types(0,4,7,10,13) },
    DRUID = { AGI=Types(5,6,10), INT=Types(4,5,10,13,15) },
    DEMONHUNTER = { AGI=Types(0,7,9,13), INT=Types(0,7,9,13) },
    EVOKER = { INT=Types(0,1,4,5,7,8,10,13,15) },
}

local function HasStat(stats, stat)
    if type(stats) ~= "table" then return false end
    if A.Number(stats["ITEM_MOD_" .. stat .. "_SHORT"]) then return true end
    for _, combination in ipairs({"AGI_STR_INT", "AGI_STR", "AGI_INT", "STR_INT"}) do
        if combination:find(stat, 1, true) and A.Number(stats["ITEM_MOD_" .. combination .. "_SHORT"]) then return true end
    end
    return false
end

-- nil means an old snapshot or missing item data; never recommend it in bags.
function A.PracticalWeapon(char, item)
    if not item then return nil end
    local profiles = A.weaponProfiles[char.class]
    if not profiles then return nil end
    local loc = item.equipLoc
    if loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
        local caps = A.classWeapons[char.class]
        if not (loc == "INVTYPE_SHIELD" and caps.shield or loc == "INVTYPE_HOLDABLE" and caps.held) then return false end
        if not item.stats then return nil end
        for stat in pairs(profiles) do
            if HasStat(item.stats, stat) then return true end
        end
        return false
    end
    if item.itemClassID ~= 2 then return item.itemClassID and true or nil end
    if item.itemSubClassID == nil or not item.stats then return nil end
    for stat, types in pairs(profiles) do
        if types[item.itemSubClassID] and HasStat(item.stats, stat) then return true end
    end
    return false
end

function A.BagBaseline(char, slot)
    local entries = A.RowItems(char, slot)
    if slot.weapon and #entries == 0 then
        local inv = (slot.key == "Offhand" or slot.key == "OnehandWeaponSecond") and 17 or 16
        entries = {{ item = char.equipped[inv] }}
    end
    local lowest
    for _, entry in ipairs(entries) do
        if entry.item and not A.Number(entry.item.level) then return nil end
        local level = entry.item and entry.item.level or 0
        lowest = math.min(lowest or level, level)
    end
    return lowest or 0
end

function A.BetterBagItems(char, slot)
    local result = {}
    if A.SlotSupported(char, slot) == false then return result end
    local baseline = A.BagBaseline(char, slot)
    if baseline == nil then return result end
    for _, item in ipairs(char.bags or {}) do
        if item.usable == true and (not slot.weapon or A.PracticalWeapon(char, item) == true) and A.Number(item.level) and item.level > baseline and A.Matches(item, slot) then
            result[#result+1] = item
        end
    end
    table.sort(result, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        if a.bag ~= b.bag then return (a.bag or 0) < (b.bag or 0) end
        return (a.bagSlot or 0) < (b.bagSlot or 0)
    end)
    return result
end

function A.Matches(item, slot)
    if not item then return false end
    if slot.equipLoc then return item.equipLoc == slot.equipLoc end
    local enum = Enum and Enum.ItemRedundancySlot
    return enum and enum[slot.key] ~= nil and item.hwmSlot == enum[slot.key]
end

function A.IsMythTrack(name)
    if type(name) ~= "string" then return false end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return name:find("Myth") ~= nil or name:find("Миф") ~= nil or name:find("миф") ~= nil
        or name:find("Легенда") ~= nil or name:find("легенда") ~= nil
        or name:find("Эпохальн") ~= nil or name:find("эпохальн") ~= nil
end

function A.PreparationState(item)
    if not item or not A.Number(item.level) then return "unknown" end
    if item.crafted then return "crafted" end
    if item.level >= A.upgradeCap then return "max" end
    if item.upgrade and item.upgrade.myth then return "discount" end
    return "below"
end

function A.AccountAtSeasonMax(char, slot, account)
    if not A.Number(account) or account < A.upgradeCap then return false end
    local entries = A.RowItems(char, slot)
    if #entries == 0 then return false end
    for _, entry in ipairs(entries) do
        if not entry.item or not A.Number(entry.item.level) or entry.item.level < A.upgradeCap then return false end
    end
    return true
end

function A.NormalizeUpgrade(info)
    if type(info) ~= "table" then return nil end
    local rank, ranks = A.Number(info.currentLevel), A.Number(info.maxLevel)
    local cap = A.Number(info.maxItemLevel)
    if not rank or not ranks or not cap or rank > ranks then return nil end
    return { rank=rank, ranks=ranks, cap=math.min(A.upgradeCap, cap),
        myth=A.IsMythTrack(info.trackString), track=info.trackString, source="api" }
end

function A.ParseUpgradeTooltip(data)
    local enum = Enum and Enum.TooltipDataLineType
    if not data or not data.lines or not enum then return nil end
    for _, line in ipairs(data.lines) do
        if line.type == enum.ItemUpgradeLevel and type(line.leftText) == "string"
            and not (issecretvalue and issecretvalue(line.leftText)) then
            local text = line.leftText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local rank, ranks = text:match("(%d+)%s*/%s*(%d+)")
            rank, ranks = tonumber(rank), tonumber(ranks)
            if rank and ranks and rank <= ranks and A.IsMythTrack(text) then
                return { rank=rank, ranks=ranks, cap=A.upgradeCap, myth=true, source="tooltip" }
            end
        end
    end
end

function A.Potential(item)
    if not item or not A.Number(item.level) then return nil, false end
    if item.crafted then return item.level, false end
    local u = item.upgrade
    if u and u.myth and u.rank < u.ranks and u.cap > item.level then
        return math.min(u.cap, A.upgradeCap), true
    end
    return item.level, false
end

-- A displayed 344 still remains 344; only the comparison/upgrade target is capped.
function A.ItemState(item, account, achievement, fresh)
    local level = item and A.Number(item.level)
    if not level then return "unknown", "" end
    if item.crafted then return "crafted", "" end
    local target = A.Number(account) and math.min(account, A.upgradeCap)
    if level >= A.upgradeCap then return "max", target and "=" or "" end
    if not target then return "unknown", "" end
    if level >= target then return "below", level == target and "=" or ">" end
    local potential, canUpgrade = A.Potential(item)
    -- At the last rank the next step is exactly the track cap, not any intermediate ilvl.
    local nextFits = canUpgrade and (item.upgrade.rank + 1 ~= item.upgrade.ranks or potential <= target)
    if canUpgrade and nextFits and potential > level and achievement == true and fresh then
        return "discount", "<"
    end
    return "below", "<"
end

function A.RowItems(char, slot)
    local items = {}
    for _, inv in ipairs(slot.inv or {16,17}) do
        local item = char.equipped[inv]
        if slot.inv or A.Matches(item, slot) then
            items[#items+1] = { inv=inv, item=item }
        end
    end
    return items
end

function A.CanRaise(char, slot, account)
    if not A.Number(account) or account >= A.upgradeCap or A.SlotSupported(char, slot) == false then return false end
    local items = A.RowItems(char, slot)
    if #items == 0 then return false end
    if slot.weapon then
        local main, off = char.equipped[16], char.equipped[17]
        if not main then return false end
        local twohand = main.equipLoc == "INVTYPE_2HWEAPON" or main.equipLoc == "INVTYPE_RANGED"
            or main.equipLoc == "INVTYPE_RANGEDRIGHT"
        -- Titan's Grip is treated as a pair when two weapons are actually equipped.
        items = twohand and not off and {{item=main}} or {{item=main}, {item=off}}
    end
    local ceiling, changed = nil, false
    for _, entry in ipairs(items) do
        if slot.weapon and A.PracticalWeapon(char, entry.item) == false then return false end
        local potential, upgradable = A.Potential(entry.item)
        if not potential then return false end
        ceiling = math.min(ceiling or potential, potential)
        changed = changed or upgradable
    end
    if changed and ceiling > account then return true, math.min(ceiling, A.upgradeCap) end
    return false
end

function A.Remember(record, field, value)
    value = A.Number(value)
    if value and (not record[field] or value > record[field]) then record[field] = value end
end

-- Nil means unavailable, never zero. Historical peaks are not discount eligibility.
function A.UpdateWatermark(record, value, now)
    value = A.Number(value)
    if not value then return false end
    record.value, record.updated = value, now
    A.Remember(record, "peak", value)
    return true
end

function A.Forecast(current, account, achievement, fresh)
    if not A.Number(account) then return A.T("Нет данных"), "unknown" end
    if not A.Number(current) then return A.T("Порог ") .. account, "unknown" end
    if current >= account then return A.T("Порог достигнут"), "done" end
    if achievement == false then return A.T("Нужно достижение"), "locked" end
    if achievement ~= true then return A.T("Статус неизвестен"), "unknown" end
    if not fresh then return A.T("До ") .. account .. A.T(" (кэш)"), "cached" end
    return A.T("До ") .. account .. " (+" .. (account - current) .. ")", "available"
end

function A.CharacterKeys(db)
    local keys = {}
    for key in pairs(db.characters) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        return db.characters[a].name < db.characters[b].name
    end)
    return keys
end


-- A positive crafting quality is specific to a crafted output, not item rarity.
function A.DetectCrafted(quality, tooltip)
    if A.Number(quality) then return true end
    for index, line in ipairs(tooltip and tooltip.lines or {}) do
        local text = line.leftText
        if index > 1 and type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if text:lower():find("tidal crafted", 1, true) then return true end
        end
    end
    return false
end

function A.ItemCanRaise(char, slot, item, account, inBags)
    if not item or item.crafted or not A.Number(account) then return false end
    local potential, canUpgrade = A.Potential(item)
    if not canUpgrade or potential <= account then return false end
    if not inBags then return A.CanRaise(char, slot, account) end
    local virtual = { class=char.class, equipped={} }
    for inv, value in pairs(char.equipped) do virtual.equipped[inv] = value end
    local destination, weakest
    for _, entry in ipairs(A.RowItems(char, slot)) do
        if entry.item and not A.Number(entry.item.level) then return false end
        local level = entry.item and entry.item.level or 0
        if not weakest or level < weakest then destination, weakest = entry.inv, level end
    end
    destination = destination or ((slot.key == "Offhand" or slot.key == "OnehandWeaponSecond") and 17 or 16)
    virtual.equipped[destination] = item
    if item.equipLoc == "INVTYPE_2HWEAPON" or item.equipLoc == "INVTYPE_RANGED" or item.equipLoc == "INVTYPE_RANGEDRIGHT" then
        local off = virtual.equipped[17]
        if not (char.class == "WARRIOR" and off and off.equipLoc == "INVTYPE_2HWEAPON") then virtual.equipped[17] = nil end
    end
    return A.CanRaise(virtual, slot, account)
end
