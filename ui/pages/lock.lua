require "ui.pages.pages"
require "utils.helpers"

local playerDetector = peripheral.find("playerDetector")
if not playerDetector then error("No player detector found, please connect one to the computer to use") end

local lockPage = {}
local editLockPage = {}

pages.addPage("lock", lockPage)
pages.addPage("editLock", editLockPage)

local w, h = term.getSize()

local authorisedPlayers = readFile("users.txt") or {}

storage.lockPageEnabled = #authorisedPlayers > 0

local function savePlayers()
  writeFile("users.txt", authorisedPlayers)
end

hook.add("playerClick", "lockUnlockAttempt", function(playerName)
  if table.contains(authorisedPlayers, playerName) and storage.lockPageEnabled then
    pages.setPage(lockPage.active and "itemList" or "lock")
  end
end)

timer.create("autolock", 5, 0, function()
  if lockPage.active or not storage.lockPageEnabled then return end
  local plys = playerDetector.getPlayersInRange(5)
  local foundPlayer = false
  for _, ply in pairs(plys) do
    if table.contains(authorisedPlayers, ply) then
      foundPlayer = true
    end
  end
  if not foundPlayer then
    pages.setPage("lock")
  end
end)

function lockPage.setup()
  hook.add("terminate", "preventTerminate", function()
    return true
  end)

  local text = "Awaiting fingerprint..."
  term.setCursorPos(math.floor(w / 2 - #text / 2), math.floor(h / 2))
  term.setTextColor(colors.gray)
  term.write(text)
  term.setTextColor(colors.white)
end

function lockPage.cleanup()
  hook.remove("terminate", "preventTerminate")
end

local function addElem(elem)
  table.insert(editLockPage.elems, elem)
  return elem
end

function editLockPage.setup()
  editLockPage.elems = {}

  local backButton = addElem(ui.text.create())
  backButton:setPos(2, h - 4)
  backButton:setSize(10, 3)
  backButton:setTextDrawPos(3, 1)
  backButton:setText("Back")
  function backButton:onClick()
    pages.setPage("itemList")
  end

  -- Main title
  local titleText = "Lock Manager"
  term.setCursorPos(math.floor(w / 2 - #titleText / 2), 2)
  term.write(titleText)

  -- Horizontal line
  term.setTextColor(colors.gray)
  term.setCursorPos(3, 4)
  term.write(string.rep("_", w - 4))

  -- left title
  local midLeftX = 2 + math.floor((w - 4) * 0.25)
  local leftTitleText = "Authorised players"
  term.setCursorPos(math.ceil(midLeftX - #leftTitleText / 2), 6)
  term.write(leftTitleText)

  local midX = math.floor(w * 0.5)

  local authList = addElem(ui.buttonList.create())
  authList:setPos(2, 7)
  authList:setSize(midX - 4, h - 13)

  -- right title
  local midRightX = 2 + math.floor((w - 4) * 0.75)
  local rightTitleText = "Unauthorised players"
  term.setCursorPos(math.ceil(midRightX - #rightTitleText / 2), 6)
  term.write(rightTitleText)

  local unauthList = addElem(ui.buttonList.create())
  unauthList:setPos(midX + 2, 7)
  unauthList:setSize(midX - 4, h - 13)

  local function updateLists()
    local onlinePlys = 
    local allPlys = {}
    for _, ply in ipairs(playerDetector.getOnlinePlayers() or {}) do
      allPlys[ply] = false
    end
    for _, ply in ipairs(authorisedPlayers) do
      allPlys[ply] = true
    end

    local authOptions = {}
    local unauthOptions = {}

    for ply, isAuth in pairs(allPlys) do
      table.insert(isAuth and authOptions or unauthOptions, ply)
    end

    table.sort(authOptions)
    table.sort(unauthOptions)

    authList:setOptions(authOptions)
    unauthList:setOptions(unauthOptions)
  end

  updateLists()

  function authList:handleClick(_, data)
    table.removeByValue(authorisedPlayers, data.displayText)
    updateLists()
    savePlayers()
  end

  function unauthList:handleClick(_, data)
    table.insert(authorisedPlayers, data.displayText)
    updateLists()
    savePlayers()
  end

  local enableButton = addElem(ui.text.create())
  enableButton:setPos(midX - 15, h - 4)
  enableButton:setSize(30, 3)
  enableButton:setTextDrawPos(12, 1)

  local function updateEnableButton()
    local enabled = storage.lockPageEnabled
    enableButton:setBgColor(enabled and colors.green or colors.red)
    enableButton:setText(enabled and "Enabled" or "Disabled")
    enableButton:invalidateLayout(true)
  end

  function enableButton:onClick()
    storage.lockPageEnabled = not storage.lockPageEnabled
    updateEnableButton()
  end
end

function editLockPage.cleanup()
  for _, elem in ipairs(editLockPage.elems) do
    elem:remove()
  end
end
