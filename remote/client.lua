local function setValue(names, val)
  local pos = _ENV
  for k = 1, #names - 1 do
    if not pos[names[k]] then pos[names[k]] = {} end
    pos = pos[names[k]]
  end
  pos[names[#names]] = val
end

local idCounter = 0

function storage.remote.sharedFunctionClient(names, functionStr)
  setValue(names, function(...)
    idCounter = idCounter + 1
    local timeoutTimerId = os.startTimer(5)
    -- Note, we cannot transmit functions, so any function with a callback will not work
    -- We _could_ implement this support, but this is a lot of back and forth
    -- For now, we see if we can live without :)
    storage.modem.transmit(storage.remote.funcChannel, storage.remote.funcChannel, {functionStr = functionStr, args = table.pack(...), computerID = os.getComputerID(), id = idCounter})
    while true do
      local evt, timerId, chan, _, data = os.pullEvent()
      if evt == "modem_message" and chan == storage.remote.funcChannel and data.computerID == os.getComputerID() and data.id == idCounter then
        return table.unpack(data.args, 1, data.args.n)
      elseif evt == "timer" and timerId == timeoutTimerId then
        error("Message timed out :(")
      end
    end
  end)
end

function storage.remote.dropItem(key, count)
  return storage.enderChest.dropItem(storage.remote.clientChestName, key, count)
end

hook.add("modem_message", "remote_hook_handler", function(_, chan, _, data)
  if chan ~= storage.remote.hookChannel then return end
  hook.run(data.hookName, table.unpack(data.args, 1, data.args.n))
end)

function storage.remote.readClientChestName()
  local chestName = settings.get("cc_client_chest_name")
  if not chestName then return end
  if storage.enderChest.chestExists(chestName) then
    storage.remote.clientChestName = chestName
  else
    settings.unset("cc_client_chest_name")
    settings.save()
  end
end

function storage.remote.setClientChestName(chestName)
  storage.remote.clientChestName = chestName
  settings.set("cc_client_chest_name", chestName)
  settings.save()
end

hook.add("cc_enderchest_change", "check_valid", function(enderChests)
  if not storage.remote.clientChestName then return end
  if not table.contains(enderChests, storage.remote.clientChestName) then
    storage.remote.clientChestName = nil
    settings.unset("cc_client_chest_name")
    settings.save()
    pages.setPage("remoteClientConfig")
  end
end)

function storage.remote.setupItems()
  storage.items, storage.emptySlotCount = storage.remote.getItems()
end

hook.add("cc_storage_change_item_batched", "client_update_items", function(batch)
  for key, item in pairs(batch) do
    if item.removed then
      storage.items[key] = nil
    else
      storage.items[key] = item
    end
  end
  hook.run("cc_storage_change")
end)
