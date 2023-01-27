require "ui.pages.pages"
require "ui.numberInput"

local craftCountPage = {
  shouldMakeBackButton = true,
  backButtonText = "Cancel"
}

pages.addPage("craftCount", craftCountPage)

local w, h = term.getSize()

function craftCountPage.setup(itemName)
  local recipe = storage.crafting.getRecipe(itemName)
  if not recipe then error("Tried to craft a non-existent recipe?") end

  pages.writeTitle("Crafting " .. recipe.displayName)

  -- Vertical line
  local lineX = 2 + math.floor((w - 4) * 0.4)
  term.setTextColor(colors.gray)
  for y = 5, h - 1 do
    term.setCursorPos(lineX, y)
    term.write("|")
  end
  term.setTextColor(colors.white)

  -- Count title
  local midLeftX = 2 + math.floor((w - 4) * 0.2)
  local countTitleText = "Amount to craft"
  term.setCursorPos(math.ceil(midLeftX - #countTitleText / 2), 6)
  term.write(countTitleText)

  local countInput = pages.elem(ui.numberInput.create())
  countInput:setPos(2, 8)
  countInput:setSize(lineX - 5, 3)
  countInput:setValue(1)
  countInput:setMax(9999)
  countInput:setCanDeselect(false)

  local makePlanButton = pages.elem(ui.text.create())
  makePlanButton:setPos(lineX - 16, h - 4)
  makePlanButton:setSize(13, 3)
  makePlanButton:setTextDrawPos(2, 1)
  makePlanButton:setText("Make plan")
  function makePlanButton:onClick()
    if countInput:getValue() == 0 then return end
    if craftCountPage.plan and craftCountPage.plan.craftable then
      storage.crafting.unreservePlan(craftCountPage.plan.id)
    end
    craftCountPage.plan = storage.crafting.makeCraftPlan(itemName, countInput:getValue(), os.getComputerID())
    -- Wait for reserve item updates on client
    -- Consider a different mechanism, good enough for now
    if storage.remote.isRemote then
      craftCountPage.sleeping = true
      sleep(0.2)
      craftCountPage.sleeping = false
    end
    craftCountPage.displayPlan()
  end

  function countInput:onChange(_, new)
    if new == 0 then
      makePlanButton:setTextColor(colors.black)
      makePlanButton:setBgColor(colors.black)
    else
      makePlanButton:setTextColor(colors.white)
      makePlanButton:setBgColor(colors.gray)
    end
  end

  local function countChangeButton(num, x, y)
    local btn = pages.elem(ui.text.create())
    local str = num and tostring(num) or "    RESET    "
    if num and num > 0 then str = "+" .. str end
    str = "  " .. str .. "  "
    btn:setText(str)
    btn:setSize(#str, 3)
    btn:setTextDrawPos(0, 1)
    btn:setPos(x, y)
    function btn:onClick()
      if num then
        if countInput:getValue() == 1 and num == 64 then return countInput:setValue(64) end -- If running +64 on 1, it should go to 64 for convenience
        countInput:setValue(math.max(countInput:getValue() + num, 1))
      else
        countInput:setValue(1)
      end
    end
  end

  countChangeButton(-1, midLeftX - 9, 12)
  countChangeButton(-64, midLeftX - 10, 16)
  countChangeButton(1, midLeftX, 12)
  countChangeButton(64, midLeftX, 16)
  countChangeButton(nil, midLeftX - 10, 20)

  timer.simple(0.05, function()
    hook.add("key", "craftCountKey", function(key)
      if key ~= keys.enter then return end

      if countInput:getValue() == 0 then
        countInput:setValue(1)
      end
      if craftCountPage.plan and craftCountPage.plan.count == countInput:getValue() then
        if craftCountPage.sleeping then
          craftCountPage.craftBtn:onClick()
        end
      else
        makePlanButton:onClick()
      end
    end)
  end)

  local midRightX = 2 + math.floor((w - 4) * 0.7)
  local ingredientsTitleText = "Ingredients"
  term.setCursorPos(math.ceil(midRightX - #ingredientsTitleText / 2), 6)
  term.write(ingredientsTitleText)

  local noCraftText = "Make a plan on the left to show ingredients"
  term.setCursorPos(math.ceil(midRightX - #noCraftText / 2), 19)
  term.setTextColor(colors.gray)
  term.write(noCraftText)
  term.setTextColor(colors.white)
end

function craftCountPage.displayPlan()
  craftCountPage.madeChange = false

  if not craftCountPage.ingredientsList then
    local lineX = 2 + math.floor((w - 4) * 0.4)

    --make the list without options
    local ingredientsList = pages.elem(ui.buttonListPaged.create())
    craftCountPage.ingredientsList = ingredientsList
    ingredientsList:setPos(lineX + 2, 8)
    ingredientsList:setSize(w - 4 - lineX, h - 14)
    ingredientsList:setSplits(0.5)
    ingredientsList:setHeader({"Item name", "Available / Required"})

    local craftBtn = pages.elem(ui.text.create())
    craftCountPage.craftBtn = craftBtn
    craftBtn:setPos(lineX + 2, h - 4)
    local btnWidth = w - 4 - lineX
    craftBtn:setSize(btnWidth, 3)
    craftBtn:setTextDrawPos(math.floor(btnWidth / 2 - 3), 1)
    craftBtn:setText("CRAFT")
    function craftBtn:onClick()
      if not craftCountPage.plan.craftable then return end
      storage.crafting.runPlan(craftCountPage.plan.id)
      craftCountPage.plan = nil
      pages.setPage("itemList")
    end
  end

  local ingredientsList = craftCountPage.ingredientsList

  local toNum = {[true] = 1, [false] = 0}

  local ingredientKeys = table.keys(craftCountPage.plan.ingredients)
  local ingredientNames = {}

  for _, ingredientKey in ipairs(ingredientKeys) do
    ingredientNames[ingredientKey] =
      craftCountPage.plan.ingredientDisplayNames[ingredientKey] or
      (storage.items[ingredientKey] and storage.items[ingredientKey].detail.displayName) or
      ingredientKey
  end

  table.sort(ingredientKeys, function(a, b)
    local aMissing = toNum[craftCountPage.plan.missingIngredients[a]]
    local bMissing = toNum[craftCountPage.plan.missingIngredients[b]]
    if aMissing == bMissing then
      return ingredientNames[a] < ingredientNames[b]
    else
      return aMissing < bMissing
    end
  end)

  local options = {}

  for _, itemName in ipairs(ingredientKeys) do
    local missing = craftCountPage.plan.missingIngredients[itemName]
    local available = 0
    local required = craftCountPage.plan.ingredients[itemName]
    if storage.items[itemName] then
      available = storage.items[itemName].count
      if craftCountPage.plan.craftable then
        available = available + required
      end
    end
    local name = ingredientNames[itemName]
    local entry = {displayText = {name, available .. " / " .. required}}
    if missing then
      entry.bgColor = colors.red
    end
    table.insert(options, entry)
  end
  ingredientsList:setOptions(options)

  local craftBtn = craftCountPage.craftBtn
  if craftCountPage.plan.craftable then
    craftBtn:setTextColor(colors.white)
    craftBtn:setBgColor(colors.gray)
  else
    craftBtn:setTextColor(colors.black)
    craftBtn:setBgColor(colors.black)
  end
end

function craftCountPage.cleanup()
  if craftCountPage.plan and craftCountPage.plan.craftable then
    storage.crafting.unreservePlan(craftCountPage.plan.id)
  end
  craftCountPage.ingredientsList = nil
  craftCountPage.plan = nil
end
