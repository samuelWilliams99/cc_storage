hook = {}
hook.handlers = {}
hook.routines = {}

function hook.add(eventName, handlerName, handler)
  hook.handlers[eventName] = hook.handlers[eventName] or {}
  hook.handlers[eventName][handlerName] = handler
end

hook.run = os.queueEvent

function hook.runLoop()
  os.queueEvent("initialize")
  while true do
    local eventData = table.pack(os.pullEvent())
    local handlerTable = hook.handlers[eventData[1]]

    -- Handle existing routines
    for i = #hook.routines, 1, -1 do
      local routineData = hook.routines[i]
      if routineData.filter == nil or routineData.filter == eventData[1] then
        -- We resume coroutines WITH the event name, which differs to running hook handlers, which do NOT take the event name
        local success, data = coroutine.resume(routineData.routine, table.unpack(eventData, 1, eventData.n))
        if not success then error(data) end
        if coroutine.status(routineData.routine) == "dead" then
          table.remove(hook.routines, i)
        else
          routineData.filter = data
        end
      end
    end

    -- Run handlers
    for _, handler in pairs(handlerTable or {}) do
      local co = coroutine.create(function() handler(table.unpack(eventData, 2, eventData.n)) end)
      local success, data = coroutine.resume(co)
      if not success then error(data) end
      if coroutine.status(co) ~= "dead" then
        table.insert(hook.routines, {routine = co, filter = data})
      end
    end
  end
end