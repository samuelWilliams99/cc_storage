require "ui.base"
require "ui.draw"

ui.numberInput = {}

function ui.numberInput.create(parent)
  local elem = ui.text.create(parent)
  elem:setTextDrawPos(0, 1)
  elem.value = 0
  elem.max = nil

  function elem:setMax(n)
    elem.max = n
  end

  function elem:getValue()
    return elem.value
  end

  local showUnderscore = true
  function elem:setValue(n)
    if elem.max and n > elem.max then return end
    local old = elem.value
    
    elem.value = n
    local str = ""
    if elem.value > 0 then str = tostring(elem.value) end
    if showUnderscore then str = str .. "_" end
    elem:setText("  " .. str)
    elem:invalidateLayout(true)

    if old ~= elem.value then
      elem:onChange(old, elem.value)
    end
  end

  function elem:onChange(old, new)
  end

  timer.create("numberInputUnderscore" .. elem.id, 0.5, 0, function()
    showUnderscore = not showUnderscore
    elem:setValue(elem.value)
  end)

  hook.add("key", "numberInputKey" .. elem.id, function(key)
    if key ~= keys.backspace then return end
    elem:setValue(math.floor(elem.value / 10))
  end)

  hook.add("char", "numberInputChar" .. elem.id, function(char)
    local num = tonumber(char)
    if not num then return end
    elem:setValue(elem.value * 10 + num)
  end)

  local oldOnRemove = elem.onRemove
  function elem:onRemove()
    timer.remove("numberInputUnderscore" .. elem.id)
    hook.remove("key", "numberInputKey" .. elem.id)
    hook.remove("char", "numberInputChar" .. elem.id)
    oldOnRemove(self)
  end

  return elem
end
