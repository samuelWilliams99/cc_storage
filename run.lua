dofile("cc_storage/utils/hooks.lua")
hook.clear()

dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")
dofile("cc_storage/ui/buttonlist.lua")
dofile("cc_storage/ui/text.lua")

storage.updateChests()
storage.updateItemMapping()
print("Rendering...")

sleep(0.5)

term.clear()

local w, h = term.getSize()
local page = 1
local pageCount = 1
local sorters = {
  {
    name = "Name",
    key = function(item) return item.detail.displayName end
  },
  {
    name = "Count",
    key = function(item) return item.count end
  }
}
local sorterIndex = 1
-- true for asc, false for desc
local order = true

local buttonList = ui.buttonList.create()
buttonList:setSize(w - 4, h - 6)
buttonList:setPos(2, 4)

local btnGap = 4

local leftBtn = ui.text.create()
leftBtn:setSize(3, 1)
leftBtn:setPos(math.floor(w / 2) - 3 - btnGap, h - 1)
leftBtn:setText("")

local rightBtn = ui.text.create()
rightBtn:setSize(3, 1)
rightBtn:setPos(math.floor(w / 2) + btnGap + 1, h - 1)
rightBtn:setText("")

local sortSwitch = ui.text.create()
sortSwitch:setPos(0, 0)
local function updateSortSwitch()
  local text = "Sort: " .. sorters[sorterIndex].name
  sortSwitch:setSize(#text, 1)
  sortSwitch:setText(text)
end
updateSortSwitch()

local orderSwitch = ui.text.create()
orderSwitch:setPos(w - 9, 0)
orderSwitch:setSize(9, 1)
local function updateOrderSwitch()
  orderSwitch:setText("Order: " .. (order and "/\\" or "\\/"))
end
updateOrderSwitch()

local pageCounter = ui.text.create()
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

-- TODO: optimise this a lot
local function updateDisplay()
  local itemKeys = table.keys(storage.items)
  local key = sorters[sorterIndex].key
  local comp = order and (function(a, b) return a < b end) or (function(a, b) return a > b end)

  -- Sort by the comparator and what not, fall back to display name asc afterwards
  table.sort(itemKeys, function(aName, bName)
    local a = storage.items[aName]
    local b = storage.items[bName]
    local aKey = key(a)
    local bKey = key(b)
    if aKey == bKey then
      return a.detail.displayName < b.detail.displayName
    else
      return comp(aKey, bKey)
    end
  end)

  local pageSize = buttonList.size.y

  pageCount = math.ceil(#itemKeys / pageSize)
  page = math.min(pageCount, page)

  local maxNameLength = math.floor(w * 0.6)
  local options = {}
  for i = (page - 1) * pageSize + 1, math.min(#itemKeys, page * pageSize) do
    local name = itemKeys[i]
    local item = storage.items[name]
    local displayNamePadded = item.detail.displayName
    if #displayNamePadded > maxNameLength then
      displayNamePadded = displayNamePadded:sub(1, maxNameLength - 3) .. "..."
    else
      displayNamePadded = displayNamePadded .. string.rep(" ", maxNameLength - #displayNamePadded)
    end

    table.insert(options, {
      displayText = displayNamePadded .. " | " .. item.count,
      name = name
    })
  end

  buttonList:setOptions(options)

  updatePageCounter()
end

function buttonList:handleClick(btn, data)
  if btn == 1 then -- left
    storage.dropItem(data.name, 1)
  elseif btn == 2 then -- right
    storage.dropItem(data.name, 64)
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
  updateSortSwitch()
  updateDisplay()
end

function orderSwitch:onClick()
  order = not order
  updateOrderSwitch()
  updateDisplay()
end

hook.add("cc_storage_change", "update_view", updateDisplay)
updateDisplay()

hook.add("mouse_scroll", "menu_shift", function(dir)
  if dir == 1 then
    rightBtn:onClick(1)
  else
    leftBtn:onClick(1)
  end
end)

storage.startInputTimer()
hook.runLoop()
