require "utils.helpers"

local args = {...}
local n = tonumber(args[1])

local logs = readFile("logs.txt")
if not logs then return print("No errors to report boss!") end

n = n or 1

local log = logs[#logs - n + 1]

if not log then return print("No error at this index") end

print("Occured at: " .. log.time)
printError("Hook " .. log.event .. ", " .. log.handlerName .. " errored with: " .. tostring(log.err) .. "\n" .. log.stack)
