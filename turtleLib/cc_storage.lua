if not turtle then error("Library should only be run on turtles") end

local idCounter = 0
local modem = peripheral.find("modem")
local funcChannel = 12394
modem.open(funcChannel)

local storageId = nil
local enderChestId = nil

local function callRemote(functionStr, delay, ...)
  if not storageId then error("No storage id set!") end
  idCounter = idCounter + 1
  local messageId = idCounter
  local timeoutTimerId = delay and os.startTimer(delay)
  modem.transmit(funcChannel, funcChannel, {
    functionStr = functionStr,
    args = table.pack(...),
    computerID = os.getComputerID(),
    id = messageId,
    storageId = storageId
  })
  while true do
    local evt, timerId, chan, _, data = os.pullEvent()
    if evt == "modem_message" and chan == funcChannel and data.computerID == os.getComputerID() and data.id == messageId then
      if delay then os.cancelTimer(timeoutTimerId) end
      return table.unpack(data.args, 1, data.args.n)
    elseif evt == "timer" and timerId == timeoutTimerId then
      return nil
    end
  end
end

local function setStorageId(n)
  storageId = n
  if not callRemote("storage.remote.getStorageId", 0.5) then error("Couldn't find storage computer with this ID") end
end

local function setEnderChestId(n)
  if not storageId then error("Must call setStorageId before setEnderChestId") end
  enderChestId = "enderstorage:ender_chest_" .. n
  local chests = callRemote("storage.enderChest.getChestNames", 0.5)
  if not chests then error("No computer") end
  for _, chest in ipairs(chests) do
    if chest == enderChestId then return end
  end
  error("No chest with id " .. n .. " found")
end

local function placeChest()
  for k = 1, 16 do
    local itemDetail = turtle.getItemDetail(k)
    if itemDetail and itemDetail.name == "enderstorage:ender_chest" then
      turtle.select(k)
      turtle.digUp()
      turtle.placeUp()
      return k
    end
  end
  error("No enderchest found!")
end

local function pickupChest(slot)
  turtle.select(slot)
  turtle.digUp()
end

local function withTurtleLock(f, ...)
  if not callRemote("storage.enderChest.obtainTurtleLock", nil, enderChestId) then error("No such chest id") end

  local ret = table.pack(f(...))

  callRemote("storage.enderChest.releaseTurtleLock", nil, enderChestId)

  return table.unpack(ret, 1, ret.n)
end

local function withTurtleChest(f, ...)
  local selectedSlot = turtle.getSelectedSlot()

  local chestSlot = placeChest()

  local args = table.pack(...)

  turtle.select(selectedSlot)
  local ret = table.pack(withTurtleLock(function()
    return f(table.unpack(args, 1, args.n))
  end))

  pickupChest(chestSlot)

  turtle.select(selectedSlot)

  return table.unpack(ret, 1, ret.n)
end

local function inputChestBySlots(slots)
  if #slots == 0 then return end

  withTurtleChest(function()
    for _, slot in ipairs(slots) do
      turtle.select(slot)
      turtle.dropUp()
    end
  end)
end

local function toTrueMap(t)
  local out = {}
  for _, k in pairs(t) do
    out[k] = true
  end
  return out
end

local function inputChestByWhitelist(whitelist)
  local slots = {}
  local whitelistMap = toTrueMap(whitelist)
  whitelistMap["enderstorage:ender_chest"] = nil
  for k = 1, 16 do
    local itemDetail = turtle.getItemDetail(k)
    if itemDetail and whitelistMap[itemDetail.name] then
      table.insert(slots, k)
    end
  end
  inputChestBySlots(slots)
end

local function inputChestByBlacklist(blacklist)
  local slots = {}
  local blacklistMap = toTrueMap(blacklist)
  blacklistMap["enderstorage:ender_chest"] = true
  for k = 1, 16 do
    local itemDetail = turtle.getItemDetail(k)
    if itemDetail and not blacklistMap[itemDetail.name] then
      table.insert(slots, k)
    end
  end
  inputChestBySlots(slots)
end

local function inputChest()
  inputChestByBlacklist({})
end

-- takes {itemName = count}
-- returns real {itemName = count}
local function getItems(items)
  return withTurtleChest(function()
    local out = {}
    for itemName, count in pairs(items) do
      local success, realCount = callRemote("storage.enderChest.dropItem", nil, enderChestId, itemName, count)
      out[itemName] = success and realCount or 0
    end
    while turtle.suckUp() do end
    return out
  end)
end

-- returns the count
local function getItem(itemName, count)
  return getItems({[itemName] = count})[itemName]
end

return {
  setStorageId = setStorageId,
  setEnderChestId = setEnderChestId,
  inputChestBySlots = inputChestBySlots,
  inputChestByWhitelist = inputChestByWhitelist,
  inputChestByBlacklist = inputChestByBlacklist,
  inputChest = inputChest,
  getItem = getItem,
  getItems = getItems,
}
