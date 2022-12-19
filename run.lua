dofile("cc_storage/utils/hooks.lua")
hook.clear()

dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")
dofile("cc_storage/ui/button.lua")

storage.updateChests()
storage.updateItemMapping()
storage.startInputTimer()

sleep(1)

term.clear()

local counter = 0
for name, item in pairs(storage.items) do
  counter = counter + 1
  if counter > 30 then break end

  local button = ui.button.create()
  button:setPos(2, counter)
  button:setSize(80, 1)
  button:setText(item.detail.displayName .. ": " .. item.count)
  button:setBgColor(counter % 2 == 0 and colors.gray or colors.black)
  function button:onClick()
    if item.count == 0 then return end
    storage.dropItem(name, 1)
    button:setText(item.detail.displayName .. ": " .. item.count)
  end
end

hook.runLoop()
