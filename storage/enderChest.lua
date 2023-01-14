require "utils.helpers"

storage.enderChest = {}
storage.enderChest.configPath = "enderChests.txt"

local function avoidSides(name)
  if name:find("") then return true end
end

--[[
format
key = peripheral name
value = {
  type = "input" | "terminal"
  computerId = id of pocket if terminal
}
}
]]
function storage.enderChest.loadConfig()
  storage.enderChest.config = readFile(storage.enderChest.configPath) or {}
end

function storage.enderChest.saveConfig()
  writeFile(storage.enderChest.configPath, storage.enderChest.config or {})
end

function storage.enderChest.reloadChests()
  storage.enderChest.chests = {peripheral.find("enderstorage:ender_chest", avoidSides)}
  storage.enderChest.inputChests = {}
  for _, chest in pairs(storage.enderChest.chests) do
    local chestName = peripheral.getName(chest)
    local chestConfig = storage.enderChest.config[chestName]
    if chestConfig and chestConfig.type == "input" then
      table.insert(storage.enderChest.inputChests, chest)
    end
  end
end

function storage.enderChest.setup()
  storage.enderChest.loadConfig()
  storage.enderChest.reloadChests()
end

function storage.enderChest.startInputTimer()
  timer.create("inputEnderChest", 0.5, 0, function()
    for _, chest in ipairs(storage.enderChest.inputChests) do
      storage.inputChest(chest)
    end
  end)
end

function storage.enderChest.peripheralChange(peripheralName)
  if not peripheralName:startsWith("enderstorage:ender_chest_") then return end
  storage.enderChest.reloadChests()
  hook.run("ender_chest_change")
end

hook.add("peripheral", "enderChestAttach", storage.enderChest.peripheralChange)
hook.add("peripheral_detach", "enderChestAttach", storage.enderChest.peripheralChange)
