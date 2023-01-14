require "ui.pages.pages"

local storagePage = {}

pages.addPage("itemList", storagePage)

function storagePage.setup()
  local hasCrafters = not table.isEmpty(storage.crafting.crafters)

  term.clear()

  local w, h = term.getSize()
  local page = 1
  local pageCount = 1
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

  local buttonList = pages.elem(ui.buttonList.create())
  buttonList:setSize(w - 4, h - 6)
  buttonList:setPos(2, 4)
  buttonList:setSplits(0.65)

  local btnGap = 4

  local leftBtn = pages.elem(ui.text.create())
  leftBtn:setSize(3, 1)
  leftBtn:setPos(math.floor(w / 2) - 3 - btnGap, h - 1)
  leftBtn:setText("")

  local rightBtn = pages.elem(ui.text.create())
  rightBtn:setSize(3, 1)
  rightBtn:setPos(math.floor(w / 2) + btnGap + 1, h - 1)
  rightBtn:setText("")

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

  local slotCounter = pages.elem(ui.text.create())
  slotCounter:setBgColor(colors.black)
  local function updateSlotCounter()
    local slotsUsed = storage.totalSlotCount - #storage.emptySlots
    local str = slotsUsed .. "/" .. storage.totalSlotCount .. " slots used"
    slotCounter:setPos(w - #str, h - 1)
    slotCounter:setSize(#str, 1)
    slotCounter:setText(str)
  end
  updateSlotCounter()

  local pageCounter = pages.elem(ui.text.create())
  local function updatePageCounter()
    local pageCountStr = tostring(pageCount)
    local pageStr = tostring(page)
    pageStr = string.rep(" ", #pageCountStr - #pageStr) .. pageStr
    local pageCounterStr = pageStr .. "/" .. pageCountStr

    pageCounter:setSize(#pageCounterStr, 1)
    pageCounter:setPos(math.floor(w / 2) - #pageStr, h - 1)
    pageCounter:setText(pageCounterStr)

    leftBtn:setText(page == 1 and "" or "<<<")
    leftBtn:setBgColor(page == 1 and colors.black or colors.gray)
    rightBtn:setText(page == pageCount and "" or ">>>")
    rightBtn:setBgColor(page == pageCount and colors.black or colors.gray)
  end

  updatePageCounter()

  local configureButton = pages.elem(ui.text.create())
  configureButton:setPos(0, h - 1)
  configureButton:setSize(9, 1)
  configureButton:setText("Configure")
  function configureButton:onClick()
    pages.setPage("configure")
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

  -- TODO: optimise this a lot
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

    local function getItemData(name)
      if storage.items[name] then return storage.items[name] end
      local recipe = storage.crafting.recipes[name]
      return {detail = {displayName = recipe.displayName}, count = 0, isRecipe = true}
    end

    itemKeys = table.filter(itemKeys, function(name)
      if storage.items[name] and storage.items[name].count == 0 then return false end
      if searchString == "" then return true end
      local itemData = getItemData(name)
      return itemData.detail.displayName:lower():find(searchString)
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

    local pageSize = buttonList.size.y - 1

    pageCount = math.max(1, math.ceil(#itemKeys / pageSize))
    page = math.min(pageCount, page)

    local options = {{displayText = {"ITEM NAME", "COUNT"}}}
    for i = (page - 1) * pageSize + 1, math.min(#itemKeys, page * pageSize) do
      local name = itemKeys[i]
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

      table.insert(options, {
        displayText = {displayName, countText},
        name = name,
        maxCount = item.detail.maxCount -- Will be nil for non craftables
      })
    end

    buttonList:setOptions(options)

    updatePageCounter()
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

  function leftBtn:onClick()
    if page == 1 then return end
    page = page - 1
    updateDisplay()
  end

  function rightBtn:onClick()
    if page == pageCount then return end
    page = page + 1
    updateDisplay()
  end

  function sortSwitch:onClick()
    sorterIndex = (sorterIndex % #sorters) + 1
    order = sorters[sorterIndex].order
    page = 1
    updateSortSwitch()
    updateOrderSwitch()
    updateDisplay()
  end

  function orderSwitch:onClick()
    order = not order
    page = 1
    updateOrderSwitch()
    updateDisplay()
  end

  updateDisplay()

  hook.add("cc_storage_change", "update_view", function()
    timer.create("inventory_delay", 0.1, 1, updateDisplay)
  end)

  hook.add("mouse_scroll", "menu_shift", function(dir)
    if dir == 1 then
      rightBtn:onClick()
    else
      leftBtn:onClick()
    end
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
  hook.remove("mouse_scroll", "menu_shift")
  hook.remove("mouse_click", "clear_search")
  timer.remove("inventory_delay")

  timer.remove("idle_clear_search")
  hook.remove("key", "idle_clear_search")
  hook.remove("mouse_click", "idle_clear_search")
  hook.remove("mouse_scroll", "idle_clear_search")
end
