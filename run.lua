dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils/timer.lua")
dofile("cc_storage/storage/items.lua")

local items = storage.getItemMapping(storage.getChests())
print(textutils.serialise(table.keys(items)))

hook.runLoop()
