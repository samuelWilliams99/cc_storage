dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")

storage.updateChests()
storage.updateItemMapping()
storage.startInputTimer()

hook.runLoop()
