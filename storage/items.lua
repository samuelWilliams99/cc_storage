require "utils.helpers"
require "utils.timer"

storage = {}
require "storage.crafting"

-- Must not use peripherals that are wrapped sides, as pushItems doesn't work with them. Must instead be through the wired modem.
local function avoidSides(name)
  if name:find("_") then return true end
end

function storage.updateChests()
  local chests = {peripheral.find("minecraft:chest", avoidSides)}
  storage.chests = {}
  storage.crafting.candidates = {}
  for _, chest in ipairs(chests) do
    if chest.size() == 27 and table.isEmpty(chest.list()) then
      table.insert(storage.crafting.candidates, chest)
    else
      table.insert(storage.chests, chest)
    end
  end

  print("Found " .. #storage.chests .. " chests and " .. #storage.crafting.candidates .. " crafter candidates")
  storage.dropper = peripheral.find("minecraft:trapped_chest", avoidSides)
  if storage.dropper then
    print("Found dropper chest")
  else
    error("Could not find dropper chest, please add a trapped_chest to the network")
  end
  storage.input = peripheral.find("minecraft:barrel", avoidSides)
  if storage.input then
    print("Found input barrel")
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

local function itemChanged(key, count, item)
  hook.run("cc_storage_change_item", key, count, item)
  hook.run("cc_storage_change")
end

function storage.getItemKey(item, detail)
  return item.name .. (detail.nbt or "") .. (detail.damage or "")
end

function storage.saveItem(item, detail, chest, slot, useReserved)
  local items = storage.items
  local key = storage.getItemKey(item, detail)

  items[key] = items[key] or {count = 0, locations = {}, reservedCount = 0}
  if useReserved then
    items[key].reservedCount = items[key].reservedCount + item.count
  else
    items[key].count = items[key].count + item.count
  end
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

function storage.reserveItemsUnsafe(items, shouldUnreserve)
  for key, count in pairs(items) do
    local item = storage.items[key]
    if not item then return false, "No such item" end
    if shouldUnreserve then
      if item.reservedCount < count then return false, "Not enough items" end
      count = -count
    else
      if item.count < count then return false, "Not enough items" end
    end
    item.count = item.count - count
    item.reservedCount = item.reservedCount + count
    hook.run("cc_storage_change_item", key, -count, item)
  end
  hook.run("cc_storage_change")
  return true
end

function storage.withLock(f)
  return function(...)
    while storage.lock do
      sleep(0.05)
    end
    storage.lock = true
    local res = table.pack(f(...))
    storage.lock = false
    return table.unpack(res, 1, res.n)
  end
end

storage.reserveItems = storage.withLock(storage.reserveItemsUnsafe)

function storage.unreserveItems(items)
  return storage.reserveItems(items, true)
end

local function writeLine(text, y)
  term.setCursorPos(1, y)
  term.clearLine()
  term.write(text)
end

-- Where frac is 0-1
local function writeProgressBar(frac, y)
  local w = term.getSize()
  local charCount = math.ceil(frac * (w - 2))
  writeLine("[" .. string.rep("=", charCount) .. string.rep(" ", w - 2 - charCount) .. "]", y)
end

local function writeUpdate(text, stepNum, stepMax, progPrefix, prog, progMax, y)
  writeLine(text .. " (step " .. stepNum .. "/" .. stepMax .. ") (" .. progPrefix .. " " .. prog .. "/" .. progMax .. ")", y)
  writeProgressBar(prog/progMax, y + 1)
end

function storage.updateItemMapping()
  print("Building item matrix...")
  storage.items = {}
  storage.emptySlots = {}
  local items = storage.items
  local itemCount = 0

  local _, termY = term.getCursorPos()

  local totalOccupiedSlots = 0
  local slotCounter = 1
  local chestCount = table.count(storage.chests)
  local chestCounter = 1
  local chestsData = {}
  for chestKey, chest in ipairs(storage.chests) do
    local chestItems = chest.list()
    totalOccupiedSlots = totalOccupiedSlots + table.count(chestItems)
    chestsData[chestKey] = {
      list = chestItems,
      size = chest.size(),
      chest = chest
    }
    writeUpdate("Finding chests and sizes", 1, 2, "chest", chestCounter, chestCount, termY)
    chestCounter = chestCounter + 1
  end

  for _, chestData in ipairs(chestsData) do
    local chestItems = chestData.list
    local chest = chestData.chest
    for slot = 1, chestData.size do
      writeUpdate("Indexing items", 2, 2, "slot", slotCounter, totalOccupiedSlots, termY)
      local item = chestItems[slot]
      if item then
        local detail = chest.getItemDetail(slot)
        itemCount = itemCount + item.count

        storage.saveItem(item, detail, chest, slot)
        slotCounter = slotCounter + 1
      else
        table.insert(storage.emptySlots, {chest = chest, slot = slot})
      end
    end
  end

  local uniqueItemCount = table.count(items)

  writeUpdate("Complete", 2, 2, "slot", totalOccupiedSlots, totalOccupiedSlots, termY)
  term.setCursorPos(1, termY + 2)
  print("Found " .. itemCount .. " items, " .. uniqueItemCount .. " of which unique.")
  print("Found " .. #storage.emptySlots .. " empty slots.")
end

function storage.addEmptyChest(chest)
  for slot = 1, chest.size() do
    table.insert(storage.emptySlots, {chest = chest, slot = slot})
  end
end

function storage.dropItem(key, count, useReserved)
  return storage.dropItemTo(key, count, storage.dropper, useReserved)
end

function storage.dropItemToUnsafe(key, count, chest, useReserved)
  local item = storage.items[key]
  if not item then
    return false
  end

  if useReserved then
    if item.reservedCount < count then return false end
    item.reservedCount = item.reservedCount - count
    item.count = item.count + count
  end

  if item.count == 0 then return false end

  storage.dropItemsTo(item.locations, count, chest)
  count = math.min(count, item.count)
  item.count = item.count - count
  if item.count == 0 and item.reservedCount == 0 then
    storage.items[key] = nil
  end

  if not useReserved then
    itemChanged(key, -count, item)
  end
  return true
end

storage.dropItemTo = storage.withLock(storage.dropItemToUnsafe)

function storage.dropItemsTo(locations, count, chest)
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
    location.chest.pushItems(peripheral.getName(chest), location.slot, toMove)

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
  timer.create("input", 0.5, 0, function() storage.inputChest(storage.input) end)
end

function storage.inputChest(chest, useReserved)
  local inputItems = chest.list()
  if table.isEmpty(inputItems) then
    return
  end

  for k, item in pairs(inputItems) do
    storage.inputItemFrom(k, item, chest, useReserved)
  end
end

function storage.inputItemFromUnsafe(slot, item, chest, useReserved)
  local detail = chest.getItemDetail(slot)
  local key = storage.getItemKey(item, detail)
  local storedItem = storage.items[key]
  local startingCount = item.count
  if storedItem then
    storage.inputItemsFrom(storedItem, slot, item, chest, useReserved)
  end
  if item.count == 0 then
    if not useReserved then
      itemChanged(key, startingCount, storedItem)
    end
    return
  end
  
  if #storage.emptySlots == 0 then
    if item.count ~= startingCount and not useReserved then
      itemChanged(key, startingCount - item.count, storedItem)
    end

    return
  end
  
  local newSlot = table.remove(storage.emptySlots, 1)
  chest.pushItems(peripheral.getName(newSlot.chest), slot, item.count, newSlot.slot)
  
  storage.saveItem(item, detail, newSlot.chest, newSlot.slot, useReserved)
  
  if not useReserved then
    itemChanged(key, startingCount, storedItem)
  end
end

storage.inputItemFrom = storage.withLock(storage.inputItemFromUnsafe)

function storage.inputItemsFrom(item, slot, newItem, chest, useReserved)
  local max = item.detail.maxCount
  for k = #item.locations, 1, -1 do
    local location = item.locations[k]
    local canAdd = max - location.count
    if canAdd > 0 then
      local toMove = canAdd
      if canAdd >= newItem.count then
        toMove = newItem.count
      end
      chest.pushItems(peripheral.getName(location.chest), slot, toMove, location.slot)
      location.count = location.count + toMove

      if useReserved then
        item.reservedCount = item.reservedCount + toMove
      else
        item.count = item.count + toMove
      end

      newItem.count = newItem.count - toMove
      if newItem.count == 0 then break end
    end
  end
end
