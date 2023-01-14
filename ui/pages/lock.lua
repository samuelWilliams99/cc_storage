require "ui.pages.pages"
require "utils.helpers"

local playerDetector = peripheral.find("playerDetector")
if not playerDetector then error("No player detector found, please connect one to the computer to use") end

local lockPage = {}
local editLockPage = {
  shouldMakeBackButton = true,
  title = "Lock Manager",
  configName = "Lock Manager"
}

pages.addPage("lock", lockPage)
pages.addPage("editLock", editLockPage)

local w, h = term.getSize()

local authorisedPlayers = readFile("users.txt") or {}

storage.lockPageEnabled = #authorisedPlayers > 0

local function savePlayers()
  writeFile("users.txt", authorisedPlayers)
end

function storage.startLockTimer()
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
end

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

function editLockPage.setup()
  -- left title
  local midLeftX = 2 + math.floor((w - 4) * 0.25)
  local leftTitleText = "Authorised players"
  term.setCursorPos(math.ceil(midLeftX - #leftTitleText / 2), 6)
  term.write(leftTitleText)

  -- right title
  local midRightX = 2 + math.floor((w - 4) * 0.75)
  local rightTitleText = "Unauthorised players"
  term.setCursorPos(math.ceil(midRightX - #rightTitleText / 2), 6)
  term.write(rightTitleText)

  term.setTextColor(colors.white)

  local midX = math.floor(w * 0.5)

  local authList = pages.elem(ui.buttonList.create())
  authList:setPos(2, 7)
  authList:setSize(midX - 4, h - 13)
  authList:setTextCentered(true)

  local unauthList = pages.elem(ui.buttonList.create())
  unauthList:setPos(midX + 2, 7)
  unauthList:setSize(midX - 4, h - 13)
  unauthList:setTextCentered(true)

  local function updateLists()
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
      table.insert(isAuth and authOptions or unauthOptions, {displayText = ply})
    end

    table.sort(authOptions, function(a, b) return a.displayText < b.displayText end)
    table.sort(unauthOptions, function(a, b) return a.displayText < b.displayText end)

    authList:setOptions(authOptions)
    unauthList:setOptions(unauthOptions)
  end

  updateLists()

  local enableButton = pages.elem(ui.text.create())
  enableButton:setPos(midX - 15, h - 4)
  enableButton:setSize(30, 3)
  enableButton:setTextDrawPos(11, 1)

  local function updateEnableButton()
    local enabled = storage.lockPageEnabled
    local col = enabled and colors.green or colors.red
    
    if #authorisedPlayers == 0 then
      col = colors.gray
    end
    enableButton:setBgColor(col)
    enableButton:setText(enabled and "Enabled" or "Disabled")
    enableButton:invalidateLayout(true)
  end

  updateEnableButton()

  function authList:handleClick(_, data)
    table.removeByValue(authorisedPlayers, data.displayText)
    if #authorisedPlayers == 0 then storage.lockPageEnabled = false end
    updateLists()
    updateEnableButton()
    savePlayers()
  end

  function unauthList:handleClick(_, data)
    table.insert(authorisedPlayers, data.displayText)
    updateLists()
    updateEnableButton()
    savePlayers()
  end

  function enableButton:onClick()
    if #authorisedPlayers == 0 then return end
    storage.lockPageEnabled = not storage.lockPageEnabled
    updateEnableButton()
  end
end
