require "utils.hooks"
require "utils.helpers"

local craftingPortIn = 1357
local craftingPortOut = craftingPortIn + 1
local modem = peripheral.find("modem")
modem.open(craftingPortIn)

local gridTranslation = {1,2,3,5,6,7,9,10,11}

local function moveItem(moveData)
  local item = turtle.getItemDetail()
  local slots = moveData[item.name]
  if not slots then return end
  for slot, amt in pairs(slots) do
    local toMove = math.min(amt, item.count)
    turtle.transferTo(gridTranslation[slot], toMove)
    if amt == toMove then
      slots[slot] = nil
    else
      slots[slot] = amt - toMove
    end
    item.count = item.count - toMove
    if item.count == 0 then break end
  end
end

local function handleCrafting(data)
  -- Data is mapping 1-9 to an item, alongside "craftCount" as number to make
  turtle.select(16)

  local placement = data.placement
  local moveData = {}
  for i = 1, 9 do
    if placement[i] then
      moveData[placement[i]] = moveData[placement[i]] or {}
      moveData[placement[i]][i] = data.craftCount
    end
  end

  while turtle.suck() do
    moveItem(moveData)
  end

  turtle.select(1)
  turtle.craft()
  for i = 1, 16 do
    turtle.select(i)
    if turtle.getItemCount() == 0 then break end
    turtle.drop()
  end
  modem.transmit(craftingPortOut, craftingPortIn, {type = "craft", computerID = os.getComputerID()})
end

local function toBool(x)
  -- avoid the `x and y or z` syntax here to be explicit
  if x then return true else return false end
end

hook.add("modem_message", "doCraft", function(_, port, _, data)
  if data.type == "craft" then
    if data.computerID == os.getComputerID() then
      print("Received a craft request, handling...")
      handleCrafting(data)
      print("Finished!")
    end
  elseif data.type == "scan" then
    modem.transmit(craftingPortOut, craftingPortIn, {type = "scan", computerID = os.getComputerID()})
    term.clear()
    term.setCursorPos(1, 1)
    print("Replied to crafter ping!")
  elseif data.type == "check" then
    if not table.contains(data.ids, os.getComputerID()) then return end
    print("Received a check message, looking for " .. data.name)
    turtle.select(16)
    turtle.suck()
    local item = turtle.getItemDetail(16)
    local found = toBool(item and item.name == data.name)
    print(found and "Found item" or "Did not find item")
    turtle.drop()

    local slotsToDrop = {}
    for i = 1, 15 do
      if turtle.getItemCount(i) > 0 then table.insert(slotsToDrop, i) end
    end

    modem.transmit(craftingPortOut, craftingPortIn, {type = "check", found = found, computerID = os.getComputerID(), shouldEmpty = #slotsToDrop > 0})
    if found then
      for _, slot in ipairs(slotsToDrop) do
        turtle.select(slot)
        turtle.drop()
      end
      if #slotsToDrop > 0 then
        modem.transmit(craftingPortOut, craftingPortIn, {type = "chest_emptied", computerID = os.getComputerID()})
      end
    end
  elseif data.type == "empty_chest" then
    if not table.contains(data.ids, os.getComputerID()) then return end
    print("Emptying chest")
    turtle.select(1)
    while turtle.suck() do end
    modem.transmit(craftingPortOut, craftingPortIn, {type = "empty_chest", computerID = os.getComputerID()})
  end
end)

hook.runLoop()
