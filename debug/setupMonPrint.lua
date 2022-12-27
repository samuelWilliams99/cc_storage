local mon = peripheral.find("monitor")
mon.clear()
mon.setCursorPos(1,1)
local _, h = mon.getSize()

function _G.printMon(...)
    local vals = {...}
    local printStr = ""
    for i, elem in ipairs(vals) do
        printStr = printStr .. tostring(elem)
        if i ~= #vals then
            printStr = printStr .. "\t"
        end
    end
    mon.write(printStr)
    local _, y = mon.getCursorPos()
    if y < h then
        mon.setCursorPos(1, y + 1)
    else
        mon.scroll(1)
        mon.setCursorPos(1, y)
    end
end

function _G.clearMon()
    mon.clear()
    mon.setCursorPos(1,1)
end
