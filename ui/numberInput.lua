require "ui.base"
require "ui.draw"

ui.numberInput = {}

function ui.numberInput.create(parent)
  local elem = ui.text.create(parent)
  elem:setTextDrawPos(0, 1)
  elem.value = 0
  elem.max = nil
  elem.canDeselect = true
  elem.selected = false

  function elem:setCanDeselect(canDeselect)
    self.canDeselect = canDeselect
    if not canDeselect then
      self:setSelected(true)
    end
  end

  function elem:onClick()
    if not self.selected then
      self:setSelected(true)
    end
  end
  
  local showUnderscore = true
  function elem:setSelected(selected)
    self.selected = selected
    showUnderscore = selected
    self:setValue(self.value)
    if selected then
      self:startUnderscoreTimer()
    else
      self:stopUnderscoreTimer()
      self:onDeselect(self.value)
    end
  end

  function elem:onDeselect(val)
  end

  function elem:setMax(n)
    elem.max = n
  end

  function elem:getValue()
    return elem.value
  end

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

  function elem:startUnderscoreTimer()
    timer.create("numberInputUnderscore" .. elem.id, 0.5, 0, function()
      if not elem.selected then return end
      showUnderscore = not showUnderscore
      elem:setValue(elem.value)
    end)
  end

  function elem:stopUnderscoreTimer()
    timer.remove("numberInputUnderscore" .. elem.id)
  end

  hook.add("key", "numberInputKey" .. elem.id, function(key)
    if not elem.selected then return end
    if key ~= keys.backspace then return end
    elem:setValue(math.floor(elem.value / 10))
  end)

  hook.add("char", "numberInputChar" .. elem.id, function(char)
    if not elem.selected then return end
    local num = tonumber(char)
    if not num then return end
    elem:setValue(elem.value * 10 + num)
  end)

  -- need a hook for clicking outside the range
  hook.add("mouse_click", "numberInputClick" .. elem.id, function(_, x, y)
    if elem.removed then return end
    if not elem.canDeselect then return end
    local globalX, globalY = elem:localisePosition(0, 0)
    local outsideX = x < globalX + 1 or x > globalX + 1 + elem.size.x
    local outsideY = y < globalY + 1 or y > globalY + 1 + elem.size.y

    if outsideX or outsideY and elem.selected then
      elem:setSelected(false)
    end
  end)

  local oldOnRemove = elem.onRemove
  function elem:onRemove()
    self:stopUnderscoreTimer()
    hook.remove("key", "numberInputKey" .. elem.id)
    hook.remove("char", "numberInputChar" .. elem.id)
    hook.remove("mouse_click", "numberInputClick" .. elem.id)
    oldOnRemove(self)
  end

  return elem
end
