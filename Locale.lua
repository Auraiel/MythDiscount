local _, A = ...
local english = {
    ["Скрыть недоступные слоты"] = "Hide unavailable slots",
    [" (крафт)"] = " (crafted)",
    ["Достижение #62416"] = "Achievement #62416",
    ["Не на треке «Легенда»"] = "Not on the Myth track",
    ["«Легенда» ниже 334"] = "Myth below 334",
    ["Не «Легенда» / нет скидки"] = "Not Myth / no discount",
    ["Можно улучшить со скидкой"] = "Discounted upgrade available",
    ["Максимум (334+)"] = "Maximum (334+)",
    ["Может поднять лимит скидки уч. записи"] = "Can raise account discount limit",
    ["Крафтовый предмет"] = "Crafted item",
    ["Для скидки нужны два предмета нужного илвла на одном персонаже."] = "The discount requires two items at the target item level on the same character.",
    ["Для оружия действуют отдельные пороги: двуручное или комплект одноручного и левой руки."] = "Weapons have separate thresholds: a two-hander or a main-hand and off-hand pair.",
    ["Щиты: воин, паладин, шаман. Порог общий с предметами для левой руки."] = "Shields: Warrior, Paladin, Shaman. Shares a threshold with held off-hand items.",
    ["Есть в сумках: "] = "In bags: ",
    ["Все персонажи:"] = "All characters:",
    ["|cff66ff88получено|r"] = "|cff66ff88earned|r",
    ["|cffffbb55не получено - подготовка|r"] = "|cffffbb55not earned - preparation|r",
    ["статус неизвестен"] = "status unknown",
    ["Средний илвл (надето): "] = "Average item level (equipped): ",
    [" (снимок)"] = " (snapshot)",
    [" (кэш)"] = " (cached)",
    [" до "] = " to ",
    ["Может поднять лимит скидки уч. записи (снимок): "] = "Can raise account discount limit (snapshot): ",
    ["Может поднять лимит скидки уч. записи: "] = "Can raise account discount limit: ",
    ["отсутствует"] = "none",
    ["Язык:"] = "Language:",
    [" (текущий)"] = " (current)",
    ["Обновить"] = "Refresh",
    ["Слот"] = "Slot",
    ["Надето"] = "Equipped",
    ["Есть в сумках"] = "In bags",
    ["Максимум на аккаунте"] = "Account maximum",
    ["|cff69ccf0MythDiscount|r: /md - окно; /md scan - обновить; /md resetpos - центр окна. Полная команда: /mythdiscount."] = "|cff69ccf0MythDiscount|r: /md - toggle window; /md scan - refresh; /md resetpos - center window. Full command: /mythdiscount.",
    ["Голова"] = "Head",
    ["Шея"] = "Neck",
    ["Плечи"] = "Shoulders",
    ["Спина"] = "Back",
    ["Грудь"] = "Chest",
    ["Запястья"] = "Wrists",
    ["Кисти"] = "Hands",
    ["Пояс"] = "Waist",
    ["Ноги"] = "Legs",
    ["Ступни"] = "Feet",
    ["Кольца"] = "Rings",
    ["Аксессуары"] = "Trinkets",
    ["Двуручное"] = "Two-handed",
    ["Правая рука (инт)"] = "Main hand (Int)",
    ["Одноручное"] = "One-handed",
    ["Второе одноруч."] = "Second one-hand",
    ["Левая рука"] = "Off-hand",
    ["Щит"] = "Shield",
    ["Нет данных"] = "No data",
    ["Порог "] = "Threshold ",
    ["Порог достигнут"] = "Threshold reached",
    ["Нужно достижение"] = "Achievement required",
    ["Статус неизвестен"] = "Status unknown",
    ["До "] = "Up to ",
    ["Авто (клиент)"] = "Auto (client)",
    ["|cffff9d35Оранжевый|r - не на треке «Легенда».\n|cffff5555Красный|r - «Легенда» ниже 334.  |cff66ff88Зелёный (334+)|r - максимум"] = "|cffff9d35Orange|r - not on the Myth track.\n|cffff5555Red|r - Myth below 334.  |cff66ff88Green (334+)|r - maximum",
    ["|cffff9d35Оранжевый|r - не «Легенда» или нет улучшения со скидкой.\n|cffff5555Красный|r - можно улучшить со скидкой.  |cff66ff88Зелёный (334+)|r - максимум"] = "|cffff9d35Orange|r - not Myth or no discounted upgrade available.\n|cffff5555Red|r - discounted upgrade available.  |cff66ff88Green (334+)|r - maximum",
}

function A.LanguageChoice()
    return MistDiscountDB and MistDiscountDB.language or "auto"
end

function A.Language()
    local choice = A.LanguageChoice()
    if choice == "ruRU" or choice == "enUS" then return choice end
    return GetLocale and GetLocale() == "ruRU" and "ruRU" or "enUS"
end

function A.T(text)
    if A.Language() == "ruRU" then return text end
    return english[text] or text
end

function A.SetLanguage(choice)
    if choice ~= "auto" and choice ~= "ruRU" and choice ~= "enUS" then return end
    MistDiscountDB = MistDiscountDB or { version=1, contexts={} }
    MistDiscountDB.language = choice
    if GameTooltip then GameTooltip:Hide() end
    if A.frame then
        A.frame.character:GenerateMenu()
        A.frame.language:GenerateMenu()
    end
    if A.RefreshUI then A.RefreshUI() end
end
