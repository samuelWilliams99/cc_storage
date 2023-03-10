hook = {}
hook.handlers = {}
hook.routines = {}

-- Additional hooks added:
-- initialize - runs at the start of the program (prefer this over code before hook.runLoop, as it'll run in a coroutine)

-- Special behaviour
-- terminate - this hook is not sent to running coroutines to avoid unnecessary errors. returning true on this hook will prevent the termination

-- Returning values out of hooks does nothing, EXCEPT for the `terminate` hook, in which case, returning true will disable the usual Terminate error thrown
-- For example, `hook.add("terminate", "prevent_terminate", function() return true end)` will prevent terminating
function hook.add(eventName, handlerName, handler, priority)
  priority = priority or 0
  hook.handlers[eventName] = hook.handlers[eventName] or {}

  local newHandlerData = {
    handler = handler,
    handlerName = handlerName,
    priority = priority
  }

  local handlers = hook.handlers[eventName]
  local inserted = false

  for i = #handlers, 1, -1 do
    local handlerData = handlers[i]
    if handlerData.handlerName == handlerName then
      table.remove(handlers, i)
      i = i - 1
    end
    if not inserted and handlerData.priority >= priority then
      table.insert(handlers, i + 1, newHandlerData)
      inserted = true
    end
  end
  
  if not inserted then
    table.insert(handlers, 1, newHandlerData)
  end
end

function hook.remove(eventName, handlerName)
  for i, handlerData in ipairs(hook.handlers[eventName] or {}) do
    if handlerData.handlerName == handlerName then
      table.remove(hook.handlers[eventName], i)
      return
    end
  end
end

local function throwError(event, handlerName, data, co)
  local shouldPrevent = false
  local traceback = debug.traceback(co)
  if hook.preError then
    shouldPrevent = not not hook.preError(event, handlerName, data, traceback)
  end
  if not shouldPrevent then
    error("Hook " .. event .. ", " .. handlerName .. " errored with: " .. tostring(data) .. "\n" .. traceback, 0)
  end
end

function hook.runInHandlerContext(f, ...)
  local args = table.pack(...)
  local co = coroutine.create(function() f(table.unpack(args, 1, args.n)) end)
  local success, data = coroutine.resume(co)

  if not success then throwError("ONE-OFF-HANDLER", "", data, co) end

  if coroutine.status(co) ~= "dead" then
    table.insert(hook.routines, {routine = co, filter = data, isTerminate = false, event = "ONE-OFF-HANDLER", handlerName = ""})
  end
end

-- Add a pre-throw error callback. returning true with this function will prevent the error
function hook.setPreError(f)
  hook.preError = f
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
          if not success then throwError(routineData.event, routineData.handlerName, data, routineData.routine) end
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

    -- copy to avoid hook changes in hook
    local handlerTableCopy = table.shallowCopy(handlerTable or {})

    -- Run handlers
    for _, handlerData in ipairs(handlerTableCopy) do
      local handlerName = handlerData.handlerName
      local handler = handlerData.handler
      local co = coroutine.create(function() return handler(table.unpack(eventData, 2, eventData.n)) end)
      local success, data = coroutine.resume(co)

      if not success then throwError(event, handlerName, data, co) end

      local finished = coroutine.status(co) == "dead"

      if not finished then
        table.insert(hook.routines, {routine = co, filter = data, isTerminate = isTerminate, event = event, handlerName = handlerName})
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