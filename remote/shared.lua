storage.remote = {}
storage.remote.funcChannel = 12394
storage.remote.hookChannel = 12395

if storage.wirelessModem then
  storage.wirelessModem.open(storage.remote.funcChannel)
  storage.wirelessModem.open(storage.remote.hookChannel)
else
  print("No wireless modem found, pocket terminals cannot be used")
end

local sharedFuncs = {
  -- Items
  "storage.getTotalSlotCount",
  "storage.getItemCount",
  "storage.getDefragSummary",
  -- Ender chest
  "storage.enderChest.dropItem",
  "storage.enderChest.pauseChest",
  "storage.enderChest.unpauseChest",
  "storage.enderChest.setChestPaused",
  "storage.enderChest.itemPauseChest",
  "storage.enderChest.getChestNames",
  "storage.enderChest.chestExists",
  "storage.enderChest.isChestPaused",
  "storage.enderChest.obtainTurtleLock",
  "storage.enderChest.releaseTurtleLock",
  -- Lock
  "storage.lock.getOnlinePlayers",
  "storage.lock.getAuthorisedPlayers",
  "storage.lock.authorisePlayer",
  "storage.lock.unauthorisePlayer",
  "storage.lock.setEnabled",
  "storage.lock.getEnabled",
  "storage.lock.hasDetector",
  -- Crafting
  "storage.crafting.unreservePlan",
  "storage.crafting.runPlan",
  "storage.crafting.makeCraftPlan",
  "storage.crafting.hasCrafters",
  "storage.crafting.getActivePlanCount",
  -- Recipes
  "storage.crafting.getRecipe",
  "storage.crafting.addRecipe",
  "storage.crafting.removeRecipe",
  "storage.crafting.getRecipeDisplayNamesAndMods",
  "storage.crafting.getPlacementFromInventory",
  "storage.crafting.getCraftedItemFromInventory",
  "storage.crafting.hasDropper",
  -- Remote
  "storage.remote.getItems",
  "storage.remote.getStorageId",
  -- Burn items
  "storage.burnItems.getItemSetting",
  "storage.burnItems.getItemSettings",
  "storage.burnItems.setItemLimit",
  "storage.burnItems.getNextBurnTime",
  "storage.burnItems.getBurnSlotsUsed",
  "storage.burnItems.getMaxBurnSlots",
  "storage.burnItems.burnAllOfItem",
  "storage.burnItems.reclaimItems",
  "storage.burnItems.burnChestNow",
  "storage.burnItems.isDisabled",
  -- Util
  "printMon"
}

-- These functions are to be called only by clients, and will provide the client computer id as the first argument
local sharedFuncsClientOnly = {
  "storage.remote.transmitConnected",
  "storage.remote.transmitPing",
  "storage.remote.transmitDisconnected",
}

local forwardedHooks = {
  "cc_lock_authorised_players_change",
  "cc_lock_enabled_change",
  "cc_recipes_change",
  "cc_enderchest_change",
  "cc_storage_change_item_batched",
  "cc_crafting_plan_change",
  "cc_initialize",
  "cc_burn_items_setting_change",
  "cc_burn_items_settings_change",
  "cc_burn_items_next_burn_time",
  "cc_burn_items_slots_change",
}

storage.remote.isRemote = pocket and true or false

if storage.remote.isRemote then
  require "remote.client"
else
  require "remote.server"
end

function storage.remote.sharedFunction(functionStr, giveClientId)
  local names = {}
  for name in string.gmatch(functionStr, "([^\\.]+)") do
    table.insert(names, name)
  end
  if storage.remote.isRemote then
    storage.remote.sharedFunctionClient(names, functionStr)
  else
    storage.remote.sharedFunctionServer(names, functionStr, giveClientId)
  end
end

function storage.remote.registerFunctions()
  for _, func in ipairs(sharedFuncs) do
    storage.remote.sharedFunction(func)
  end
  for _, func in ipairs(sharedFuncsClientOnly) do
    storage.remote.sharedFunction(func, true)
  end
  if not storage.remote.isRemote then
    for _, hookName in ipairs(forwardedHooks) do
      storage.remote.sharedHookServer(hookName)
    end
  end
end
