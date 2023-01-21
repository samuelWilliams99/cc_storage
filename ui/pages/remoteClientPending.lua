require "ui.pages.pages"

local remoteClientPendingPage = {}

local w, h = term.getSize()

pages.addPage("remoteClientPending", remoteClientPendingPage)

function remoteClientPendingPage.setup()
  local text = "Waiting for storage computer to come online..."
  term.setCursorPos(math.floor(w / 2 - #text / 2) + 1, math.floor(h / 2))
  term.setTextColor(colors.gray)
  term.write(text)
  term.setTextColor(colors.white)

  local configText = "Connect to different storage device"
  local configButton = pages.elem(ui.text.create())
  configButton:setPos(math.floor(w / 2 - #configText / 2 - 3), math.floor(h / 2) + 3)
  configButton:setSize(6 + #configText, 3)
  configButton:setTextDrawPos(3, 1)
  configButton:setText(configText)
  function configButton:onClick()
    storage.remote.setStorageId(nil)
    storage.remote.pendingConnection = false
    pages.setPage("remoteClientConfig")
  end

  timer.create("cc_storage_client_ping", 3, 0, function()
    if storage.remote.storageIdExists() then
      -- above request takes 1 second, someone could press the config button in that time
      if not remoteClientPendingPage.active then return end
      storage.remote.pendingConnection = false
      storage.remote.setupItems()
      storage.remote.readClientChestName()
      if storage.remote.clientChestName then
        pages.setPage("itemList")
      else
        pages.setPage("remoteClientConfig")
      end
    end
  end)
end

function remoteClientPendingPage.cleanup()
  timer.remove("cc_storage_client_ping")
end
