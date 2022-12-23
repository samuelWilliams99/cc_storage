dofile("cc_storage/utils/hooks.lua")
hook.clear()

dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")
dofile("cc_storage/ui/buttonlist.lua")

storage.updateChests()
storage.updateItemMapping()
storage.startInputTimer()

sleep(1)

term.clear()

local w, h = term.getSize()

local buttonList = ui.buttonList.create()
buttonList:setSize(w, h)

local function calcOptions()
  local options = {}
  for name, item in pairs(storage.items) do
    if #options >= h then break end

    table.insert(options, {
      displayText = item.detail.displayName .. ": " .. item.count,
      name = name
    })
  end
  return options
end

function buttonList:handleClick(btn, data)
  if btn == 1 then -- left
    storage.dropItem(data.name, 64)
  elseif btn == 2 then -- right
    storage.dropItem(data.name, 1)
  end
end

hook.add("cc_storage_change", "update_view", function()
  buttonList:setOptions(calcOptions())
end)

buttonList:setOptions(calcOptions())

hook.runLoop()
