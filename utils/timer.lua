require "utils.hooks"

timer = timer or {}
timer.ccTimerIDLookup = timer.ccTimerIDLookup or {}
timer.timers = timer.timers or {}
timer.nameCounter = timer.nameCounter or 0

hook.add("timer", "timerLoop", function(ccTimerID)
  local name = timer.ccTimerIDLookup[ccTimerID]
  if not name then return end
  timer.ccTimerIDLookup[ccTimerID] = nil

  local timerData = timer.timers[name]
  if not timerData then return end

  timerData.callback()

  if timerData.repsLeft == 1 then
    timer.timers[name] = nil
    return
  end

  if timerData.repsLeft ~= 0 then
    timerData.repsLeft = timerData.repsLeft - 1
  end

  local newCCTimerID = os.startTimer(timerData.delay)
  timer.ccTimerIDLookup[newCCTimerID] = name
  timerData.ccTimerID = newCCTimerID
end)

function timer.create(name, delay, reps, callback)
  timer.remove(name)
  local ccTimerID = os.startTimer(delay)

  timer.ccTimerIDLookup[ccTimerID] = name

  timer.timers[name] = {
    delay = delay,
    repsLeft = reps,
    callback = callback,
    ccTimerID = ccTimerID
  }
end

-- Restarts the delay
function timer.restart(name)
  local timerData = timer.timers[name]
  if not timerData then return end

  timer.ccTimerIDLookup[timerData.ccTimerID] = nil

  os.cancelTimer(timerData.ccTimerID)

  local newCCTimerID = os.startTimer(timerData.delay)
  timer.ccTimerIDLookup[newCCTimerID] = name
  timerData.ccTimerID = newCCTimerID
end

function timer.simple(delay, callback)
  timer.create("simple_timer_" .. timer.nameCounter, delay, 1, callback)
  timer.nameCounter = timer.nameCounter + 1
end

function timer.exists(name)
  return timer.timers[name] and true or false
end

function timer.remove(name)
  local timerData = timer.timers[name]
  if not timerData then return end
  timer.timers[name] = nil
  timer.ccTimerIDLookup[timerData.ccTimerID] = nil

  os.cancelTimer(timerData.ccTimerID)
end
