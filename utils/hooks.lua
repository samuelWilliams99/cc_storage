if hook then return end

hook = {}
hook.handlers = {}
hook.routines = {}

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
    local data = table.pack(os.pullEvent())
    local event = table.remove(data, 1)
    local handlerTable = hook.handlers[event]

    -- loop through the routines, if filter matches data[1] then resume them with it
    -- if they finish after this, remove from routines
    for i = #hook.routines, 1, -1 do
      local routineData = hook.routines[i]
      if routineData.filter == nil or routineData.filter == event then
        local success, data = coroutine.resume(routineData.routine, table.unpack(data, 1, data.n))
        if not success then error(data) end
        if coroutine.status(routineData.routine) == "dead" then
          table.remove(hook.routines, i)
        else
          routineData.filter = data
        end
      end
    end

    for _, handler in pairs(handlerTable or {}) do
      local co = coroutine.create(function() handler(table.unpack(data, 1, data.n)) end)
      local success, data = coroutine.resume(co)
      if not success then error(data) end
      if coroutine.status(co) ~= "dead" then
        table.insert(hook.routines, {routine = co, filter = data})
      end
    end
  end
end