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
  -- bug - crafted items showing as 0
  -- might be an issue with adding new items directly to reserved
  -- though just crafting sticks directly is fine?

  -- wood sword just isnt in the menu (other than the one made)
  -- also terminate should clear the screens
  -- storage.crafting.makeAndRunPlan("minecraft:wooden_sword", 1)
end)

hook.add("terminate", "clear_screen", function()
  term.clear()
  term.setCursorPos(1,1)
end)

storage.startInputTimer()
hook.runLoop()
