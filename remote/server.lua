local sharedFuncs = {}

local function getValue(names)
  local pos = _ENV
  for _, name in ipairs(names) do
    pos = pos[name]
  end
  return pos
end

function storage.remote.sharedFunctionServer(names, functionStr, giveClientId)
  sharedFuncs[functionStr] = {func = getValue(names), giveClientId = giveClientId}
end

hook.add("modem_message", "remote_function_handler", function(_, chan, _, data)
  if chan ~= storage.remote.funcChannel then return end
  if data.storageId and data.storageId ~= os.getComputerID() then return end
  local functionData = sharedFuncs[data.functionStr]
  if not functionData then return end
  local ret
  if functionData.giveClientId then
    ret = table.pack(functionData.func(data.computerID, table.unpack(data.args, 1, data.args.n)))
  else
    ret = table.pack(functionData.func(table.unpack(data.args, 1, data.args.n)))
  end
  storage.wirelessModem.transmit(storage.remote.funcChannel, storage.remote.funcChannel, {computerID = data.computerID, id = data.id, args = ret})
end)

function storage.remote.sharedHookServer(hookName)
  if storage.wirelessModem then
    hook.add(hookName, "remote_forwarder", function(...)
      storage.wirelessModem.transmit(storage.remote.hookChannel, storage.remote.hookChannel, {hookName = hookName, args = table.pack(...), storageId = os.getComputerID()})
    end)
  end
end

function storage.remote.getStorageId()
  if table.isEmpty(storage.enderChest.chests) then return end
  return {id = os.getComputerID(), label = os.getComputerLabel()}
end

-- Simplifies an item in the cheapest way, removing locations and non-required fields from detail
-- Note _not_ using table.shallowCopy and removing, as thats less efficient, and we expect to run this function a _lot_
function storage.remote.simplifyItem(item)
  return {
    count = item.count,
    reservedCount = item.reservedCount,
    key = item.key,
    modName = item.modName,
    detail = {
      displayName = item.detail.displayName,
      maxCount = item.detail.maxCount,
      damage = item.detail.damage,
      maxDamage = item.detail.maxDamage,
      enchantments = item.detail.enchantments,
      nbt = item.detail.nbt
    }
  }
end

-- Returns simplified items and empty slot count
function storage.remote.getItems()
  local storageSimplified = {}
  for itemKey, item in pairs(storage.items) do
    storageSimplified[itemKey] = storage.remote.simplifyItem(item)
  end
  return storageSimplified, storage.emptySlotCount
end

-- cc_storage_change_item_batched hook gives both batched change and new empty slot count

local batchKeys = {}
local emptyItem = {removed = true}
function storage.remote.sendItemChangeBatch()
  if table.isEmpty(batchKeys) then return end
  local batch = {}
  for _, key in ipairs(batchKeys) do
    local item = storage.items[key]
    if item then
      batch[key] = storage.remote.simplifyItem(storage.items[key])
    else
      batch[key] = emptyItem
    end
  end
  hook.run("cc_storage_change_item_batched", batch, storage.emptySlotCount)
  batchKeys = {}
  timer.remove("cc_item_batch_burst")
end

hook.add("cc_storage_change_item", "remote_batching", function(key)
  table.insert(batchKeys, key)
  timer.create("cc_item_batch_burst", 0.1, 1, storage.remote.sendItemChangeBatch)
  if not timer.exists("cc_item_batch_cap") then
    timer.create("cc_item_batch_cap", 0.5, 1, storage.remote.sendItemChangeBatch)
  end
end)

local clients = {}

function storage.remote.transmitConnected(computerId)
  if clients[computerId] then
    storage.remote.transmitDisconnected(computerId)
  end
  clients[computerId] = {lastPing = os.unixTime()}
  hook.run("cc_client_connect", computerId)
end

-- Expect the client to call this every 2 seconds, if nothing after 5s, disconnect them
function storage.remote.transmitPing(computerId)
  if not clients[computerId] then
    storage.remote.transmitConnected(computerId)
  else
    clients[computerId].lastPing = os.unixTime()
  end
end

function storage.remote.transmitDisconnected(computerId)
  if not clients[computerId] then return end
  clients[computerId] = nil
  hook.run("cc_client_disconnect", computerId)
end

function storage.remote.startClientTimeoutTimer()
  timer.create("cc_client_timeout", 1, 0, function()
    local time = os.unixTime()
    local clientIds = table.keys(clients)
    for _, computerId in ipairs(clientIds) do
      local clientData = clients[computerId]
      if time - clientData.lastPing > 5 then
        storage.remote.transmitDisconnected(computerId)
      end
    end
  end)
end
