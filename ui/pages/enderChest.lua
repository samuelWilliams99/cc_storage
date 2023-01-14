require "ui.pages.pages"

local enderChestPage = {
  shouldMakeBackButton = true,
  title = "Ender Chest Manager",
  configName = "Ender Chest Manager"
}

pages.addPage("enderChest", enderChestPage)

local w, h = term.getSize()

function enderChestPage.setup()
  local chestList = pages.elem(ui.buttonList.create())
  chestList:setPos(2, 5)
  chestList:setSize(w - 4, h - 11)

  local function updateChestList()
    local options = {}

    local function addChest(chestName, chestConfig, connected)
      local bgColor = nil
      if chestConfig and chestConfig.type == "input" then
        bgColor = colors.blue
      end

      local displayText = chestName
      if not connected then
        displayText = displayText .. " [DISCONNECTED]"
      end

      table.insert(options, {displayText = displayText, chestName = chestName, bgColor = bgColor})
    end

    local seenNames = {}
    for _, chest in ipairs(storage.enderChest.chests) do
      local chestName = peripheral.getName(chest)
      seenNames[chestName] = true
      local chestConfig = storage.enderChest.config[chestName]
      addChest(chestName, chestConfig, true)
    end
    for chestName, chestConfig in pairs(storage.enderChest.config) do
      if not seenNames[chestName] then
        addChest(chestName, chestConfig, false)
      end
    end
    chestList:setOptions(options)
  end
  updateChestList()

  function chestList:handleClick(_, data)
    local chestName = data.chestName
    local chestConfig = storage.enderChest.config[chestName]
    if not chestConfig then
      storage.enderChest.config[chestName] = {type = "input"}
    else
      storage.enderChest.config[chestName] = nil
    end
    storage.enderChest.saveConfig()
    storage.enderChest.reloadChests()
    updateChestList()
  end
  
  hook.add("ender_chest_change", "update_ui", updateChestList)
end

function enderChestPage.cleanup()
  hook.remove("ender_chest_change", "update_ui")
end