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

function storage.enderChest.dropItem(chestName, key, count)
  local chestData = storage.enderChest.chests[chestName]
  if not chestData then return false, "No such chest" end
  while chestData.inputting do
    sleep(0.05)
  end
  chestData.itemPaused = true
  storage.dropItemTo(key, count, chestData.chest)
  return true
end

function storage.enderChest.pauseChest(chestName, unpause)
  local chestData = storage.enderChest.chests[chestName]
  if not chestData then return false, "No such chest" end
  chestData.fullPaused = not unpause
end

function storage.enderChest.unpauseChest(chestName)
  return storage.enderChest.pauseChest(chestName, true)
end

local function inputChest(chestData)
  local items = chestData.chest:list()
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

function storage.enderChest.startInputTimer()
  timer.create("inputEnderChests", 0.5, 0, function()
    for _, chestData in pairs(storage.enderChest.chests) do
      chestData.inputting = true
      inputChest(chestData)
      chestData.inputting = false
    end
  end)
end

function storage.enderChest.peripheralChange(peripheralName)
  if not peripheralName:startsWith("enderstorage:ender_chest_") then return end
  storage.enderChest.loadChests()
end

hook.add("peripheral", "enderChestAttach", storage.enderChest.peripheralChange)
hook.add("peripheral_detach", "enderChestAttach", storage.enderChest.peripheralChange)
