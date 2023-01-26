require "utils.hooks"
require "utils.helpers"

local burningPortIn = 1564
local burningPortOut = burningPortIn + 1
local modem = peripheral.find("modem", function(_, p) return not p.isWireless() end)
if not modem then error("Not connected to a wired modem") end
modem.open(burningPortIn)

for i = 2, 16 do
  if turtle.getItemCount(i) == 0 then
    error("Must have items in all but first slot")
  end
end

if turtle.getItemCount(1) > 0 then
  if turtle.getItemDetail(1).name ~= "trapped_chest" then
    error("First item must be either empty or trapped chest")
  end
  turtle.place()
end

hook.add("modem_message", "doBurn", function(_, port)
  if port ~= burningPortIn then return end
  turtle.dig()
  turtle.place()
  modem.transmit(burningPortOut, burningPortIn, true) -- True is a very small amount of data, would use `nil` if allowed
end)
