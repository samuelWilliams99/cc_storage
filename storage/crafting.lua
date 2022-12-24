storage.crafting = storage.crafting or {}

local craftingPort = 1357
local modem = peripheral.wrap("back")
modem.open(craftingPort)

function storage.crafting.setupCrafters()
    print("Locating crafters")
    local chests = storage.crafting.candidates or {}

    os.startTimer(1)
    modem.transmit(craftingPort, craftingPort, {type = "scan"})
    local crafterIDs = {}
    while true do
        local data = {os.pullEvent()}
        if data[1] == "modem_message" and data[3] == craftingPort then
            local compID = data[5].computerID
            table.insert(crafterIDs, compID)
        elseif data[1] == "timer" then
            break
        end
    end
    print("Found " .. #crafterIDs .. " crafting turtles, locating chests...")

    print(#chests .. " crafting chest candidates turned out to be normal chests.")
    for _, chest in pairs(chests) do
        storage.addEmptyChest(chest)
    end
end