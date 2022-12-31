require "utils.hooks"
require "utils.timer"
require "storage.items"
require "storage.crafting"
require "ui.buttonlist"
require "ui.text"

storage.updateChests()
storage.updateItemMapping()
storage.crafting.loadRecipes()
storage.crafting.setupCrafters()

require "ui.pages.storage"

hook.add("initialize", "testing", function()
  -- bug errors when crafting a second sword, but not third?

  -- storage.crafting.makeAndRunPlan("minecraft:wooden_sword", 1)
end)

hook.add("terminate", "clear_screen", function()
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
