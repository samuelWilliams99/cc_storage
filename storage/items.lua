dofile("cc_storage/utils/helpers.lua")
dofile("cc_storage/utils/timer.lua")

storage = {}

function storage.updateChests()
  storage.chests = {peripheral.find("minecraft:chest")}
  storage.dropper = peripheral.find("minecraft:trapped_chest")
  storage.input = peripheral.find("minecraft:barrel")
end

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

function storage.getItemKey(item, detail)
  return item.name .. (detail.nbt or "") .. (detail.damage or "")
end

function storage.saveItem(item, detail, chest, slot)
  local items = storage.items
  local key = storage.getItemKey(item, detail)

  items[key] = items[key] or {count = 0, locations = {}}
  items[key].count = items[key].count + item.count
  items[key].detail = detail
  table.insert(items[key].locations, {chest = chest, slot = slot, count = item.count})
end

function storage.updateItemMapping(chests)
  storage.items = {}
  storage.emptySlots = {}
  local items = storage.items

  for _, chest in pairs(chests) do
    local chestItems = chest.list()
    for k = 1, chest.size() do
      local item = chestItems[k]
      if item then
        local detail = chest.getItemDetail(k)

        storage.saveItem(item, detail, chest, k)
      else
        table.insert(storage.emptySlots, {chest = chest, slot = k})
      end
    end
  end
end

function storage.dropItem(key, count)
  local item = storage.items[key]
  if not item then
    return false
  end

  storage.dropItems(item.locations, count)
  item.count = item.count - count
  if item.count <= 0 then
    storage.items[keys] = nil
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
      table.insert(storage.emptySlots, {chest = location.chest, slot = location.slot})
    end
  end
end

function storage.startInputTimer()
  timer.create("input", 0.5, 0, storage.inputLoop)
end

function storage.inputLoop()
  local inputItems = storage.input.list()
  if #inputItems == 0 then
    return
  end

  if #storage.emptySlots == 0 then
    print("OUT OF SPACEEEEEE")
    return
  end

  for k, item in pairs(inputItems) do
    storage.inputItem(k, item)
  end
end

function storage.inputItem(slot, item)
  local detail = storage.input.getItemDetail(slot)
  local key = storage.getItemKey(item, detail)
  local storedItem = storage.items[key]
  if storedItem then
    storage.inputItems(storedItem, slot, item)
  end
  if item.count == 0 then return end

  if #storage.emptySlots == 0 then return end
  local newSlot = table.remove(storage.emptySlots, 1)
  storage.input.pushItems(peripheral.getName(newSlot.chest), slot, item.count, newSlot.slot)

  storage.saveItem(item, detail, newSlot.chest, newSlot.slot)
end

function storage.inputItems(item, slot, newItem)
  local max = item.detail.maxItems
  for _, location in ipairs(item.locations) do
    local canAdd = max - location.count
    if canAdd > 0 then
      local toMove = canAdd
      if canAdd >= newItem.count then
        toMove = newItem.count
      end
      storage.input.pushItems(peripheral.getName(location.chest), slot, toMove, location.slot)
      location.count = location.count + toMove
      newItem.count = newItem.count - toMove
      if newItem.count == 0 then break end
    end
  end
end
