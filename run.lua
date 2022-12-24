dofile("cc_storage/utils/hooks.lua")
hook.clear()

dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")
dofile("cc_storage/ui/buttonlist.lua")

storage.updateChests()
storage.updateItemMapping()
print("Rendering...")

sleep(0.5)

term.clear()

local w, h = term.getSize()

local buttonList = ui.buttonList.create()
buttonList:setSize(w - 4, h - 4)
buttonList:setPos(2, 2)

local function calcOptions()
  local options = {}
  for name, item in pairs(storage.items) do
    if #options >= buttonList.size.y then break end

    table.insert(options, {
      displayText = item.detail.displayName .. ": " .. item.count,
      name = name
    })
  end
  return options
end

function buttonList:handleClick(btn, data)
  if btn == 1 then -- left
    storage.dropItem(data.name, 1)
  elseif btn == 2 then -- right
    storage.dropItem(data.name, 64)
  end
end

hook.add("cc_storage_change", "update_view", function()
  buttonList:setOptions(calcOptions())
end)

buttonList:setOptions(calcOptions())

storage.startInputTimer()
hook.runLoop()
