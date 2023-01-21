require "ui.pages.pages"

local remoteClientConfigPage = {
  title = "Remote Client Config",
  configName = "Remote Client Config"
}

local w, h = term.getSize()

-- TODO add manual chest lock button

pages.addPage("remoteClientConfig", remoteClientConfigPage)

function remoteClientConfigPage.setup()
  local enderChests = storage.enderChest.getChestNames()

  if storage.remote.clientChestName then
    pages.addBackButton(remoteClientConfigPage)
  end

  local enderChestList = pages.elem(ui.buttonListPaged.create())
  enderChestList:setPos(2, 5)
  enderChestList:setSize(w - 4, h - 10)

  local function updateList()
    local options = {}
    for i, chestName in ipairs(enderChests) do
      options[i] = {displayText = chestName, bgColor = chestName == storage.remote.clientChestName and colors.blue or nil}
    end
    enderChestList:setOptions(options)
  end
  updateList()

  function enderChestList:handleClick(_, data)
    local wasNil = storage.remote.clientChestName == nil
    storage.remote.setClientChestName(data.displayText)

    updateList()
    if wasNil then
      pages.addBackButton(remoteClientConfigPage)
    end
  end

  hook.add("cc_enderchest_change", "update_menu", function(_enderChests)
    enderChests = _enderChests
    updateList()
  end)
end

function remoteClientConfigPage.cleanup()
  hook.remove("cc_enderchest_change", "update_menu")
end
