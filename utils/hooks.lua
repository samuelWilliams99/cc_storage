hook = {}
hook.handlers = {}
hook.routines = {}

-- Returning values out of hooks does nothing, EXCEPT for the `terminate` hook, in which case, returning true will disable the usual Terminate error thrown
-- For example, `hook.add("terminate", "prevent_terminate", function() return true end)` will prevent terminating
function hook.add(eventName, handlerName, handler)
  hook.handlers[eventName] = hook.handlers[eventName] or {}
  hook.handlers[eventName][handlerName] = handler
end

hook.run = os.queueEvent

function hook.runLoop()
  os.queueEvent("initialize")
  while true do
    local eventData = table.pack(os.pullEventRaw())
    local event = eventData[1]
    local isTerminate = event == "terminate"
    local handlerTable = hook.handlers[event]

    -- Handle existing routines (but not if terminate message, as then they error out)
    if not isTerminate then
      for i = #hook.routines, 1, -1 do
        local routineData = hook.routines[i]
        if routineData.filter == nil or routineData.filter == event then
          -- We resume coroutines WITH the event name, which differs to running hook handlers, which do NOT take the event name
          local success, data = coroutine.resume(routineData.routine, table.unpack(eventData, 1, eventData.n))
          if not success then error(data) end
          if coroutine.status(routineData.routine) == "dead" then
            table.remove(hook.routines, i)
            if routineData.isTerminate and not data then
              error("Terminated", 0)
            end
          else
            routineData.filter = data
          end
        end
      end
    end

    local shouldTerminate = isTerminate

    -- Run handlers
    for handlerName, handler in pairs(handlerTable or {}) do
      local co = coroutine.create(function() handler(table.unpack(eventData, 2, eventData.n)) end)
      local success, data = coroutine.resume(co)

      if not success then error("Hook " .. event .. ", " .. handlerName .. " errored with: " .. tostring(data), 2) end

      local finished = coroutine.status(co) == "dead"

      if not finished then
        table.insert(hook.routines, {routine = co, filter = data, isTerminate = isTerminate})
        if isTerminate then
          shouldTerminate = false
        end
      end

      if isTerminate and data then
        shouldTerminate = false
      end
    end

    if shouldTerminate then
      error("Terminated", 0)
    end
  end
end