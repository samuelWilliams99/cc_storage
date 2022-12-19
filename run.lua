dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")
dofile("cc_storage/ui/button.lua")

storage.updateChests()
storage.updateItemMapping()
storage.startInputTimer()

sleep(1)

local button = ui.button.create()
button:setPos(4, 4)
button:setSize(1, 10)
button:setText("Click me!")
function button:onClick()
  self:SetTextColor(colors.green)
  self:setText("Clicked :0")
end

ui.drawAll()

hook.runLoop()
