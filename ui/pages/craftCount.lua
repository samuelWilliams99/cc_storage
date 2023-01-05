require "ui.pages.pages"

local craftCountPage = {}

pages.addPage("craftCount", craftCountPage)

local w, h = term.getSize()

local function addElem(elem)
  table.insert(craftCountPage.elems, elem)
  return elem
end

-- later we'll need an active plans page.
-- for now though we can do a "x crafting plans running" in the corner or some shit

function craftCountPage.setup(itemName)
  craftCountPage.elems = {}

  local recipe = storage.crafting.recipes[itemName]
  if not recipe then error("Tried to craft a non-existent recipe?") end

  -- Main title
  local titleText = "Crafting " .. recipe.displayName
  term.setCursorPos(math.floor(w / 2 - #titleText / 2), 2)
  term.write(titleText)

  -- Horizontal line
  term.setTextColor(colors.gray)
  term.setCursorPos(3, 4)
  term.write(string.rep("_", w - 4))

  -- Vertical line
  local lineX = 2 + math.floor((w - 4) * 0.4)
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

  local count = 1
  local countText = addElem(ui.text.create())
  countText:setPos(4, 8)
  countText:setSize(lineX - 7, 3)
  countText:setTextDrawPos(0, 1)

  local cancelButton = addElem(ui.text.create())
  cancelButton:setPos(4, h - 6)
  cancelButton:setSize(13, 3)
  cancelButton:setTextDrawPos(3, 1)
  cancelButton:setText("Cancel")
  function cancelButton:onClick()
    pages.setPage("itemList")
  end

  local makePlanButton = addElem(ui.text.create())
  makePlanButton:setPos(lineX - 16, h - 6)
  makePlanButton:setSize(13, 3)
  makePlanButton:setTextDrawPos(2, 1)
  makePlanButton:setText("Make plan")
  function makePlanButton:onClick()
    if count == 0 then return end
    if craftCountPage.plan and craftCountPage.plan.craftable then
      storage.crafting.unreservePlan(craftCountPage.plan)
    end
    craftCountPage.plan = storage.crafting.makeCraftPlan(itemName, count)
    craftCountPage.displayPlan()
  end

  local showUnderscore = true
  local function updateCount(n)
    local changed = count ~= n

    count = n
    local str = ""
    if count > 0 then str = tostring(count) end 
    if showUnderscore then str = str .. "_" end
    countText:setText("  " .. str)
    countText:invalidateLayout(true)

    if not changed then return end

    if count == 0 then
      makePlanButton:setTextColor(colors.black)
      makePlanButton:setBgColor(colors.black)
    else
      makePlanButton:setTextColor(colors.white)
      makePlanButton:setBgColor(colors.gray)
    end
  end

  updateCount(1)

  timer.create("craftCountUnderscore", 0.5, 0, function()
    showUnderscore = not showUnderscore
    updateCount(count)
  end)

  local function countChangeButton(num, x, y)
    local btn = addElem(ui.text.create())
    local str = num and tostring(num) or "    RESET    "
    if num and num > 0 then str = "+" .. str end
    str = "  " .. str .. "  "
    btn:setText(str)
    btn:setSize(#str, 3)
    btn:setTextDrawPos(0, 1)
    btn:setPos(x, y)
    function btn:onClick()
      if num then
        if count == 1 and num == 64 then updateCount(0) end -- If running +64 on 1, it should go to 64 for convenience
        updateCount(math.max(count + num, 1))
      else
        updateCount(1)
      end
    end
  end

  countChangeButton(-1, midLeftX - 8, 12)
  countChangeButton(-64, midLeftX - 9, 16)
  countChangeButton(1, midLeftX + 1, 12)
  countChangeButton(64, midLeftX + 1, 16)
  countChangeButton(nil, midLeftX - 9, 20)

  hook.add("char", "craftCountChar", function(char)
    local num = tonumber(char)
    if not num then return end
    updateCount(count * 10 + num)
  end)

  hook.add("key", "craftCountKey", function(key)
    if key == keys.backspace then
      updateCount(math.floor(count / 10))
    elseif key == keys.enter and count == 0 then
      updateCount(1)
    end
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
  local plan = craftCountPage.plan
  if plan.craftable then
    storage.crafting.reservePlan(plan)
  end

  if not craftCountPage.ingredientsList then
    local lineX = 2 + math.floor((w - 4) * 0.4)

    --make the list without options
    local ingredientsList = addElem(ui.buttonList.create())
    craftCountPage.ingredientsList = ingredientsList
    ingredientsList:setPos(lineX + 2, 8)
    ingredientsList:setSize(w - lineX - 6, h - 16)

    local craftBtn = addElem(ui.text.create())
    craftCountPage.craftBtn = craftBtn
    craftBtn:setPos(lineX + 2, h - 6)
    local btnWidth = w - 4 - lineX - 2
    craftBtn:setSize(btnWidth, 3)
    craftBtn:setTextDrawPos(math.floor(btnWidth / 2 - 3), 1)
    craftBtn:setText("CRAFT")
    function craftBtn:onClick()
      if not plan.craftable then return end
      storage.crafting.runPlan(plan)
      craftCountPage.plan = nil
      pages.setPage("itemList")
    end
  end

  local ingredientsList = craftCountPage.ingredientsList

  local toNum = {[true] = 1, [false] = 0}

  local ingredientKeys = table.keys(plan.ingredients)
  table.sort(ingredientKeys, function(a, b)
    local aMissing = toNum[plan.missingIngredients[a]]
    local bMissing = toNum[plan.missingIngredients[b]]
    if aMissing == bMissing then
      return a < b
    else
      return aMissing < bMissing
    end
  end)

  local ingredientSplitX = 2 + math.floor((w - 4) * 0.7)
  local xOffset = ingredientSplitX - ingredientsList.pos.x
  local options = {
    { displayText = "Item name" .. string.rep(" ", xOffset - 9) .. "| Available / missing"
    }
  }

  for _, itemName in ipairs(ingredientKeys) do
    local missing = plan.missingIngredients[itemName]
    local name = itemName
    local available = 0
    if storage.items[itemName] then
      name = storage.items[itemName].detail.displayName
      available = storage.items[itemName].count
    end
    local str = name .. string.rep(" ", xOffset - #name) .. "| " .. available .. " / " .. (missing or 0)
    table.insert(options, {displayText = str})
  end
  ingredientsList:setOptions(options)

  local craftBtn = craftCountPage.craftBtn
  if plan.craftable then
    craftBtn:setTextColor(colors.white)
    craftBtn:setBgColor(colors.gray)
  else
    craftBtn:setTextColor(colors.black)
    craftBtn:setBgColor(colors.black)
  end
end

function craftCountPage.cleanup()
  if craftCountPage.plan and craftCountPage.plan.craftable then
    storage.crafting.unreservePlan(craftCountPage.plan)
  end
  hook.remove("char", "craftCountChar")
  hook.remove("key", "craftCountKey")
  timer.remove("craftCountUnderscore")
  for _, elem in ipairs(craftCountPage.elems) do
    elem:remove()
  end
end
