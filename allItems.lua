local function filter(xs, p)
  local out = {}
  for i, x in ipairs(xs) do
    if p(x, i) then
      table.insert(out, x)
    end
  end
  return out
end

local function startsWith(s, s2)
  return s:sub(1, #s2) == s2
end

function table.map(t, f)
  local out = {}
  for k, v in pairs(t) do
    out[k] = f(v)
  end
  return out
end

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
