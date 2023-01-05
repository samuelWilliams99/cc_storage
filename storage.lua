require "utils.hooks"
require "utils.timer"
require "storage.items"
require "storage.crafting"
require "ui.buttonlist"
require "ui.text"
require "ui.pages.craftCount"
require "ui.pages.itemList"
require "ui.pages.lock"
require "ui.pages.pages"

storage.updateChests()
storage.updateItemMapping()
storage.crafting.loadRecipes()
storage.crafting.setupCrafters()

-- void limit - needs a menu
--   same menu as the craft up-down for things like iron

print("Rendering...")
sleep(1)

hook.add("initialize", "testing", function()
  pages.setPage("craftCount", "minecraft:wooden_sword552887824c43124013fd24f6edcde0fb")
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

storage.startInputTimer()
hook.runLoop()
