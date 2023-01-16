storage.remoteAccess = {}

storage.remoteAccess.requestPort = 29381
storage.modem.open(storage.remoteAccess.requestPort)

-- If possible, reuse the same itemList code, just hide the configure button.
-- Move everything that reads data from storage.items into functions which we can change based on context
-- Create a newstartup with initially requests the storage data, then spins up the single UI
-- Add a button to that UI for bag pausing
-- Finally, add some way of specifying the enderchestID, maybe it asks you to put a single cobblestone in your bag, and waits for an input that just has one cobble
-- computer finds one, it sends that periph ID out to the computer ID that requested it

-- Hard part - item updates, we can't send over the whole table every time (i think, maybe we just can)
-- Try sending the whole thing, but if it doesnt work/is slow, deep look into the item management code, ensure all the onchange hooks are correct
-- Then batch up changes by batching until either 0.5s passes or no changes in 0.1s and send those off to the remote terminals
--   The changes will be broadcast freely, the full state must be specifically requested
--   Potential issue: a computer requests the full state but misses updates while the full state is sending
--   We'll need to start batching updates immediately, and perhaps have some minimum delay after full send before batch can be sent

hook.add("modem_message", "remote_access", function(_, port, _, data)
  if port ~= storage.remoteAccess.requestPort then return end

  if data.type == "requestItem" then
    storage.enderChest.dropItem(data.chestName, data.key, data.count)
  elseif data.type == "pauseChest" then
    storage.enderChest.pauseChest(data.chestName, not data.shouldPause)
  elseif data.type == "requestData" then
    -- ??
  end
end)
