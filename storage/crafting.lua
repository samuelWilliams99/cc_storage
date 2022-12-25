storage.crafting = storage.crafting or {}

local craftingPort = 1357
local modem = peripheral.wrap("back")
modem.open(craftingPort)

local function handleAllReplies(handler, ids)
  os.startTimer(1)
  local remaining = table.shallowCopy(ids or {})
  while true do
    local data = {os.pullEvent()}
    if data[1] == "modem_message" and data[3] == craftingPort then
      handler(data)
      if ids then
        table.removeByValue(remaining, data.computerID)
        if table.isEmpty(remaining) then break end
      end
    elseif data[1] == "timer" then
      break
    end
  end
end

local function checkChests(chests, itemName, lastChest)
  storage.crafting.crafters = {}
  for i = #chests, 1, -1 do
    local chest = chests[i]
    lastChest.pushItems(peripheral.getName(chest))
    lastChest = chest
    modem.transmit(craftingPort, craftingPort, {type = "check", name = firstItemName})
    handleAllReplies(function(data)
      if data.found then
        table.insert(storage.crafting.crafters, {computerID = data.computerID, chest = chest})
        table.remove(chests, i)
      end
    end, storage.crafting.crafterIDs)
  end
end

function storage.crafting.setupCrafters()
  print("Locating crafters")
  local chests = storage.crafting.candidates or {}

  os.startTimer(1)
  modem.transmit(craftingPort, craftingPort, {type = "scan"})
  storage.crafting.crafterIDs = {}

  handleAllReplies(function(data)
    local compID = data[5].computerID
    table.insert(storage.crafting.crafterIDs, compID)
  end)

  print("Found " .. #storage.crafting.crafterIDs .. " crafting turtles, locating chests...")

  if table.isEmpty(storage.items) then error("Please place at least 1 item in one of the chests to initialise the system") end
  local firstItemName, item = next(storage.items)

  storage.dropItemTo(firstItemName, 1, storage.input)

  checkChests(chests, item.name, storage.input)
  print("Found chests for " .. #storage.crafting.crafters .. " crafting turtles and registered them.")

  print(#chests .. " crafting chest candidates turned out to be normal chests.")
  for _, chest in pairs(chests) do
    storage.addEmptyChest(chest)
  end
end

-- TODO: use multiple crafters
function storage.crafting.craft(recipe, amt)
  local crafter = storage.crafting.crafters[1]

  local items = {}
  local msg = {type = "craft", craftCount = amt}
  for i = 1, 9 do
    if recipe[i] then
      items[recipe[i]] = (items[recipe[i]] or 0) + amt
      msg[i] = recipe[i]
    end
  end
  for name, amt in pairs(items) do
    storage.dropItemTo(name, amt, crafter.chest)
  end
  modem.transmit(craftingPort, craftingPort, msg)

  -- pull event until get complete message back from that computer (or some timer passes)
  -- with os.pullEvent("modem_message")
  -- then input all items 
  -- maybe also update some global state thats like "crafting items" for UI purposes
end