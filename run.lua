dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils.timer.lua")
dofile("cc_storage/storage/items.lua")

print(textutils.serialise(storage.getItemMapping(storage.getChests())))

hook.runLoop()
