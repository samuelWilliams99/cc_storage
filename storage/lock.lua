storage.lock = {}

local playerDetector = peripheral.find("playerDetector")
if not playerDetector then error("No player detector found, please connect one to the computer to use") end

local authorisedPlayers = readFile("users.txt") or {}

storage.lock.enabled = #authorisedPlayers > 0

local function savePlayers()
  writeFile("users.txt", authorisedPlayers)
  hook.run("cc_lock_authorised_players_change", authorisedPlayers)
end

function storage.lock.getOnlinePlayers()
  return playerDetector.getOnlinePlayers() or {}
end

function storage.lock.getAuthorisedPlayers()
  return authorisedPlayers
end

function storage.lock.authorisePlayer(plyName)
  table.insert(authorisedPlayers, plyName)
  savePlayers()
end

function storage.lock.unauthorisePlayer(plyName)
  table.removeByValue(authorisedPlayers, plyName)
  savePlayers()
  if #authorisedPlayers == 0 then
    storage.lock.setEnabled(false)
  end
end

function storage.lock.setEnabled(enabled)
  storage.lock.enabled = enabled
  hook.run("cc_lock_enabled_change", enabled)
end

function storage.lock.getEnabled()
  return storage.lock.enabled
end

function storage.startLockTimer()
  hook.add("playerClick", "lockUnlockAttempt", function(playerName)
    if table.contains(authorisedPlayers, playerName) and storage.lock.enabled then
      pages.setPage(pages.pages.lock.active and "itemList" or "lock")
    end
  end)

  timer.create("autolock", 5, 0, function()
    if pages.pages.lock.active or not storage.lock.enabled then return end
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
