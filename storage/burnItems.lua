storage.burnItems = {}
storage.burnItems.maxSlots = 27
storage.burnItems.slotsLeft = storage.burnItems.maxSlots

local burningPortOut = 1564
local burningPortIn = burningPortOut + 1
storage.wiredModem.open(burningPortIn)

storage.burnItems.itemSettingsPath = "./itemSettings.txt"

-- TODO: Add a config page to quickly get to existing item settings, as else setting an item to 0 permanently blocks it from computer
-- This page should have a "bin slots used" thing, as well as a "reclaim burned items" button

-- Returns number | nil
function storage.burnItems.getItemLimit(itemKey)
  local itemSetting = storage.burnItems.itemSettings[itemKey]
  return itemSetting and itemSetting.limit
end

function storage.burnItems.getNextBurnTime()
  return storage.burnItems.nextBurnTime
end

function storage.burnItems.getBurnSlotsUsed()
  return storage.burnItems.maxSlots - storage.burnItems.slotsLeft
end

function storage.burnItems.getMaxBurnSlots()
  return storage.burnItems.maxSlots
end

function storage.burnItems.saveSettings()
  writeFile(storage.burnItems.itemSettingsPath, storage.burnItems.itemSettings)
end

--[[
itemSettings: {
  itemKey: {
    limit = number | nil
  }
}
]]
function storage.burnItems.setup()
  storage.burnItems.itemSettings = readFile(storage.burnItems.itemSettingsPath) or {}
  for _, turtle in ipairs(storage.turtles) do
    if turtle.getLabel() == "burner" then
      storage.burnItems.turtle = turtle
      storage.burnItems.burnChest(true)
      return
    end
  end
  error("No burner turtle found")
end

function storage.burnItems.burnChest(ignoreSlots)
  storage.burnItems.setBurnIn(nil)
  if storage.burnItems.slotsLeft == storage.burnItems.maxSlots and not ignoreSlots then return end
  storage.wiredModem.transmit(burningPortOut, burningPortIn, storage.burnItems.turtle.getID())
  while true do
    local _, _, port = os.pullEvent("modem_message")
    if port == burningPortIn then break end
  end
  storage.burnItems.slotsLeft = storage.burnItems.maxSlots
end

function storage.burnItems.withBurnLock(f, pred)
  return function(...)
    while storage.burnItems.burnLock or (pred and pred()) do
      sleep(0.05)
    end
    storage.burnItems.burnLock = true
    local ret = table.pack(f(...))
    storage.burnItems.burnLock = false
    return table.unpack(ret, 1, ret.n)
  end
end

function storage.burnItems.withBurnAndItemLock(f)
  return storage.burnItems.withBurnLock(f, function() return storage.itemLock end)
end

function storage.burnItems.setBurnIn(t)
  storage.burnItems.nextBurnTime = t and (os.unixTime() + t)
  if t then
    timer.create("burnItems", t, 1, storage.burnItems.withBurnLock(storage.burnItems.burnChest))
  else
    timer.remove("burnItems")
  end
  hook.run("cc_burn_items_next_burn_time", storage.burnItems.nextBurnTime)
end

-- Starts a timer to, or immediately clears the burn chest
function storage.burnItems.checkBurnChest(async)
  if storage.burnItems.slotsLeft == 0 then
    if async then
      storage.burnItems.setBurnIn(0.05)
    else
      storage.burnItems.burnChest()
    end
    return
  end
  storage.burnItems.setBurnIn(300)
end

function storage.burnItems.canBurnInCurrentBatch()
  return storage.burnItems.slotsLeft > 0
end

function storage.burnItems.burnItemStackFromInputUnsafe(chest, slot, amt)
  if storage.burnItems.slotsLeft == 0 then return end
  chest.pushItems(peripheral.getName(storage.burnItems.chest), slot, amt)
  storage.burnItems.slotsLeft = storage.burnItems.slotsLeft - 1
  storage.burnItems.checkBurnChest(true)
end

storage.burnItems.burnItemStackFromInput = storage.burnItems.withBurnLock(storage.burnItems.burnItemStackFromInputUnsafe)

function storage.burnItems.addItemEntry(itemKey)
  if storage.burnItems.itemSettings[itemKey] then return end
  storage.burnItems.itemSettings[itemKey] = {} -- Add default values here
end

function storage.burnItems.getItemSetting(itemKey)
  return storage.burnItems.itemSettings[itemKey] or {}
end

function storage.burnItems.setItemLimit(itemKey, limit)
  storage.burnItems.itemSettings[itemKey].limit = limit
  if not limit then -- This will need changing later if we add more settings
    storage.burnItems.itemSettings[itemKey] = nil
  end
  hook.run("cc_burn_items_settings_change", itemKey, storage.burnItems.itemSettings[itemKey])
  storage.burnItems.saveSettings()
  -- Delay this to another coroutine, so the function may return immediately
  timer.simple(0.05, function()
    storage.burnItems.bringToLimit(itemKey)
  end)
end

local itemsBeingLimited = {}

function storage.burnItems.bringToLimit(itemKey)
  if itemsBeingLimited[itemKey] then return end
  local itemSettings = storage.burnItems.itemSettings[itemKey]
  if not itemSettings then return end
  local limit = itemSettings.limit
  if not limit then return end

  itemsBeingLimited[itemKey] = true

  while storage.items[itemKey] and storage.items[itemKey].count > limit do
    local amtToBurn = storage.items[itemKey].count - limit
    storage.burnItems.burnItem(itemKey, amtToBurn)
  end

  itemsBeingLimited[itemKey] = nil
end

function storage.burnItems.bringAllItemsToLimit()
  hook.runInHandlerContext(function()
    for itemKey in pairs(storage.burnItems.itemSettings) do
      storage.burnItems.bringToLimit(itemKey)
    end
  end)
end

function storage.burnItems.burnItemUnsafe(itemKey, amt)
  local item = storage.items[itemKey]
  local maxCount = item.detail.maxCount
  local stacksNeeded = math.ceil(amt / maxCount)
  local stacksAble = math.min(stacksNeeded, storage.burnItems.slotsLeft)

  local itemsAble = math.min(amt, stacksAble * maxCount)

  storage.dropItemTo(itemKey, itemsAble, storage.burnItems.chest)
  storage.burnItems.slotsLeft = storage.burnItems.slotsLeft - stacksAble

  storage.burnItems.checkBurnChest()
end

storage.burnItems.burnItem = storage.burnItems.withBurnAndItemLock(storage.burnItems.burnItemUnsafe)

function storage.burnItems.preInputHandler(itemKey, chest, slot, count)
  local currentCount = storage.items[itemKey] and storage.items[itemKey].count or 0
  local itemSetting = storage.burnItems.itemSettings[itemKey]
  if not itemSetting or not itemSetting.limit then return count end
  local amtToBurn = math.min((currentCount + count) - itemSetting.limit, count)

  if amtToBurn > 0 then
    if storage.burnItems.canBurnInCurrentBatch() then
      storage.burnItems.burnItemStackFromInput(chest, slot, amtToBurn)
      return count - amtToBurn
    else
      timer.create("bringItemToLimit_" .. itemKey, 0.05, 1, function()
        storage.burnItems.bringToLimit(itemKey)
      end)
    end
  end
  return count
end
