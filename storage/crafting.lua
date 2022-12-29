storage.crafting = storage.crafting or {}
dofile("cc_storage/storage/recipes.lua")

storage.crafting.crafters = {}
-- the jobQueue list is a queue of jobs to be run
storage.crafting.jobQueue = {}
-- a task is created by .craft or .craftShallow, and contains many jobs.
storage.crafting.tasks = {}

-- TODO: recipe management
-- requires "screen" support, whereby we have several screens that can be rendered and switched between
-- will also need this for the crafting UI, which atm is terrible

-- TODO (later): the scan should happen BEFORE the chest lookup, and turtles should empty the chest into their own inv before replying to the scan
-- then, on successful check, turtles should empty their inv back into the chest, and the comp should input all the items
-- this is recovery for the situations where turtles are mid craft when the computer goes down

local craftingPortOut = 1357
local craftingPortIn = craftingPortOut + 1
local modem = peripheral.wrap("back")
modem.open(craftingPortIn)

-- We specifically use os.pullEvent here as this code all runs _before_ the hook system gets enabled
-- Also, it allows us to treat these replies as syncronous calls, which makes the setup easier
-- ideally we'd use promises, but they're a little heavy for CC
local function handleAllReplies(handler, ids)
  local timerID = os.startTimer(1)
  local remaining = table.shallowCopy(ids or {})
  while true do
    local data = {os.pullEvent()}
    if data[1] == "modem_message" and data[3] == craftingPortIn then
      handler(data[5])
      if ids then
        table.removeByValue(remaining, data.computerID)
        if table.isEmpty(remaining) then break end
      end
    elseif data[1] == "timer" and data[2] == timerID then
      break
    end
  end
  os.cancelTimer(timerID)
end

local function checkChests(chests, itemName, lastChest)
  storage.crafting.crafters = {}
  for i = #chests, 1, -1 do
    local chest = chests[i]
    lastChest.pushItems(peripheral.getName(chest), 1, 1, 1)
    lastChest = chest
    modem.transmit(craftingPortOut, craftingPortIn, {type = "check", name = itemName})
    handleAllReplies(function(data)
      if data.found then
        storage.crafting.crafters[data.computerID] = {computerID = data.computerID, chest = chest}
        table.remove(chests, i)
      end
    end, storage.crafting.crafterIDs)
  end
  storage.inputChest(lastChest)
end

function storage.crafting.setupCrafters()
  print("Locating crafters")
  local chests = storage.crafting.candidates or {}

  os.startTimer(1)
  modem.transmit(craftingPortOut, craftingPortIn, {type = "scan"})
  storage.crafting.crafterIDs = {}

  handleAllReplies(function(data)
    local compID = data.computerID
    table.insert(storage.crafting.crafterIDs, compID)
  end)

  print("Found " .. #storage.crafting.crafterIDs .. " crafting turtles, locating chests...")

  if table.isEmpty(storage.items) then error("Please place at least 1 item in one of the chests to initialise the system") end
  local firstItemName, item = next(storage.items)

  storage.dropItemTo(firstItemName, 1, storage.input)

  checkChests(chests, item.detail.name, storage.input)
  print("Found chests for " .. table.count(storage.crafting.crafters) .. " crafting turtles and registered them.")

  print(#chests .. " crafting chest candidates turned out to be normal chests.")
  for _, chest in pairs(chests) do
    storage.addEmptyChest(chest)
  end
end

--[[
structure:
plan = {
  -- Inner lists are crafts that can happen together, handle with a forloop
  -- outer lists MUST happen after eachother, so iterate once _all_ crafts in the previous list are complete
  -- technically some nodes could be unblocked before the previous step completes, however single crafts take like 1 second, so it'd at max waste that much time
  -- This is not provided if items are missing
  -- total ingredients it would use to create (including any missing), if a recipe is uncraftable, this will be greater than what we have in storage
  ingredients: { [itemName]: count }
  missingItems?: { [itemName]: count }
  craftable: bool
  -- below both needed for unreserving
  craftedItems: { [itemName]: count }
}

ABORT
this doesnt work
say im making an iron sword, it'll wait for the iron to smelt before crafting the sticks - no

do opportunistic crafting, and think about prioritisation later
so, we make a DAG with one node per item
  each element stores a list of "parents", which is to the say the items to be crafted
finally, we get a list of leaves, which are the ingredients
next we need the first crafts, which are all the parents of those leaves that don't have any other children - or, those where we have enough of all child elements
  we will keep a mapping of items in the craft - including initial ingredients then also intermediates made
we set these crafting
whenever any of them finish, we look at its parents
  filter out any that we can't craft yet (so children aren't satisfied)
  trigger all the jobs we can (depending on how many items were complete) - given smelting is like 1 (possible more if more furnaces) at a time, and crafting is up to 64
    for now, this is ordered arbitrarily, we will add prioritisation here later
  rince and repeat

also, the `table.remove(jobs, 1)` part in the craft complete handler can be any index, as there is no order in queued jobs
  so we can run a prioritisation step there too


prioritisation - 2 metrics
  doing long jobs first - anything that uses a furnace or non crafter should be done first, and any predicates (direct or non direct) should take priority
  avoiding small repeat jobs - if we can avoid doing, say: 1x, some y, 1x, some y, 1x ... and instead do some y, some y, some y, 3x - we save crafting time
    this is to say, jobs that _arent_ holding us up, that have slow ingredient crafting, should wait until all their ingredients are ready (or there are no other jobs) before running
      -> or at the very least, these are low priority
  we may see this as 2 scores
    one is a time score put on everything
    and the other is a "completeness" score, as a "number i can craft now / total number i'll need to craft"
    higher the better on both, but time is more important



]]

-- Creates a crafting plan for an item recursively.
-- Useful fields for the UI include
-- plan.craftable = boolean -- is the plan executable
-- plan.ingredients = {[itemName] = count}
-- plan.missingIngredients = {[itemName] = count} -- empty if craftable
-- recommended to call reserve plan directly afterwards
function storage.crafting.makeCraftPlan(itemName, count)
  -- wrapper function so VScode doesn't see the `plan` and `parent` argument
  local plan = {
    nodes = {},
    leaves = {},
    ingredients = {},
    missingIngredients = {},
    craftedItems = {},
    craftable = true
  }
  storage.crafting.makeCraftPlanAux(itemName, count, plan)
  plan.leaves = table.keys(plan.leaves)
  plan.craftedItems[itemName] = (plan.craftedItems[itemName] or 0) + count
  return plan
end

function storage.crafting.makeCraftPlanAux(itemName, count, plan, parent)
  local isRoot = not parent

  local recipe = storage.crafting.recipes[itemName]

  local hadCraftedItems = not not plan.craftedItems[itemName]

  if hadCraftedItems then
    local amountToUse = math.min(plan.craftedItems[itemName], count)
    plan.craftedItems[itemName] = plan.craftedItems[itemName] - amountToUse
    if plan.craftedItems[itemName] == 0 then plan.craftedItems[itemName] = nil end
    count = count - amountToUse

    -- If an item is in craftedItems, there is definitely a node for it
    -- We can also assume we'll have a parent, as craftedItems will be empty in the isRoot call
    local node = plan.nodes[itemName]
    table.insert(node.parents, parent)
    plan.leaves[parent.itemName] = nil
  end

  if not isRoot then
    local item = storage.items[itemName]
    local amountUsed = plan.ingredients[itemName] or 0
    local amountInStorage = item and item.count or 0
    local amountLeft = amountInStorage - amountUsed

    local amountToUse = math.min(count, amountLeft)
    if amountToUse > 0 then
      count = count - amountToUse
      plan.ingredients[itemName] = amountUsed + amountToUse
    end
  end

  if count == 0 then return end

  if not recipe then
    plan.craftable = false
    plan.missingIngredients[itemName] = (plan.missingIngredients[itemName] or 0) + count
    plan.ingredients[itemName] = (plan.ingredients[itemName] or 0) + count
    return
  end

  -- We have a recipe
  local craftCount = math.ceil(count / recipe.count)
  local excessItems = craftCount * recipe.count - count
  if excessItems > 0 then
    plan.craftedItems[itemName] = (plan.craftedItems[itemName] or 0) + excessItems
  end

  local node = plan.nodes[itemName]
  if not node then
    node = {
      parents = {},
      count = craftCount,
      isRoot = isRoot,
      itemName = itemName
    }
    plan.nodes[itemName] = node
    plan.leaves[itemName] = true
  end

  if not isRoot and not hadCraftedItems then
    table.insert(node.parents, parent)
    plan.leaves[parent.itemName] = nil
  end

  for ingredientName, ingredientCount in pairs(recipe.ingredients) do
    storage.crafting.makeCraftPlanAux(ingredientName, ingredientCount * craftCount, plan, node)
  end
end

function storage.crafting.reservePlan(plan)
  if not plan.craftable then return end
  for itemName, count in pairs(plan.ingredients) do
    storage.reserveItems(itemName, count)
  end
end

function storage.crafting.unreservePlan(plan)
  if not plan.craftable then return end
  for itemName, count in pairs(plan.ingredients) do
    storage.unreserveItems(itemName, count)
  end
end

function storage.crafting.runPlan(plan, cb)
  if not plan.craftable then return false, "Uncraftable plan" end


end

-- Calculates the max of this item that a crafter can craft
function storage.crafting.getMaxPerCrafter(recipe)
  local minStack = 64
  for itemName, count in pairs(recipe.ingredients) do
    local item = storage.items[itemName]
    if not item then return end
    local maxStackForIngredient = math.floor(item.detail.maxCount / count)
    if maxStackForIngredient < minStack then
      minStack = maxStackForIngredient
    end
  end
  return minStack
end

-- Crafts an item, parallelising if needed, taking a callback for when finished, as well as a flag for using reserved items (likely always true?)
-- returns `true, errMessage` or `false, jobCount` based on if possible
-- Shallow - as does not attempt to craft any missing ingredients
function storage.crafting.craftShallow(itemName, craftCount, cb, useReserved)
  if craftCount == 0 then return false, "Cannot craft 0" end
  local recipe = storage.crafting.recipes[itemName]
  if not recipe then return false, "No recipe for " .. itemName end
  local maxCraftsPerCrafter = storage.crafting.getMaxPerCrafter(recipe)
  if not maxCraftsPerCrafter then return false, "Not enough ingredients to craft this many items" end

  -- Given we cannot assume maxCraftsPerCrafter fits into craftCount integer times, we do `repeatedCraftCount` jobs of maxCraftsPerCrafter crafts, alongside a "change" job
  -- this is the number of JOBs
  local repeatedJobCount = math.floor(craftCount / maxCraftsPerCrafter)
  -- this is the number of crafts for the change `job`
  local changeCount = craftCount - repeatedJobCount * maxCraftsPerCrafter

  local task = storage.crafting.addTask(cb)

  for i = 1, repeatedJobCount do
    storage.crafting.addCraftToQueue(recipe, maxCraftsPerCrafter, task, useReserved)
  end
  if changeCount > 0 then
    storage.crafting.addCraftToQueue(recipe, changeCount, task, useReserved)
  end
  return true, math.ceil(craftCount / maxCraftsPerCrafter)
end

function storage.crafting.addTask(cb)
  local task = {
    cb = cb,
    jobs = {}
  }
  table.insert(storage.crafting.tasks, task)
  return task
end

-- find an inactive crafter, start its craft loop with this job
-- if none, add to the crafting queue and do nothing
function storage.crafting.addCraftToQueue(recipe, craftCount, task, useReserved)
  local job = {
    recipe = recipe,
    craftCount = craftCount,
    task = task,
    useReserved = useReserved
  }
  table.insert(task.jobs, job)

  local crafter = storage.crafting.findInactiveCrafter()
  if crafter then
    storage.crafting.runCrafter(job, crafter)
  else
    table.insert(storage.crafting.jobQueue, job)
  end
end

function storage.crafting.findInactiveCrafter()
  for _, crafter in pairs(storage.crafting.crafters) do
    if not crafter.activeJob then return crafter end
  end
end

function storage.crafting.runCrafter(job, crafter)
  crafter.activeJob = job

  local msg = {
    type = "craft",
    craftCount = job.craftCount,
    placement = job.recipe.placement,
    computerID = crafter.computerID
  }

  for name, amt in pairs(job.recipe.ingredients) do
    storage.dropItemTo(name, amt * job.craftCount, crafter.chest, job.useReserved)
  end
  modem.transmit(craftingPortOut, craftingPortIn, msg)
end

hook.add("modem_message", "crafting_reply", function(_, port, _, data)
  if port ~= craftingPortIn then return end
  if data.type ~= "craft" then return end

  local crafter = storage.crafting.crafters[data.computerID]
  if not crafter then return end -- Not a crafter we know about
  storage.inputChest(crafter.chest, true)

  -- Job completion logic
  local job = crafter.activeJob
  if job then
    table.removeByValue(job.task.jobs, job)
    if table.isEmpty(job.task.jobs) then
      if job.task.cb then job.task.cb() end
      table.removeByValue(storage.crafting.tasks, job.task)
    end
  end

  if table.isEmpty(storage.crafting.jobQueue) then
    crafter.activeJob = nil
  else
    local nextJob = table.remove(storage.crafting.jobQueue, 1)
    storage.crafting.runCrafter(nextJob, crafter)
  end
end)
