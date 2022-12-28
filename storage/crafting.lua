storage.crafting = storage.crafting or {}
dofile("cc_storage/storage/recipes.lua")

storage.crafting.crafters = {}
-- the jobQueue list is a queue of jobs to be run
storage.crafting.jobQueue = {}
-- a task is created by .craft or .craftShallow, and contains many jobs.
storage.crafting.tasks = {}

-- TODO: deep crafting
-- Make a function that creates a crafting plan AND reserves all the materials it intends to use.
--   This should take the item we want and the amount we want to make
--   The plan should include an easy to display index of all materials needed
--   Note - if we do not have the materials for this, it should _not_ reserve items, still provide the material index, and also provide a list of items that we do not have enough for
--   we'll then use this plan, alongside the current storage.items to show useful information
-- Make a function that rejects a crafting plan - unreserving all its materials
-- Make a function that executes a crafting plan, making all the stuff

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
A crafting plan is, in theory, a DAG, which i'd rather not model
the plan will be a array of arrays of crafts

We start by building the craft tree, root being the item we want with the amount (put ON the node)
we find its recipe - for each ingredient we check
  do we have some?
  if we don't have them all, we add a craft node with the amount we're missing. If we're missing a recipe for this, we don't have enough, the craft is a failure
    we instead add a missing items leaf, flagged
  if we don't have none, we add a leaf with the amount we have (we also add this leaf to the leaves array)
  each node should hold an array of its children and a ref to its parent
repeat depth first until we run out (or hit a cycle)

write a leaf prune function, which takes the list of leaves, returns their list of parents (nubbed by ref)

before the first prune, sum all the items in the leaves, this is the cost of the recipe (including any flagged leaves)
  if any leaves are missing items leaves, the recipe is said to be uncraftable, store this with the cost of the recipe lookup
do a first prune, which removes all items we already have
we get back the first list of crafts
repeat until the root has no children, add that as a final craft step

structure:
plan = {
  -- Inner lists are crafts that can happen together, handle with a forloop
  -- outer lists MUST happen after eachother, so iterate once _all_ crafts in the previous list are complete
  -- technically some nodes could be unblocked before the previous step completes, however single crafts take like 1 second, so it'd at max waste that much time
  -- This is not provided if items are missing
  steps?: [ [ {itemName: string, count: int} ] ]
  -- total ingredients it would use to create (including any missing), if a recipe is uncraftable, this will be greater than what we have in storage
  ingredients: { [itemName]: count }
  missingItems?: { [itemName]: count }
  craftable: bool
  -- below both needed for unreserving
  craftedItems: { [itemName]: count }
}

TODO: some crafts have extra items at the end, which will currently be reserved and unusable
we'll need some way to keep track of those to unreserve at the end
  added craftedItems to the end, need to add to that as we craft
  change craftShallow to take the craftCount, not the itemCount
  then, as we build the plan (so in the first pass), we can calculate and sum up the excess as we go
  and pass in the craft count as we need to, each node can store the craft count, as thats what we actually need
    each node doesnt need to know the excess though, as we'll know that as we build the tree and can fill out the craftedItems
  ofc, be sure to add in the goal item as well (easy example is crafting 1 stick, as the craftedItems will actually be 4, 
    so be sure to take into account that we may craft more of the TARGET than requested)

]]

function storage.crafting.makeCraftPlan(itemName, count)
  -- write me please
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

  if table.isEmpty(plan.steps) then
    for itemName, count in pairs(plan.craftedItems) do
      storage.unreserveItems(itemName, count)
    end
    cb()
  end

  local step = table.remove(plan.steps, 1)
  local stepPartsRemaining = #step
  for _, task in ipairs(step) do
    storage.crafting.craftShallow(task.itemName, task.count, function()
      stepPartsRemaining = stepPartsRemaining - 1
      if stepPartsRemaining == 0 then
        storage.crafting.runPlan(plan, cb)
      end
    end, true)
  end

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

-- Crafts an item, parallelising if needed, taking a callback for when finished
-- returns `true, errMessage` or `false, jobCount` based on if possible
-- Shallow - as does not attempt to craft any missing ingredients
-- will need a second `craft` function for crafting plans
function storage.crafting.craftShallow(itemName, itemCount, cb, useReserved)
  if itemCount == 0 then return false, "Cannot craft 0" end
  local recipe = storage.crafting.recipes[itemName]
  if not recipe then return false, "No recipe for " .. itemName end
  local craftCount = math.ceil(itemCount / recipe.count)
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
