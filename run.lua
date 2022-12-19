dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")
dofile("cc_storage/ui/button.lua")

print(textutils.serialise(hook))

storage.updateChests()
storage.updateItemMapping()
storage.startInputTimer()

sleep(1)

term.clear()
local button = ui.button.create()
button:setPos(4, 4)
button:setSize(20, 1)
button:setText("Click me!")
function button:onClick()
  self:SetTextColor(colors.green)
  self:setText("Clicked :0")
end

hook.runLoop()
