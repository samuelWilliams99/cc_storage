require "utils.helpers"

storage.enderChest = {}

local function avoidSides(name)
  if name:find("_") then return true end
end

function storage.enderChest.loadChests()
  storage.enderChest.chests = {}
  for _, chest in ipairs({peripheral.find("enderstorage:ender_chest", avoidSides)}) do
    storage.enderChest.chests[peripheral.getName(chest)] = {
      chest = chest,
      itemPaused = false,
      fullPaused = false,
      inputting = false
    }
  end
end

function storage.enderChest.getChestNames()
  return table.keys(storage.enderChest.chests)
end

function storage.enderChest.chestExists(chestName)
  return storage.enderChest.chests[chestName] and true or false
end

function storage.enderChest.isChestPaused(chestName)
  return (storage.enderChest.chests[chestName] or {fullPaused = false}).fullPaused
end

local function runLocked(chestData, f, ...)
  while chestData.inputting do
    sleep(0.05)
  end

  chestData.inputting = true
  local ret = table.pack(f(chestData, ...))
  chestData.inputting = false
  return table.unpack(ret, 1, ret.n)
end

function storage.enderChest.obtainTurtleLock(chestName)
  local chestData = storage.enderChest.chests[chestName]
  if not chestData then return false, "No such chest" end

  while chestData.turtleLock do
    sleep(0.5)
  end

  chestData.turtleLock = true

  timer.create("autoReleaseTurtleLock" .. chestName, 10, 1, function()
    storage.enderChest.releaseTurtleLock(chestName)
  end)
  return true
end

function storage.enderChest.dropItem(chestName, key, count)
  local chestData = storage.enderChest.chests[chestName]
  if not chestData then return false, "No such chest" end

  local success, realCount = runLocked(chestData, function()
    local oldFulledPaused = chestData.fullPaused
    -- Do a full pause while items are being moved into the chest, then switch to itemPause
    chestData.fullPaused = true
    local success, realCount = storage.dropItemTo(key, count, chestData.chest)
    chestData.fullPaused = oldFulledPaused
    chestData.itemPaused = true
    return success, realCount
  end)

  return true, success and realCount or 0
end

function storage.enderChest.itemPauseChest(chestName)
  local chestData = storage.enderChest.chests[chestName]
  if not chestData then return false, "No such chest" end
  chestData.itemPaused = true
end

function storage.enderChest.setChestPaused(chestName, paused)
  local chestData = storage.enderChest.chests[chestName]
  if not chestData then return false, "No such chest" end
  chestData.fullPaused = paused
end

function storage.enderChest.pauseChest(chestName)
  return storage.enderChest.setChestPaused(chestName, true)
end

function storage.enderChest.unpauseChest(chestName)
  return storage.enderChest.setChestPaused(chestName, false)
end

local function inputChest(chestData)
  local items = chestData.chest:list()
  if not items then return end
  if chestData.itemPaused then
    if table.isEmpty(items) then
      chestData.itemPaused = false
    else
      return
    end
  end
  if chestData.fullPaused then return end
  storage.inputChest(chestData.chest, false, items)
end

function storage.enderChest.releaseTurtleLock(chestName)
  local chestData = storage.enderChest.chests[chestName]
  if not chestData then return false, "No such chest" end

  timer.remove("autoReleaseTurtleLock" .. chestName)
  chestData.turtleLock = false
  chestData.itemPaused = false
  inputChest(chestData)
end

function storage.enderChest.startInputTimer()
  timer.create("inputEnderChests", 0.5, 0, function()
    for _, chestData in pairs(storage.enderChest.chests) do
      runLocked(chestData, inputChest)
    end
  end)
end

function storage.enderChest.peripheralChange(peripheralName)
  if not peripheralName:startsWith("enderstorage:ender_chest_") then return end
  storage.enderChest.loadChests()
  hook.run("cc_enderchest_change", storage.enderChest.getChestNames())
end

hook.add("peripheral", "enderChestAttach", storage.enderChest.peripheralChange)
hook.add("peripheral_detach", "enderChestAttach", storage.enderChest.peripheralChange)
