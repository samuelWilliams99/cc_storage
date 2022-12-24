dofile("cc_storage/utils/hooks.lua")
hook.clear()

local craftingPort = 1357
local modem = peripheral.find("modem")
modem.open(craftingPort)

local gridTranslation = {1,2,3,5,6,7,9,10,11}

local function moveItem(data)
  local item = turtle.getItemDetail()
  for i = 1, 9 do
    if data[i] and data[i] == item.name then
      turtle.transferTo(gridTranslation[i], data.craftCount)
    end
  end
end

hook.add("modem_message", "doCraft", function(_, port, _, data)
  -- Data is mapping 1-9 to an item, alongside "craftCount" as number to make
  turtle.select(16)
  while turtle.suck() do
    moveItem(data)
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
