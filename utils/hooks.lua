if hook then return end

hook = {}

function hook.add(eventName, handlerName, handler)
    hook[eventName] = hook[eventName] or {}
    hook[eventName][handlerName] = handler
end

hook.run = os.queueEvent

function hook.runLoop()
    os.queueEvent("initialize")
    while true do
        local data = {os.pullEvent()}
        local handlerTable = hook[data[1]]
        table.remove(data, 1)

        for _, handler in pairs(handlerTable or {}) do
            handler(unpack(data))
        end
    end
end