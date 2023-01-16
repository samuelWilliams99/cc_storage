require "ui.pages.pages"

local storagePage = {}

pages.addPage("itemList", storagePage)

function storagePage.setup()
  local hasCrafters = not table.isEmpty(storage.crafting.crafters)

  term.clear()

  local w, h = term.getSize()
  local sorters = {
    {
      name = "Name",
      key = function(item) return item.detail.displayName end,
      order = true
    },
    {
      name = "Count",
      key = function(item) return item.count end,
      order = false
    }
  }
  local sorterIndex = 1
  -- true for asc, false for desc
  local order = true
  local searchString = ""

  local function getItemData(name)
    if storage.items[name] then return storage.items[name] end
    local recipe = storage.crafting.recipes[name]
    return {detail = {displayName = recipe.displayName}, count = 0, isRecipe = true}
  end

  local function getCountText(count, maxCount)
    if maxCount == 1 or count <= maxCount then return tostring(count) end
    local stacks = math.floor(count / maxCount)
    local str = tostring(count) .. " (" .. stacks .. " * " .. maxCount
    local remainder = count % maxCount
    if remainder > 0 then
      str = str .. " + " .. remainder
    end
    return str .. ")"
  end

  local buttonList = pages.elem(ui.buttonListPaged.create())
  buttonList:setSize(w - 4, h - 4)
  buttonList:setPos(2, 4)
  buttonList:setSplits(0.65)
  buttonList:setHeader({"ITEM NAME", "COUNT"})
  buttonList:setAllowPageHide(false)
  function buttonList:preProcess(name)
    local item = getItemData(name)
    local displayName = item.detail.displayName

    if item.detail.damage then
      displayName = displayName .. " (" .. (item.detail.maxDamage - item.detail.damage) .. "/" .. item.detail.maxDamage .. ")"
    end
    if item.detail.enchantments then
      if #item.detail.enchantments == 1 then
        displayName = displayName .. " (" .. item.detail.enchantments[1].displayName .. ")"
      else
        displayName = displayName .. " (+ " .. #item.detail.enchantments .. " enchantments)"
      end
    end

    local countText = item.isRecipe and "CRAFT" or getCountText(item.count, item.detail.maxCount)
    if not item.isRecipe and storage.crafting.recipes[name] and hasCrafters then -- If we have some but its also craftable
      countText = countText .. " *" -- Add a star :)
    end

    return {
      displayText = {displayName, countText},
      name = name,
      maxCount = item.detail.maxCount -- Will be nil for non craftables
    }
  end

  local sortSwitch = pages.elem(ui.text.create())
  sortSwitch:setPos(0, 0)

  -- Get correct size
  do
    local maxLength = 0
    for _, sorter in ipairs(sorters) do
      maxLength = math.max(maxLength, #sorter.name)
    end
    sortSwitch:setSize(6 + maxLength, 1)
  end

  local function updateSortSwitch()
    sortSwitch:setText("Sort: " .. sorters[sorterIndex].name)
  end
  updateSortSwitch()

  local orderSwitch = pages.elem(ui.text.create())
  orderSwitch:setPos(w - 9, 0)
  orderSwitch:setSize(9, 1)
  local function updateOrderSwitch()
    orderSwitch:setText("Order: " .. (order and "/\\" or "\\/"))
  end
  updateOrderSwitch()

  local craftingCounter = pages.elem(ui.text.create())
  craftingCounter:setBgColor(colors.black)
  local function updateCraftingCounter()
    if table.isEmpty(storage.crafting.plans) then
      craftingCounter:setTextColor(colors.black)
    else
      craftingCounter:setTextColor(colors.white)
    end
    local text = #storage.crafting.plans .. " Crafting job active"
    craftingCounter:setPos(w - 11 - #text, 0)
    craftingCounter:setSize(#text, 1)
    craftingCounter:setText(text)
  end
  updateCraftingCounter()

  -- TODO: the next 2 are now indented from the left/right by 2, because they're in the item list.
  -- Consider implementing a noBackgroundClear option, and moving them out of it
  -- However, this will cause order issues with onClick, we may need to change that to handle _all_ elements that overlap the mouse
  -- so drop the break at base.lua:120
  local slotCounter = ui.text.create(buttonList)
  slotCounter:setBgColor(colors.black)
  local function updateSlotCounter()
    local slotsUsed = storage.totalSlotCount - #storage.emptySlots
    local str = slotsUsed .. "/" .. storage.totalSlotCount .. " slots used"
    slotCounter:setPos(buttonList.size.x - #str, buttonList.size.y - 1)
    slotCounter:setSize(#str, 1)
    slotCounter:setText(str)
  end
  updateSlotCounter()

  local configureButton = ui.text.create(buttonList)
  configureButton:setPos(0, buttonList.size.y - 1)
  configureButton:setSize(9, 1)
  configureButton:setText("Configure")
  function configureButton:onClick()
    pages.setPage("configure")
  end

  -- TODO: optimise this a lot
  -- At very least, keys + recipe adding, as well as filter, can all be one loop, rather than 3
  -- Consider if its possible to not recreate the ensure list each time, but instead update it as needed
  local function updateDisplay()
    if not storagePage.active then return end
    local itemKeys = table.keys(storage.items)

    if hasCrafters then
      for name in pairs(storage.crafting.recipes) do
        if not storage.items[name] then
          table.insert(itemKeys, name)
        end
      end
    end

    itemKeys = table.filter(itemKeys, function(name)
      if storage.items[name] and storage.items[name].count == 0 then return false end
      if searchString == "" then return true end
      local itemData = getItemData(name)
      return itemData.detail.displayName:lower():find(searchString, nil, true)
    end)

    local key = sorters[sorterIndex].key
    local comp = order and (function(a, b) return a < b end) or (function(a, b) return a > b end)

    -- Sort by the comparator and what not, fall back to display name asc afterwards
    table.sort(itemKeys, function(aName, bName)
      local a = getItemData(aName)
      local b = getItemData(bName)
      local aKey = key(a)
      local bKey = key(b)
      if aKey == bKey then
        return a.detail.displayName < b.detail.displayName
      else
        return comp(aKey, bKey)
      end
    end)

    buttonList:setOptions(itemKeys)

    updateSlotCounter()
    updateCraftingCounter()
  end

  function buttonList:handleClick(btn, data)
    if not data.name then return end

    local canCraft = storage.crafting.recipes[data.name] and hasCrafters

    if canCraft and (btn == 3 or not storage.items[data.name]) then
      pages.setPage("craftCount", data.name)
    elseif btn == 2 then
      storage.dropItem(data.name, data.maxCount)
    elseif btn == 1 then
      storage.dropItem(data.name, 1)
    end
  end

  function sortSwitch:onClick()
    sorterIndex = (sorterIndex % #sorters) + 1
    order = sorters[sorterIndex].order
    buttonList:setPage(1, true)
    updateSortSwitch()
    updateOrderSwitch()
    updateDisplay()
  end

  function orderSwitch:onClick()
    order = not order
    buttonList:setPage(1, true)
    updateOrderSwitch()
    updateDisplay()
  end

  updateDisplay()

  hook.add("cc_storage_change", "update_view", function()
    timer.create("inventory_delay", 0.1, 1, updateDisplay)
  end)

  hook.add("mouse_click", "clear_search", function(btn, x, y)
    if y == 3 and btn == 2 then
      hook.run("key", 257, false)
    end
  end)

  local function idleClear()
    timer.create("idle_clear_search", 20, 1, function()
      hook.run("key", 257, false)
    end)
  end

  hook.add("key", "idle_clear_search", idleClear)
  hook.add("mouse_click", "idle_clear_search", idleClear)
  hook.add("mouse_scroll", "idle_clear_search", idleClear)

  -- what to do about this...
  hook.runInHandlerContext(function()
    while storagePage.active do
      term.setCursorPos(3, 3)
      term.clearLine()
      term.write("Search: ")
      read(nil, nil, function(str)
        searchString = str:lower()
        updateDisplay()
        return {}
      end)
      searchString = ""
      updateDisplay()
    end
  end)
end

function storagePage.cleanup()
  hook.run("key", 257, false)

  hook.remove("cc_storage_change", "update_view")
  hook.remove("mouse_click", "clear_search")
  timer.remove("inventory_delay")

  timer.remove("idle_clear_search")
  hook.remove("key", "idle_clear_search")
  hook.remove("mouse_click", "idle_clear_search")
  hook.remove("mouse_scroll", "idle_clear_search")
end
