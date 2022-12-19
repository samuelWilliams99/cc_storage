if hook then return end

hook = {}
hook.handlers = {}

function hook.add(eventName, handlerName, handler)
    hook.handlers[eventName] = hook.handlers[eventName] or {}
    hook.handlers[eventName][handlerName] = handler
end

hook.run = os.queueEvent

function hook.clear()
    hook.handlers = {}
end

function hook.runLoop()
    os.queueEvent("initialize")
    while true do
        local data = {os.pullEvent()}
        local handlerTable = hook.handlers[data[1]]
        table.remove(data, 1)

        for _, handler in pairs(handlerTable or {}) do
            handler(unpack(data))
        end
    end
end