dofile("cc_storage/utils/helpers.lua")
dofile("cc_storage/utils/timer.lua")
storage = {}
dofile("cc_storage/storage/crafting.lua")

function storage.updateChests()
  local chests = {peripheral.find("minecraft:chest")}
  storage.chests = {}
  storage.crafting.candidates = {}
  for _, chest in ipairs(chests) do
    if chest.getSize() == 27 and table.isEmpty(chest.list()) then
      table.insert(storage.crafting.candidates, chest)
    else
      table.insert(storage.chests, chest)
    end
  end

  print("Found " .. #storage.chests .. " chests and " .. #storage.crafting.candidates .. " crafter candidates")
  storage.dropper = peripheral.find("minecraft:trapped_chest")
  if storage.dropper then
    print("Found dropper chest.")
  else
    error("Could not find dropper chest, please add a trapped_chest to the network")
  end
  storage.input = peripheral.find("minecraft:barrel")
  if storage.input then
    print("Found input barrel.")
  else
    print("Could not find input barrel, please add a barrel to the network")
  end
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
  local locations = items[key].locations
  local locationKey = #locations + 1
  for k, location in ipairs(locations) do
    if item.count < location.count then
      locationKey = k
      break
    end
  end
  table.insert(items[key].locations, locationKey, {chest = chest, slot = slot, count = item.count})
end

function storage.updateItemMapping()
  print("Building item matrix...")
  storage.items = {}
  storage.emptySlots = {}
  local items = storage.items
  local itemCount = 0

  for chestKey, chest in pairs(storage.chests) do
    local chestItems = chest.list()
    for slot = 1, chest.size() do
      local item = chestItems[slot]
      if item then
        local detail = chest.getItemDetail(slot)
        itemCount = itemCount + item.count

        storage.saveItem(item, detail, chest, slot)
      else
        table.insert(storage.emptySlots, {chest = chest, slot = slot})
      end
    end
    print("Indexed chest " .. chestKey .. "/" .. #storage.chests)
  end

  local uniqueItemCount = table.count(items)

  print("Built item matrix.")
  print("Found " .. itemCount .. " items, " .. uniqueItemCount .. " of which unique.")
  print("Found " .. #storage.emptySlots .. " empty slots.")
end

function storage.addEmptyChest(chest)
  for slot = 1, chest.getSize() do
    table.insert(storage.emptySlots, {chest = chest, slot = slot})
  end
end

function storage.dropItem(key, count)
  local item = storage.items[key]
  if not item then
    return false
  end

  storage.dropItems(item.locations, count)
  count = math.min(count, item.count)
  item.count = item.count - count
  if item.count <= 0 then
    storage.items[key] = nil
  end
  hook.run("cc_storage_change", key, -count, item)
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

    if location.count == 0 then
      table.remove(locations, 1)
      table.insert(storage.emptySlots, {chest = location.chest, slot = location.slot})
    end

    if count == 0 then
      break
    end
  end
end

function storage.startInputTimer()
  timer.create("input", 0.5, 0, storage.inputLoop)
end

function storage.inputLoop()
  local inputItems = storage.input.list()
  if table.isEmpty(inputItems) then
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
  local startingCount = item.count
  if storedItem then
    storage.inputItems(storedItem, slot, item)
  end
  if item.count == 0 then
    hook.run("cc_storage_change", key, startingCount, storedItem)
    return
  end

  if #storage.emptySlots == 0 then
    if item.count ~= startingCount then
      hook.run("cc_storage_change", key, startingCount - item.count, storedItem)
    end
    -- print("Out of empty spaces, can't fit additional " .. item.count .. " of " .. item.name .. " in chests.")
    return
  end

  local newSlot = table.remove(storage.emptySlots, 1)
  storage.input.pushItems(peripheral.getName(newSlot.chest), slot, item.count, newSlot.slot)

  storage.saveItem(item, detail, newSlot.chest, newSlot.slot)

  hook.run("cc_storage_change", key, startingCount, storedItem)
end

function storage.inputItems(item, slot, newItem)
  local max = item.detail.maxCount
  for k = #item.locations, 1, -1 do
    local location = item.locations[k]
    local canAdd = max - location.count
    if canAdd > 0 then
      local toMove = canAdd
      if canAdd >= newItem.count then
        toMove = newItem.count
      end
      storage.input.pushItems(peripheral.getName(location.chest), slot, toMove, location.slot)
      location.count = location.count + toMove
      item.count = item.count + toMove
      newItem.count = newItem.count - toMove
      if newItem.count == 0 then break end
    end
  end
end
