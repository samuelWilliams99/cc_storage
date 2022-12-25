storage.crafting = storage.crafting or {}
storage.crafting.recipes = storage.crafting.recipes or {}
storage.crafting.crafters = {}
-- the jobQueue list is a queue of jobs to be run
storage.crafting.jobQueue = {}
-- a task is created by .craft or .craftShallow, and contains many jobs.
storage.crafting.tasks = {}

-- TODO (next): must bring all items needed for crafting into some sort of "temp location", or perhaps simply remove from the UI
-- so users may not take crafting ingredients as they are used

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
      handler(data)
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
    print("moved item to chest " .. i .. ", submitting message")
    modem.transmit(craftingPortOut, craftingPortIn, {type = "check", name = itemName})
    handleAllReplies(function(data)
      print("got reply: " .. data.found)
      if data.found then
        storage.crafting.crafters[data.computerID] = {computerID = data.computerID, chest = chest}
        table.remove(chests, i)
      end
    end, storage.crafting.crafterIDs)
    sleep(5)
  end
  print("finished, moving back")
  storage.inputChest(lastChest)
end

function storage.crafting.setupCrafters()
  print("Locating crafters")
  local chests = storage.crafting.candidates or {}

  os.startTimer(1)
  modem.transmit(craftingPortOut, craftingPortIn, {type = "scan"})
  storage.crafting.crafterIDs = {}

  handleAllReplies(function(data)
    local compID = data[5].computerID
    table.insert(storage.crafting.crafterIDs, compID)
  end)

  print("Found " .. #storage.crafting.crafterIDs .. " crafting turtles, locating chests...")

  if table.isEmpty(storage.items) then error("Please place at least 1 item in one of the chests to initialise the system") end
  local firstItemName, item = next(storage.items)

  print("pushed item to storage")
  storage.dropItemTo(firstItemName, 1, storage.input)

  checkChests(chests, item.detail.name, storage.input)
  print("Found chests for " .. table.count(storage.crafting.crafters) .. " crafting turtles and registered them.")

  print(#chests .. " crafting chest candidates turned out to be normal chests.")
  for _, chest in pairs(chests) do
    storage.addEmptyChest(chest)
  end
end

function storage.crafting.addRecipe(itemName, recipePlacement, count)
  count = count or 1
  local ingredients = {}
  for i = 1, 9 do
    if recipePlacement[i] then
      ingredients[recipePlacement[i]] = (ingredients[recipePlacement[i]] or 0) + 1
    end
  end
  storage.crafting.recipes[itemName] = {
    placement = recipePlacement,
    ingredients = ingredients,
    itemName = itemName,
    count = count
  }
end

-- Takes a recipe and works out the max number of times you can craft (note, if count > 1, this is different to max items), and the max per crafter
-- won't provide max per crafter if we can't make any (as we dont know max stacks)
function storage.crafting.getCraftAmounts(recipe)
  local minStack = 64
  local maxCrafts = math.huge
  for itemName, count in pairs(recipe.ingredients) do
    local item = storage.items[itemName]
    if not item then return 0 end
    local maxStackForIngredient = math.floor(item.detail.maxCount / count)
    local maxCraftsForIngredient = math.floor(item.count / count)
    if maxStackForIngredient < minStack then
      minStack = maxStackForIngredient
    end
    if maxCraftsForIngredient < maxCrafts then
      maxCrafts = maxCraftsForIngredient
    end
  end
  return maxCrafts, minStack
end

-- Crafts an item, parallelising if needed, taking a callback for when finished
-- returns `true, errMessage` or `false, jobCount` based on if possible
-- Shallow - as does not attempt to craft any missing ingredients
-- will need a second `craft` function for crafting plans
function storage.crafting.craftShallow(itemName, itemCount, cb)
  if itemCount == 0 then return false, "Cannot craft 0" end
  local recipe = storage.crafting.recipes[itemName]
  if not recipe then return false, "No recipe for " .. itemName end
  local craftCount = math.ceil(itemCount / recipe.count)
  local maxCrafts, maxCraftsPerCrafter = storage.crafting.getCraftAmounts(recipe)
  if maxCrafts < craftCount then return false, "Not enough ingredients to craft this many items" end

  -- Given we cannot assume maxCraftsPerCrafter fits into craftCount integer times, we do `repeatedCraftCount` jobs of maxCraftsPerCrafter crafts, alongside a "change" job
  -- this is the number of JOBs
  local repeatedJobCount = math.floor(maxCrafts / craftCount)
  -- this is the number of crafts for the change `job`
  local changeCount = craftCount - repeatedJobCount * maxCraftsPerCrafter

  local task = storage.crafting.addTask(cb)

  for i = 1, repeatedJobCount do
    storage.crafting.addCraftToQueue(recipe, maxCraftsPerCrafter, task)
  end
  if changeCount > 0 then
    storage.crafting.addCraftToQueue(recipe, changeCount, task)
  end
  return true, math.ceil(maxCrafts / craftCount)
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
function storage.crafting.addCraftToQueue(recipe, craftCount, task)
  local job = {
    recipe = recipe,
    craftCount = craftCount,
    task = task
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
    storage.dropItemTo(name, amt * job.craftCount, crafter.chest)
  end
  modem.transmit(craftingPortOut, craftingPortIn, msg)
end

hook.add("modem_message", "crafting_reply", function(_, port, _, data)
  if port ~= craftingPortIn then return end
  if data.type ~= "craft" then return end

  local crafter = storage.crafting.crafters[data.computerID]
  if not crafter then return end -- Not a crafter we know about
  storage.inputChest(crafter.chest)
  
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

-- Add a testing recipe, sticks
storage.crafting.addRecipe("minecraft:stick", {[1] = "minecraft:oak_planks", [4] = "minecraft:oak_planks"}, 4)
