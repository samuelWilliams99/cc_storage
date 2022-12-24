dofile("cc_storage/utils/hooks.lua")
hook.clear()

local craftingPort = 1357
local modem = peripheral.find("modem")
modem.open(craftingPort)

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

hook.add("modem_message", "doCraft", function(_, port, _, data)
  -- Data is mapping 1-9 to an item, alongside "craftCount" as number to make
  turtle.select(16)

  local moveData = {}
  for i = 1, 9 do
    if data[i] then
      moveData[data[i]] = moveData[data[i]] or {}
      moveData[data[i]][i] = data.craftCount
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
  modem.transmit(craftingPort, craftingPort)
end)

hook.runLoop()
