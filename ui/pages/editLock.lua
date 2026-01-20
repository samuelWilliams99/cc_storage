require "ui.pages.pages"
require "utils.helpers"

local editLockPage = {
  shouldMakeBackButton = true,
  title = "Lock Manager",
  configName = "Lock Manager"
}

if storage.lock.hasDetector() then
  pages.addPage("editLock", editLockPage)
end

local w, h = term.getSize()

function editLockPage.setup()
  local authorisedPlayers = storage.lock.getAuthorisedPlayers()
  local enabled = storage.lock.getEnabled()

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
    for _, ply in ipairs(storage.lock.getOnlinePlayers()) do
      allPlys[ply] = false
    end
    for _, ply in ipairs(storage.lock.getAuthorisedPlayers()) do
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
    storage.lock.unauthorisePlayer(data.displayText)
  end

  function unauthList:handleClick(_, data)
    storage.lock.authorisePlayer(data.displayText)
  end

  function enableButton:onClick()
    if #authorisedPlayers == 0 then return end
    storage.lock.setEnabled(not enabled)
  end

  hook.add("cc_lock_authorised_players_change", "update_menu", function(_authorisedPlayers)
    authorisedPlayers = _authorisedPlayers
    updateLists()
    updateEnableButton()
  end)

  hook.add("cc_lock_enabled_change", "update_menu", function(_enabled)
    enabled = _enabled
    updateEnableButton()
  end)
end

function editLockPage.cleanup()
  hook.remove("cc_lock_authorised_players_change", "update_menu")
  hook.remove("cc_lock_enabled_change", "update_menu")
end
