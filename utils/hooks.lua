hook = {}

function hook.add(eventName, handlerName, handler)
    hook[eventName] = hook[eventName] or {}
    hook[eventName][handlerName] = handler
    print("add " .. eventName .. " with " .. handlerName)
end

hook.run = os.queueEvent

function hook.runLoop()
    os.queueEvent("initialize")
    while true do
        local data = {os.pullEvent()}
        local handlerTable = hook[data[1]]
        print(data[1])
        table.remove(data, 1)

        for name, handler in pairs(handlerTable or {}) do
            print(name)
            handler(unpack(data))
        end
    end
end