dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")

storage.updateChests()
storage.updateItemMapping()
storage.dropItem("minecraft:bone", 5)

hook.runLoop()
