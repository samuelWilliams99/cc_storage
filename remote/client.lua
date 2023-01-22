local function setValue(names, val)
  local pos = _ENV
  for k = 1, #names - 1 do
    if not pos[names[k]] then pos[names[k]] = {} end
    pos = pos[names[k]]
  end
  pos[names[#names]] = val
end

local idCounter = 0

local relayDelayBuffer = 0.5

function storage.remote.sharedFunctionClient(names, functionStr)
  setValue(names, function(...)
    idCounter = idCounter + 1
    local timeoutTimerId = os.startTimer(relayDelayBuffer)
    -- Note, we cannot transmit functions, so any function with a callback will not work
    -- We _could_ implement this support, but this is a lot of back and forth
    -- For now, we see if we can live without :)
    storage.wirelessModem.transmit(storage.remote.funcChannel, storage.remote.funcChannel, {
      functionStr = functionStr,
      args = table.pack(...),
      computerID = os.getComputerID(),
      id = idCounter,
      storageId = storage.remote.storageId
    })
    while true do
      local evt, timerId, chan, _, data = os.pullEvent()
      if evt == "modem_message" and chan == storage.remote.funcChannel and data.computerID == os.getComputerID() and data.id == idCounter then
        return table.unpack(data.args, 1, data.args.n)
      elseif evt == "timer" and timerId == timeoutTimerId then
        os.reboot()
      end
    end
  end)
end

-- returns list of {id = computerId, label = computerLabel | nil}
function storage.remote.getStorageIds()
  idCounter = idCounter + 1
  local timeoutTimerId = os.startTimer(relayDelayBuffer)

  local storageIds = {}
  storage.wirelessModem.transmit(storage.remote.funcChannel, storage.remote.funcChannel, {functionStr = "storage.remote.getStorageId", args = {}, computerID = os.getComputerID(), id = idCounter})
  while true do
    local evt, timerId, chan, _, data = os.pullEvent()
    if evt == "modem_message" and chan == storage.remote.funcChannel and data.computerID == os.getComputerID() and data.id == idCounter then
      if data.args[1] then
        table.insert(storageIds, data.args[1])
      end
    elseif evt == "timer" and timerId == timeoutTimerId then
      return storageIds
    end
  end
end

function storage.remote.dropItem(key, count)
  return storage.enderChest.dropItem(storage.remote.clientChestName, key, count)
end

hook.add("modem_message", "remote_hook_handler", function(_, chan, _, data)
  if chan ~= storage.remote.hookChannel then return end
  if storage.remote.pendingConnection then return end
  if data.storageId ~= storage.remote.storageId then return end
  hook.run(data.hookName, table.unpack(data.args, 1, data.args.n))
end)

function storage.remote.storageIdExists()
  local storageIds = storage.remote.getStorageIds()

  local idExists = false
  for _, storageData in ipairs(storageIds) do
    if storageData.id == storage.remote.storageId then
      idExists = true
      break
    end
  end

  return idExists
end

function storage.remote.setStorageId(id)
  if storage.remote.storageId and not storage.remote.pendingConnection then
    storage.remote.transmitDisconnected()
  end

  storage.remote.storageId = id
  if id then
    settings.set("cc_client_storage_id", id)
  else
    settings.unset("cc_client_storage_id")
  end
  settings.save()
  storage.remote.transmitConnected()
  storage.remote.setupItems()
end

function storage.remote.readClientChestName()
  local chestName = settings.get("cc_client_chest_name")
  if storage.enderChest.chestExists(chestName) then
    storage.remote.clientChestName = chestName
  else
    settings.unset("cc_client_chest_name")
    settings.save()
  end
end

function storage.remote.readClientConnectionData()
  local storageId = settings.get("cc_client_storage_id")
  if not storageId then return end
  print("Pinging storage devices...")
  storage.remote.storageId = storageId
  
  if not storage.remote.storageIdExists() then
    storage.remote.pendingConnection = true
    return
  end

  storage.remote.transmitConnected()
  storage.remote.readClientChestName()
end

function storage.remote.setClientChestName(chestName)
  storage.remote.clientChestName = chestName
  if chestName then
    settings.set("cc_client_chest_name", chestName)
  else
    settings.unset("cc_client_chest_name")
  end
  settings.save()
end

hook.add("cc_enderchest_change", "check_valid", function(enderChests)
  if not storage.remote.clientChestName then return end
  if not table.contains(enderChests, storage.remote.clientChestName) then
    storage.remote.setClientChestName(nil)
    pages.setPage("remoteClientConfig")
  end
end)

function storage.remote.setupItems()
  storage.items, storage.emptySlotCount = storage.remote.getItems()
end

hook.add("cc_storage_change_item_batched", "client_update_items", function(batch, emptySlotCount)
  storage.emptySlotCount = emptySlotCount
  for key, item in pairs(batch) do
    if item.removed then
      storage.items[key] = nil
    else
      storage.items[key] = item
    end
  end
  hook.run("cc_storage_change")
end)

hook.add("cc_initialize", "reboot_on_init", os.reboot)

timer.create("cc_server_ping", 2, 0, function()
  if storage.remote.storageId and not storage.remote.pendingConnection then
    storage.remote.transmitPing()
  end
end)
