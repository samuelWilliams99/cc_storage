require("../utils/helpers.lua")

local names = peripheral.getNames()

chests = filter(names, function(name)
  return startsWith(name, "minecraft:chest_")
end)

local periphs = table.map(chests, peripheral.wrap) 

local items = {}
for _, chest in pairs(periphs) do
  for k, item in pairs(chest.list()) do
    items[item.name] = items[item.name] or {count = 0}
    items[item.name].count = items[item.name].count + item.count

    if not items[item.name].displayName then
      items[item.name].displayName = chest.getItemDetail(k).displayName
    end
  end
end

for item, data in pairs(items) do
  print(data.displayName .. ": " .. data.count)
end
