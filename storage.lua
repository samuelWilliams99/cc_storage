storage = {}
storage.modem = peripheral.find("modem", function(_, p) return p.isWireless() end)

require "utils.hooks"
require "utils.timer"
require "remote.shared"
require "ui.pages.pages"

if not storage.remote.isRemote then
  require "storage.items"
  require "storage.enderChest"
  require "storage.lock"
else
  require "ui.pages.remoteClientConfig"
end

require "ui.buttonList"
require "ui.text"
require "ui.pages.craftCount"
require "ui.pages.itemList"
require "ui.pages.lock"
require "ui.pages.editLock"
require "ui.pages.recipes"
require "ui.pages.configure"

storage.remote.registerFunctions()
pages.pages.configure.setupOtherPages()

if not storage.remote.isRemote then
  storage.crafting.pingCrafters()
  storage.updateChests()
  storage.updateItemMapping()
  storage.crafting.loadRecipes()
  storage.crafting.setupCrafters()
  storage.enderChest.loadChests()
  print("Rendering...")
  sleep(1)
else
  storage.remote.readClientChestName()
  storage.remote.setupItems()
end

hook.add("initialize", "testing", function()
  if not storage.remote.isRemote and storage.lock.getEnabled() then
    pages.setPage("lock")
    return
  end

  if storage.remote.isRemote and not storage.remote.clientChestName then
    pages.setPage("remoteClientConfig")
  else
    pages.setPage("itemList")
  end
end)

hook.add("terminate", "clear_screen", function()
  if pages.pages.lock.active then return end
  term.clear()
  term.setCursorPos(1,1)
end)

hook.setPreError(function(event, handlerName, err, stack)
  term.clear()
  term.setCursorPos(1,1)
  print("CC_Storage terminated - the following error occured and has been written to logs.txt:")
  print("(Just reboot the computer and let Sam know so he can take a look)")
  local logs = readFile("logs.txt") or {}
  table.insert(logs, {time = os.date(), event = event, handlerName = handlerName, err = err, stack = stack})
  writeFile("logs.txt", logs)
end)

if not storage.remote.isRemote then
  storage.startLockTimer()
  storage.enderChest.startInputTimer()
  storage.startInputTimer()
end

hook.runLoop()
