dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")

local items = storage.getItemMapping(storage.getChests())
storage.getItem("minecraft:bone", 5)

hook.runLoop()
