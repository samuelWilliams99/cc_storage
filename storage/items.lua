dofile("cc_storage/utils/helpers.lua")

storage = {}

function storage.getChests()
  return {peripheral.find("minecraft:chest")}
end

storage.dropper = peripheral.find("minecraft:trapped_chest")

--[[
key = itemName + nbt + durability
items = {
  key: {
    count: number
    detail: getItemDetail
    locations: list{
      chest: chest
      slotNumber: number
      count: number
    }
  }
}
]]

function storage.getItemMapping(chests)
  local items = {}

  for _, chest in pairs(chests) do
    for k, item in pairs(chest.list()) do
      local detail = chest.getItemDetail(k)

      local key = item.name .. (detail.nbt or "") .. (detail.damage or "")

      items[key] = items[key] or {count = 0, locations = {}}
      items[key].count = items[key].count + item.count
      items[key].detail = detail
      table.insert(items[key].locations, {chest = chest, slot = k, count = item.count})
    end
  end

  return items
end

function storage.dropItem(items, key, count)
  local item = items[key]
  if not item then
    return false
  end

  storage.dropItems(item.locations, count)
  item.count = item.count - count
  if item.count <= 0 then
    items[keys] = nil
  end
  return true
end

function storage.dropItems(locations, count)
  while #locations > 0 do
    local location = locations[1]
    local toMove
    if location.count > count then
      toMove = count
      location.count = location.count - count
      count = 0
    else
      toMove = location.count
      count = count - location.count
      location.count = 0
    end

    -- do the drop
    location.chest.pushItems(peripheral.getName(storage.dropper), location.slot, toMove)

    if count == 0 then
      break
    else
      table.remove(locations, 1)
    end
  end
end
