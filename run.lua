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

local buttonList = ui.buttonList.create()
local page = 1
local pageCount = 1
buttonList:setSize(w - 4, h - 4)
buttonList:setPos(2, 2)

local btnGap = 4

local leftBtn = ui.text.create()
leftBtn:setSize(3, 1)
leftBtn:setPos(math.floor(w / 2) - 3 - btnGap, h - 1)
leftBtn:setText("")

local rightBtn = ui.text.create()
rightBtn:setSize(3, 1)
rightBtn:setPos(math.floor(w / 2) + btnGap + 1, h - 1)
rightBtn:setText("")

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
  rightBtn:setText(page == pageCount and "" or ">>>")
end

updatePageCounter()

-- TODO: optimise this a lot
local function updateDisplay()
  local itemKeys = table.keys(storage.items)
  table.sort(itemKeys, function(a, b) return storage.items[a].detail.displayName < storage.items[b].detail.displayName end)
  local pageSize = buttonList.size.y

  pageCount = math.ceil(#itemKeys / pageSize)
  page = math.min(pageCount, page)

  local options = {}
  for i = (page - 1) * pageSize + 1, math.min(#itemKeys, page * pageSize) do
    local name = itemKeys[i]
    local item = storage.items[name]

    table.insert(options, {
      displayText = item.detail.displayName .. ": " .. item.count,
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

hook.add("cc_storage_change", "update_view", updateDisplay)
updateDisplay()

storage.startInputTimer()
hook.runLoop()
