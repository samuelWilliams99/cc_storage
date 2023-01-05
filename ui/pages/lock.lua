require "ui.pages.pages"

local lockPage = {}

pages.addPage("lock", lockPage)

local w, h = term.getSize()

local players = {
  "Sam_oh_blam_oh",
  "simmel99",
  "LaPrisci"
}

function lockPage.setup()
  local playerDetector = peripheral.find("playerDetector")
  if not playerDetector then error("No player detector found, please connect one to the computer to use") end

  hook.add("terminate", "preventTerminate", function()
    return true
  end)

  hook.add("playerClick", "lockUnlockAttempt", function(playerName)
    if table.contains(players, playerName) then
      pages.setPage(lockPage.active and "itemList" or "lock")
    end
  end)

  timer.create("autolock", 5, 0, function()
    if lockPage.active then return end
    local plys = playerDetector.getPlayersInRange(5)
    local foundPlayer = false
    for _, ply in pairs(plys) do
      if table.contains(players, ply) then
        foundPlayer = true
      end
    end
    if not foundPlayer then
      pages.setPage("lock")
    end
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
