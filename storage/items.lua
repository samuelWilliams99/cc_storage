require "utils.helpers"
require "utils.timer"
require "storage.crafting"

-- TODO: Implement maxstack
-- Will need mechanism for fast item deletion, consider the double chest + turtle strat. Checking for this setup will be annoying, consider making it optional
-- Also, a UI for this will be difficult, as we need to list all items. Consider making it part of the main buttonList UI, maybe a cog on each, or an "edit" mode
-- in this we can do item stack limits, and maybe some other settings per item - say displaying the count on a monitor, or requiring an amt in players inv, idk

-- TODO: Implement item waiting if the dropped-to inv is full, we don't currently check it

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

  storage.turtles = {peripheral.find("turtle", avoidSides)}
  for _, turtle in ipairs(storage.turtles) do turtle.turnOn() end

  print("Found " .. #storage.chests .. " chests, " .. #storage.crafting.candidates .. " crafter candidates and " .. #storage.turtles .. " turtles")
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
key = itemName + nbt
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

function storage.getItemKey(item)
  return item.name .. (item.nbt or "")
end

function storage.saveItem(item, chest, slot, useReserved)
  local items = storage.items
  local key = storage.getItemKey(item)
  local didLookup = false

  -- Pulled out into a var as "getItemDetail" takes time, and can lead to an item being detail-less while inputting
  local newItem = items[key] or {count = 0, locations = {}, reservedCount = 0, key = key}
  if useReserved then
    newItem.reservedCount = newItem.reservedCount + item.count
  else
    newItem.count = newItem.count + item.count
  end
  if not newItem.detail then
    newItem.detail = chest.getItemDetail(slot)
    didLookup = true
  end
  local locations = newItem.locations
  local locationKey = #locations + 1
  for k, location in ipairs(locations) do
    if item.count < location.count then
      locationKey = k
      break
    end
  end
  table.insert(newItem.locations, locationKey, {chest = chest, slot = slot, count = item.count})
  items[key] = newItem
  return didLookup
end

function storage.reserveItemsUnsafe(items, shouldUnreserve)
  for key, count in pairs(items) do
    local item = storage.items[key]
    if not item then return false, "No such item key: " .. key end
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
    while storage.itemLock do
      sleep(0.05)
    end
    storage.itemLock = true
    local res = table.pack(f(...))
    storage.itemLock = false
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
  if charCount == w - 2 then
    writeLine("[" .. string.rep("=", w - 2) .. "]", y)
  else
    writeLine("[" .. string.rep("=", charCount - 1) .. ">" .. string.rep(" ", w - 2 - charCount) .. "]", y)
  end
end

local function writeUpdate(text, stepNum, stepMax, progPrefix, prog, progMax, y)
  writeLine(text .. " (step " .. stepNum .. "/" .. stepMax .. ") (" .. progPrefix .. " " .. prog .. "/" .. progMax .. ")", y)
  writeProgressBar(prog/progMax, y + 1)
end

function storage.getTotalSlotCount()
  return storage.totalSlotCount
end

function storage.updateItemMapping()
  print("Building item matrix...")
  storage.items = {}
  storage.emptySlots = {}
  storage.emptySlotCount = 0
  storage.totalSlotCount = 0
  local items = storage.items
  local itemCount = 0

  local _, termY = term.getCursorPos()

  local uniqueItemKeys = {}
  local chestCount = table.count(storage.chests)
  local chestCounter = 1
  local chestsData = {}
  for chestKey, chest in ipairs(storage.chests) do
    local chestItems = chest.list()
    for _, item in pairs(chestItems) do
      uniqueItemKeys[storage.getItemKey(item)] = true
    end
    local size = chest.size()
    storage.totalSlotCount = storage.totalSlotCount + size
    chestsData[chestKey] = {
      list = chestItems,
      size = size,
      chest = chest
    }
    writeUpdate("Finding chests and sizes", 1, 2, "chest", chestCounter, chestCount, termY)
    chestCounter = chestCounter + 1
  end

  local uniqueItemKeyCount = table.count(uniqueItemKeys)

  local itemCounter = 1
  local prevItemCounter = 1
  for _, chestData in ipairs(chestsData) do
    local chestItems = chestData.list
    local chest = chestData.chest
    for slot = 1, chestData.size do
      if itemCounter ~= prevItemCounter then
        prevItemCounter = itemCounter
        writeUpdate("Indexing unique items", 2, 2, "item", itemCounter, uniqueItemKeyCount, termY)
      end
      local item = chestItems[slot]
      if item then
        itemCount = itemCount + item.count

        if storage.saveItem(item, chest, slot) then
          itemCounter = itemCounter + 1
        end
      else
        table.insert(storage.emptySlots, {chest = chest, slot = slot})
        storage.emptySlotCount = storage.emptySlotCount + 1
      end
    end
  end

  local uniqueItemCount = table.count(items)

  writeUpdate("Complete", 2, 2, "item", uniqueItemKeyCount, uniqueItemKeyCount, termY)
  term.setCursorPos(1, termY + 2)
  print("Found " .. itemCount .. " items, " .. uniqueItemCount .. " of which unique.")
  print("Found " .. #storage.emptySlots .. " empty slots.")
end

function storage.addEmptyChest(chest)
  local size = chest.size()
  for slot = 1, size do
    table.insert(storage.emptySlots, {chest = chest, slot = slot})
    storage.emptySlotCount = storage.emptySlotCount + 1
  end
  storage.totalSlotCount = storage.totalSlotCount + size
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
      storage.emptySlotCount = storage.emptySlotCount + 1
    end

    if count == 0 then
      break
    end
  end
end

function storage.startInputTimer()
  timer.create("input", 0.5, 0, function() storage.inputChest(storage.input) end)
end

-- We provide a way to give the input items, to save on calls to list
function storage.inputChestUnsafe(chest, useReserved, inputItems)
  inputItems = inputItems or chest.list()
  if table.isEmpty(inputItems or {}) then
    return
  end

  for k, item in pairs(inputItems) do
    storage.inputItemFromUnsafe(k, item, chest, useReserved)
  end
end

local function peripheralPresent(p)
  return peripheral.isPresent(peripheral.getName(p))
end

storage.inputChest = storage.withLock(storage.inputChestUnsafe)

function storage.inputItemFromUnsafe(slot, item, chest, useReserved)
  local key = storage.getItemKey(item)
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
  
  if #storage.emptySlots == 0 or not peripheralPresent(chest) then
    if item.count ~= startingCount and not useReserved then
      itemChanged(key, startingCount - item.count, storedItem)
    end

    return
  end
  
  local newSlot = table.remove(storage.emptySlots, 1)
  storage.emptySlotCount = storage.emptySlotCount - 1

  chest.pushItems(peripheral.getName(newSlot.chest), slot, item.count, newSlot.slot)
  
  storage.saveItem(item, newSlot.chest, newSlot.slot, useReserved)
  
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

      if not peripheralPresent(chest) then return end
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
