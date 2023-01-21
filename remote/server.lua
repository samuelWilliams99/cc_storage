local sharedFuncs = {}

local function getValue(names)
  local pos = _ENV
  for _, name in ipairs(names) do
    pos = pos[name]
  end
  return pos
end

function storage.remote.sharedFunctionServer(names, functionStr)
  sharedFuncs[functionStr] = getValue(names)
end

hook.add("modem_message", "remote_function_handler", function(_, chan, _, data)
  if chan ~= storage.remote.funcChannel then return end
  local f = sharedFuncs[data.functionStr]
  if not f then return end
  local ret = table.pack(f(table.unpack(data.args)))
  storage.modem.transmit(storage.remote.funcChannel, storage.remote.funcChannel, {computerID = data.computerID, id = data.id, args = ret})
end)

function storage.remote.sharedHookServer(hookName)
  hook.add(hookName, "remote_forwarder", function(...)
    storage.modem.transmit(storage.remote.hookChannel, storage.remote.hookChannel, {hookName = hookName, args = table.pack(...)})
  end)
end

-- Simplifies an item in the cheapest way, removing locations and non-required fields from detail
-- Note _not_ using table.shallowCopy and removing, as thats less efficient, and we expect to run this function a _lot_
function storage.remote.simplifyItem(item)
  return {
    count = item.count,
    reservedCount = item.reservedCount,
    key = item.key,
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
local function sendBatch()
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
  timer.create("cc_item_batch_burst", 0.1, 1, sendBatch)
  if not timer.exists("cc_item_batch_cap") then
    timer.create("cc_item_batch_cap", 0.5, 1, sendBatch)
  end
end)
