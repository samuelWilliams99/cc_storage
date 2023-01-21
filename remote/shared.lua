storage.remote = {}
storage.remote.funcChannel = 12394
storage.remote.hookChannel = 12395

storage.modem.open(storage.remote.funcChannel)
storage.modem.open(storage.remote.hookChannel)

-- TODO: need computer ids, store in settings
-- Have thing to request all cc_storage computer ids
-- put in list, select one and store in settings

local sharedFuncs = {
  -- Items
  "storage.getTotalSlotCount",
  -- Ender chest
  "storage.enderChest.dropItem",
  "storage.enderChest.pauseChest",
  "storage.enderChest.unpauseChest",
  "storage.enderChest.itemPauseChest",
  "storage.enderChest.getChestNames",
  "storage.enderChest.chestExists",
  -- Lock
  "storage.lock.getOnlinePlayers",
  "storage.lock.getAuthorisedPlayers",
  "storage.lock.authorisePlayer",
  "storage.lock.unauthorisePlayer",
  "storage.lock.setEnabled",
  "storage.lock.getEnabled",
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
  "storage.crafting.getRecipeNames",
  "storage.crafting.getPlacementFromInventory",
  "storage.crafting.getCraftedItemFromInventory",
  -- Remote
  "storage.remote.getItems"
}

local forwardedHooks = {
  "cc_lock_authorised_players_change",
  "cc_lock_enabled_change",
  "cc_recipes_change",
  "cc_enderchest_change",
  "cc_storage_change_item_batched",
  "cc_crafting_plan_change",
}

storage.remote.isRemote = pocket and true or false

if storage.remote.isRemote then
  require "remote.client"
else
  require "remote.server"
end

function storage.remote.sharedFunction(functionStr)
  local names = {}
  for name in string.gmatch(functionStr, "([^\\.]+)") do
    table.insert(names, name)
  end
  if storage.remote.isRemote then
    storage.remote.sharedFunctionClient(names, functionStr)
  else
    storage.remote.sharedFunctionServer(names, functionStr)
  end
end

function storage.remote.registerFunctions()
  for _, func in ipairs(sharedFuncs) do
    storage.remote.sharedFunction(func)
  end
  if not storage.remote.isRemote then
    for _, hookName in ipairs(forwardedHooks) do
      storage.remote.sharedHookServer(hookName)
    end
  end
end

-- TODO: we also now need to consider concurrency, ensure all functions fail gracefully if acting on out of date data

-- TODO: write a client side function for querying all _active_ computer ids, so those that are fully setup and ready
-- On startup, query this. If we dont have an ID set, go to the remote page. Said page should have a refresh button
-- If we do have an ID, and its in this list, continue as normal (unless no chest set ofc)
-- if its not in the list, create a new "pinging" page, which pings the above endpoint every 5s until it replies, and has a button to go to the config page
