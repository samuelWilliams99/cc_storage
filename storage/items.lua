dofile("cc_storage/utils/helpers.lua")

storage = {}

function storage.getChests()
  return {peripheral.find("minecraft:chest")}
end

--[[
key = itemName + nbt + durability
items = {
  key: {
    count: number
    detail: getItemDetail
    locations: list{
      chestName: string
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

      local key = item .. (detail.nbt or "") .. (detail.damage or "")

      items[key] = items[key] or {count = 0, locations = {}}
      items[key].count = items[key].count + item.count
      items[key].detail = detail
      table.insert(items[key].locations, {chestName = peripheral.getName(chest), slot = k, count = item.count})
    end
  end

  return items
end
