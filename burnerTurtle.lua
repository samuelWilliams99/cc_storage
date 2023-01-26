require "utils.hooks"
require "utils.helpers"

local burningPortIn = 1564
local burningPortOut = burningPortIn + 1
local modem = peripheral.find("modem", function(_, p) return not p.isWireless() end)
if not modem then error("Not connected to a wired modem") end
modem.open(burningPortIn)

for i = 1, 16 do
  if turtle.getItemCount(i) == 0 then
    error("Must have unstackable items in all but first slot, with trapped chest in first slot (in addition to once placed)")
  end
end

if turtle.getItemDetail(1).name ~= "minecraft:trapped_chest" then
  error("First item must be either empty or trapped chest")
end

if turtle.getItemCount(1) > 1 then
  turtle.place()
end

hook.add("modem_message", "doBurn", function(_, port, _, computerId)
  if port ~= burningPortIn then return end
  if os.getComputerID() ~= computerId then return end
  turtle.dig()
  turtle.place()
  modem.transmit(burningPortOut, burningPortIn, true) -- True is a very small amount of data, would use `nil` if allowed
end)

hook.runLoop()
