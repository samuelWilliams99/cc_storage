require "ui.base"
require "ui.draw"
require "ui.text"

ui.buttonList = {}

function ui.buttonList.create(parent)
  local elem = ui.makeElement(parent)
  elem.options = {}
  elem.buttons = {}
  elem.splits = {1}
  elem.textCentered = false

  --[[ Options:
  {
    {
      displayText: text or {text}
      ...
    }
  }
  ]]
  function elem:setOptions(options)
    self.options = options
    self:update()
  end

  function elem:setSplits(...)
    self.splits = {...}
    table.insert(self.splits, 1)
  end

  function elem:setTextCentered(centered)
    elem.textCentered = centered
  end

  function elem:rowToStr(row)
    local str = ""
    local w = self.size.x
    for i, xProp in ipairs(self.splits) do
      local rowStr = row[i] or ""
      local x = math.floor(xProp * w)
      
      local maxChars = x - #str - (i > 1 and 1 or 0) - (xProp < 1 and 1 or 0)

      if #rowStr > maxChars then
        rowStr = rowStr:sub(1, maxChars - 3) .. "..."
      end

      if i > 1 then str = str .. " " end
      
      local spacesToAdd = maxChars - #rowStr
      local preSpaces = self.textCentered and math.floor(spacesToAdd / 2) or 0
      local postSpaces = spacesToAdd - preSpaces

      str = str .. string.rep(" ", preSpaces) .. rowStr .. string.rep(" ", postSpaces)

      if xProp < 1 then
        str = str .. " |"
      end
    end
    return str
  end

  function elem:update()
    for i = #self.buttons + 1, #self.options do
      if i > self.size.y then error("Ya dun added too many things ya dangus") end
      local button = ui.text.create(self)
      button:setSize(self.size.x, 1)
      button:setPos(0, #self.buttons)
      function button:onClick(btn)
        self.parent:handleClick(btn, self.data)
      end
      table.insert(self.buttons, button)
    end

    for i = #self.buttons, #self.options + 1, -1 do
      self.buttons[i]:remove()
      table.remove(self.buttons, i)
    end

    for i, button in ipairs(self.buttons) do
      button.data = self.options[i]
      local row = button.data.displayText
      if type(row) == "string" then row = {row} end
      button:setText(elem:rowToStr(row))
      if button.data.bgColor then
        button:setBgColor(button.data.bgColor)
      else
        button:setBgColor(i % 2 == 1 and colors.black or colors.gray)
      end
    end
    self:invalidateLayout(true)
  end

  function elem:handleClick(btn, data, i)
  end

  function elem:draw()
  end

  elem:invalidateLayout()
  return elem
end
