require "ui.pages.pages"

local remoteClientConfigPage = {
  title = "Remote Client Config",
  configName = "Remote Client Config"
}

local w, h = term.getSize()

pages.addPage("remoteClientConfig", remoteClientConfigPage)

local lineX = 2 + math.floor((w - 4) * 0.5)
local centLeft = 2 + math.floor((w - 4) * 0.25)
local centRight = 2 + math.floor((w - 4) * 0.75)

function remoteClientConfigPage.updateActiveButton()
  if not remoteClientConfigPage.pauseButton then return end
  local paused = remoteClientConfigPage.pauseButton.paused
  local text = paused and "Paused" or "Unpaused"
  remoteClientConfigPage.pauseButton:setBgColor(paused and colors.red or colors.green)
  remoteClientConfigPage.pauseButton:setText(text)
  remoteClientConfigPage.pauseButton:setTextDrawPos(math.floor((remoteClientConfigPage.pauseButton.size.x - #text) / 2), 1)
  remoteClientConfigPage.pauseButton:invalidateLayout(true)
end

function remoteClientConfigPage.updateActiveButtonRemote()
  if not remoteClientConfigPage.pauseButton then return end
  local paused = storage.enderChest.isChestPaused(storage.remote.clientChestName)
  remoteClientConfigPage.pauseButton.paused = paused
  remoteClientConfigPage.updateActiveButton()
end

function remoteClientConfigPage.addBackAndActive()
  remoteClientConfigPage.backButton = pages.addBackButton(remoteClientConfigPage)

  remoteClientConfigPage.pauseButton = pages.elem(ui.text.create())
  remoteClientConfigPage.pauseButton:setPos(lineX + 1, h - 4)
  remoteClientConfigPage.pauseButton:setSize(w - lineX - 3, 3)
  remoteClientConfigPage.pauseButton:setTextDrawPos(3, 1)

  remoteClientConfigPage.updateActiveButtonRemote()

  function remoteClientConfigPage.pauseButton:onClick()
    self.paused = not self.paused
    storage.enderChest.setChestPaused(storage.remote.clientChestName, self.paused)
    remoteClientConfigPage.updateActiveButton()
  end
end

function remoteClientConfigPage.removeBackAndActive()
  if remoteClientConfigPage.backButton then
    remoteClientConfigPage.backButton:remove()
    remoteClientConfigPage.backButton = nil
  end
  if remoteClientConfigPage.pauseButton then
    remoteClientConfigPage.pauseButton:remove()
    remoteClientConfigPage.pauseButton = nil
  end
end

function remoteClientConfigPage.pingStorageIds()
  remoteClientConfigPage.pinging = true
  if remoteClientConfigPage.storageIdList then
    remoteClientConfigPage.storageIdList:remove()
    remoteClientConfigPage.storageIdList = nil
  end
  
  local function writeText(text)
    term.setTextColor(colors.gray)
    term.setCursorPos(math.floor(centLeft - #text / 2), math.floor(h / 2))
    term.write(text)
    term.setTextColor(colors.white)
  end

  writeText("Pinging storage devices...")

  local storageIds = storage.remote.getStorageIds()

  if table.isEmpty(storageIds) then
    writeText(" No storage devices found ")
    storage.remote.setStorageId(nil)
    storage.remote.setClientChestName(nil)
    remoteClientConfigPage.removeBackAndActive()
    remoteClientConfigPage.updateChestList()
    remoteClientConfigPage.pinging = false
    return
  end

  remoteClientConfigPage.storageIdList = pages.elem(ui.buttonListPaged.create())
  remoteClientConfigPage.storageIdList:setPos(2, 5)
  remoteClientConfigPage.storageIdList:setSize(lineX - 4, h - 10)
  remoteClientConfigPage.storageIdList:setHeader("Storage IDs")

  local function updateOptions()
    local options = {}
    local found = false
    for i, storageData in ipairs(storageIds) do
      local connected = storageData.id == storage.remote.storageId
      if connected then found = true end
      options[i] = {
        id = storageData.id,
        displayText = storageData.label or tostring(storageData.id),
        hasLabel = storageData.label and true or false,
        bgColor = connected and colors.blue or nil
      }
    end
    table.sort(options, function(a, b) 
      return sequenceCompares(true, {
        {a.hasLabel, b.hasLabel},
        {a.displayText, b.displayText}
      })
    end)
    remoteClientConfigPage.storageIdList:setOptions(options)
    return found
  end
  local found = updateOptions()

  if storage.remote.storageId and not found then
    storage.remote.setStorageId(nil)
    storage.remote.setClientChestName(nil)
    remoteClientConfigPage.removeBackAndActive()
  end

  function remoteClientConfigPage.storageIdList:handleClick(_, data)
    if data.id == storage.remote.storageId then return end
    storage.remote.setStorageId(data.id)
    storage.remote.setClientChestName(nil)
    remoteClientConfigPage.removeBackAndActive()
    updateOptions()
    remoteClientConfigPage.updateChestList()
  end

  remoteClientConfigPage.updateChestList()
  remoteClientConfigPage.pinging = false
end

function remoteClientConfigPage.updateChestList()
  if not storage.remote.storageId then
    if remoteClientConfigPage.enderChestList then
      remoteClientConfigPage.enderChestList:remove()
      remoteClientConfigPage.enderChestList = nil
    end
    remoteClientConfigPage.removeBackAndActive()
    return
  end

  local enderChests = storage.enderChest.getChestNames()

  remoteClientConfigPage.enderChestList = pages.elem(ui.buttonListPaged.create())
  remoteClientConfigPage.enderChestList:setPos(lineX + 1, 5)
  remoteClientConfigPage.enderChestList:setSize(w - 3 - lineX, h - 10)
  remoteClientConfigPage.enderChestList:setHeader("Ender Chest Names")

  local function getChestNumber(str)
    return tonumber(str:sub(26))
  end

  local function updateList()
    local options = {}
    for i, chestName in ipairs(enderChests) do
      options[i] = {
        displayText = chestName,
        bgColor = chestName == storage.remote.clientChestName and colors.blue or nil,
        chestNumber = getChestNumber(chestName)
      }
    end
    table.sort(options, function(a, b) return a.chestNumber < b.chestNumber end)
    remoteClientConfigPage.enderChestList:setOptions(options)
  end
  updateList()

  function remoteClientConfigPage.enderChestList:handleClick(_, data)
    local wasNil = storage.remote.clientChestName == nil
    storage.remote.setClientChestName(data.displayText)
    remoteClientConfigPage.updateActiveButtonRemote()

    updateList()
    if wasNil then
      remoteClientConfigPage.addBackAndActive()
    end
  end

  hook.add("cc_enderchest_change", "update_menu", function(_enderChests)
    enderChests = _enderChests
    updateList()
  end)
end

function remoteClientConfigPage.setup()
  -- Vertical line
  term.setTextColor(colors.gray)
  for y = 5, h - 1 do
    term.setCursorPos(lineX, y)
    term.write("|")
  end
  term.setTextColor(colors.white)

  remoteClientConfigPage.pingStorageIds()

  local refreshButton = pages.elem(ui.text.create())
  local refreshText = "Refresh"
  refreshButton:setPos(lineX - 2 - #refreshText - 6, h - 4)
  refreshButton:setSize(6 + #refreshText, 3)
  refreshButton:setTextDrawPos(3, 1)
  refreshButton:setText(refreshText)
  function refreshButton:onClick()
    if remoteClientConfigPage.pinging then return end
    remoteClientConfigPage.pingStorageIds()
  end

  if storage.remote.storageId and storage.remote.clientChestName then
    remoteClientConfigPage.addBackAndActive()
  end
end

function remoteClientConfigPage.cleanup()
  hook.remove("cc_enderchest_change", "update_menu")
  remoteClientConfigPage.storageIdList = nil
  remoteClientConfigPage.enderChestList = nil
  remoteClientConfigPage.backButton = nil
  remoteClientConfigPage.pinging = nil
  remoteClientConfigPage.pauseButton = nil
end
