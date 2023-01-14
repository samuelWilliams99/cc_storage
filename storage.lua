require "utils.hooks"
require "utils.timer"
require "storage.items"
require "storage.crafting"
require "storage.enderChest"
require "ui.buttonList"
require "ui.text"
require "ui.pages.configure"
require "ui.pages.craftCount"
require "ui.pages.itemList"
require "ui.pages.lock"
require "ui.pages.recipes"
require "ui.pages.enderChest"
require "ui.pages.pages"

storage.crafting.pingCrafters()
storage.updateChests()
storage.updateItemMapping()
storage.crafting.loadRecipes()
storage.crafting.setupCrafters()
storage.enderChest.setup()

-- void limit - needs a menu
--   same menu as the craft up-down for things like iron

print("Rendering...")
sleep(1)

hook.add("initialize", "testing", function()
  if storage.lockPageEnabled then
    pages.setPage("lock")
  else
    pages.setPage("itemList")
  end
end)

hook.add("terminate", "clear_screen", function()
  if pages.pages.lock.active then return end
  term.clear()
  term.setCursorPos(1,1)
end)

hook.setPreError(function(event, handlerName, err, stack)
  term.clear()
  term.setCursorPos(1,1)
  print("CC_Storage terminated - the following error occured and has been written to logs.txt:")
  print("(Just reboot the computer and let Sam know so he can take a look)")
  local logs = readFile("logs.txt") or {}
  table.insert(logs, {time = os.date(), event = event, handlerName = handlerName, err = err, stack = stack})
  writeFile("logs.txt", logs)
end)

storage.startLockTimer()
storage.enderChest.startInputTimer()
storage.startInputTimer()
hook.runLoop()
