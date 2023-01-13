storage.crafting = storage.crafting or {}
require "storage.recipes"
require "utils.helpers"

storage.crafting.crafters = {}
-- the jobQueue list is a queue of jobs to be run
storage.crafting.jobQueue = {}
-- a task is created by .craftShallow, and contains many jobs.
storage.crafting.tasks = {}
-- a plan is a series of tasks for deep crafting
storage.crafting.plans = {}

-- TODO: crafting UI

-- TODO: Recipes can be invalid, should throw a reasonable error in this case
-- or, force verification when adding a recipe?

local craftingPortOut = 1357
local craftingPortIn = craftingPortOut + 1
local modem = peripheral.find("modem", function(_, p) return p.isWireless() end)
modem.open(craftingPortIn)

-- We specifically use os.pullEvent here as this code all runs _before_ the hook system gets enabled
-- Also, it allows us to treat these replies as syncronous calls, which makes the setup easier
-- ideally we'd use promises, but they're a little heavy for CC
local function handleAllReplies(msgType, handler, ids, ignoreTimer)
  local timerID = os.startTimer(1)
  local remaining = table.shallowCopy(ids or {})
  while true do
    local data = {os.pullEvent()}
    if data[1] == "modem_message" and data[3] == craftingPortIn and data[5].type == msgType then
      local handlerRet = {handler(data[5])}
      if handlerRet[1] then
        table.remove(handlerRet, 1)
        return table.unpack(handlerRet)
      end
      if ids then
        table.removeByValue(remaining, data[5].computerID)
        if table.isEmpty(remaining) then break end
      end
    elseif data[1] == "timer" and data[2] == timerID and not ignoreTimer then
      break
    end
  end
  os.cancelTimer(timerID)
end

local function checkChests(chests, itemName)
  storage.crafting.crafters = {}

  local chest = chests[#chests]

  for i = #chests, 1, -1 do
    chest = chests[i]
    
    modem.transmit(craftingPortOut, craftingPortIn, {type = "check", name = itemName, ids = storage.crafting.crafterIDs})
    local shouldEmpty = handleAllReplies("check", function(data)
      if data.found then
        storage.crafting.crafters[data.computerID] = {computerID = data.computerID, chest = chest}
        table.remove(chests, i)
        return true, data.shouldEmpty
      end
    end, storage.crafting.crafterIDs)

    if i > 1 then
      chest.pushItems(peripheral.getName(chests[i - 1]), 1, 1, 1)
    end

    if shouldEmpty then
      handleAllReplies("chest_emptied", function() return true end, storage.crafting.crafterIDs, true)
      storage.inputChest(chest)
    end
  end
  storage.inputChest(chest)
end

function storage.crafting.pingCrafters()
  print("Locating crafters")
  
  modem.transmit(craftingPortOut, craftingPortIn, {type = "scan"})
  storage.crafting.crafterIDs = {}

  handleAllReplies("scan", function(data)
    local compID = data.computerID
    table.insert(storage.crafting.crafterIDs, compID)
  end)
  
  print("Found " .. #storage.crafting.crafterIDs .. " crafting turtles")

  modem.transmit(craftingPortOut, craftingPortIn, {type = "empty_chest", ids = storage.crafting.crafterIDs})
  handleAllReplies("empty_chest", function() end, storage.crafting.crafterIDs, true)

  print("All crafter chests emptied")
end

function storage.crafting.setupCrafters()
  print("Locating crafter chests...")
  local chests = storage.crafting.candidates or {}

  if table.isEmpty(storage.items) then error("Please place at least 1 item in one of the chests to initialise the system") end
  local firstItemName, item = next(storage.items)

  if table.isEmpty(chests) then
    print("No crafting candidates found")
    return
  end

  storage.dropItemTo(firstItemName, 1, chests[#chests])

  checkChests(chests, item.detail.name)
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

  -- while running plan, extended with:
  intermediates: { [itemName]: count } -- to avoid using resources crafted by other concurrent plans
}

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

function storage.crafting.makeAndRunPlan(itemName, count, cb)
  local plan = storage.crafting.makeCraftPlan(itemName, count)
  if not plan.craftable then return false end
  storage.reserveItems(plan.ingredients)
  storage.crafting.runPlan(plan, cb)
  return true
end

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
    ingredientDisplayNames = {},
    missingIngredients = {},
    craftedItems = {},
    craftable = true,
    count = count
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
      count = 0,
      isRoot = isRoot,
      itemName = itemName
    }
    plan.nodes[itemName] = node
    plan.leaves[itemName] = true
  end

  node.count = node.count + craftCount

  if not isRoot and not hadCraftedItems then
    table.insert(node.parents, parent)
    plan.leaves[parent.itemName] = nil
  end

  -- TODO: smarter prioritisation here, some parents take longer than others, and should be prioritised
  for ingredientName, ingredientCount in pairs(recipe.ingredients) do
    -- Can drop the ingredientDisplayNames check once migrated
    if recipe.ingredientDisplayNames and recipe.ingredientDisplayNames[ingredientName] then
      plan.ingredientDisplayNames[ingredientName] = recipe.ingredientDisplayNames[ingredientName]
    end
    storage.crafting.makeCraftPlanAux(ingredientName, ingredientCount * craftCount, plan, node)
  end
end

function storage.crafting.reservePlan(plan)
  if not plan.craftable then return end
  storage.reserveItems(plan.ingredients)
end

function storage.crafting.unreservePlan(plan)
  if not plan.craftable then return end
  storage.unreserveItems(plan.ingredients)
end

function storage.crafting.runPlan(plan, cb)
  if not plan.craftable then return false, "Uncraftable plan" end
  table.insert(storage.crafting.plans, plan)

  plan.intermediates = table.shallowCopy(plan.ingredients) -- maybe just set to ingredients if we dont care about ingreds after its made
  
  for _, itemName in ipairs(plan.leaves) do
    local node = plan.nodes[itemName]
    storage.crafting.runPlanAux(plan, node, cb)
  end
end

local function nodeCraftable(plan, node)
  for itemName, count in pairs(storage.crafting.recipes[node.itemName].ingredients) do
    if (plan.intermediates[itemName] or 0) < count * node.count then return false end
  end
  return true
end

function storage.crafting.runPlanAux(plan, node, cb)
  local recipe = storage.crafting.recipes[node.itemName]
  -- decrease intermediates by ingredients
  for itemName, count in pairs(recipe.ingredients) do
    plan.intermediates[itemName] = plan.intermediates[itemName] - count * node.count
  end

  -- create task
  storage.crafting.craftShallow(node.itemName, node.count, function()
    -- add items crafted to intermediates
    plan.intermediates[node.itemName] = (plan.intermediates[node.itemName] or 0) + recipe.count * node.count
    -- set count to 0 to mark complete
    node.count = 0
    -- if node is root, unreserve crafteditems, run original cb, return
    if node.isRoot then
      table.removeByValue(storage.crafting.plans, plan)
      handleFailure(storage.unreserveItems(plan.craftedItems))
      if cb then cb() end
      return
    end
    
    -- check nodes parents, filter out any with count of 0
    local incompleteParents = table.filter(node.parents, function(parent) return parent.count > 0 end)

    -- iterate the list - if we have enough items for it, recurse
    for _, parent in ipairs(incompleteParents) do
      if nodeCraftable(plan, parent) then
        storage.crafting.runPlanAux(plan, parent, cb)
      end
    end
  end, true)
end

-- Calculates the max of this item that a crafter can craft
function storage.crafting.getMaxPerCrafter(recipe)
  local minCount = 64
  for itemName, count in pairs(recipe.ingredients) do
    local item = storage.items[itemName]
    if not item then return end
    local maxCountForIngredient = math.floor(item.detail.maxCount / count)
    if maxCountForIngredient < minCount then
      minCount = maxCountForIngredient
    end
  end
  return math.min(minCount, recipe.maxCrafts)
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
      table.removeByValue(storage.crafting.tasks, job.task)
      if job.task.cb then job.task.cb() end
    end
  end

  if table.isEmpty(storage.crafting.jobQueue) then
    crafter.activeJob = nil
  else
    -- TODO: Doesn't need to run head of this list, can be any element
    -- Implement prioritisation here to run jobs that block more time first
    local nextJob = table.remove(storage.crafting.jobQueue, 1)
    storage.crafting.runCrafter(nextJob, crafter)
  end
end)
