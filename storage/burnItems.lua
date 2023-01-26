storage.burnItems = {}
storage.burnItems.slotsLeft = 27

local burningPortOut = 1564
local burningPortIn = burningPortOut + 1
storage.wiredModem.open(burningPortIn)

storage.burnItems.itemSettingsPath = "./itemSettings.txt"

-- Returns number | nil
function storage.burnItems.getItemLimit(itemKey)
  local itemSetting = storage.burnItems.itemSettings[itemKey]
  return itemSetting and itemSetting.limit
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
      return
    end
  end
  error("No burner turtle found")
end

function storage.burnItems.burnChest()
  if storage.burnItems.slotsLeft == 27 then return end
  storage.wiredModem.transmit(burningPortOut, burningPortIn, storage.burnItems.turtle.getID())
  while true do
    local _, _, port = os.pullEvent("modem_message")
    if port == burningPortIn then break end
  end
  storage.burnItems.slotsLeft = 27
end

function storage.burnItems.withBurnLock(f)
  return function(...)
    while storage.burnItems.burnLock do
      sleep(0.05)
    end
    storage.burnItems.burnLock = true
    local ret = table.pack(f(...))
    storage.burnItems.burnLock = false
    return table.unpack(ret, 1, ret.n)
  end
end

-- Starts a timer to, or immediately clears the burn chest
function storage.burnItems.checkBurnChest()
  if storage.burnItems.slotsLeft == 0 then
    storage.burnItems.burnChest()
    timer.remove("burnItems")
    return
  end
  timer.create("burnItems", 60, 1, storage.burnItems.withBurnLock(storage.burnItems.burnChest))
end

function storage.burnItems.canBurnInCurrentBatch()
  return storage.burnItems.slotsLeft > 0
end

function storage.burnItems.burnItemStackFromInputUnsafe(chest, slot, amt)
  if storage.burnItems.slotsLeft == 0 then return end
  chest.pushItems(peripheral.getName(storage.burnItems.chest, slot, amt))
  storage.burnItems.slotsLeft = storage.burnItems.slotsLeft - amt
  storage.burnItems.checkBurnChest()
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

function storage.burnItems.bringToLimit(itemKey)
  local itemSettings = storage.burnItems.itemSettings[itemKey]
  if not itemSettings then return end
  local limit = itemSettings.limit
  if not limit then return end

  while storage.items[itemKey] and storage.items[itemKey].count > limit do
    local amtToBurn = storage.items[itemKey].count - limit
    storage.burnItems.burnItem(itemKey, amtToBurn)
  end
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

storage.burnItems.burnItem = storage.burnItems.withBurnLock(storage.burnItems.burnItemUnsafe)

function storage.burnItems.preInputHandler(itemKey, chest, slot, count)
  local currentCount = storage.items[itemKey] and storage.items[itemKey].count or 0
  local itemSetting = storage.burnItems.itemSettings[itemKey]
  if not itemSetting or not itemSetting.limit then return count end
  local amtToBurn = math.max(0, (currentCount + count) - itemSetting.limit)

  if storage.burnItems.canBurnInCurrentBatch() then
    storage.burnItems.burnItemStackFromInput(chest, slot, amtToBurn)
    return count - amtToBurn
  end
  return count
end
