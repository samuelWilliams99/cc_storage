require "ui.base"
require "ui.draw"
local cc_strings = require "cc.strings"

ui.logger = {}

function ui.logger.create(parent)
  local elem = ui.makeElement(parent)
  elem.texts = {}

  function elem:writeText(text, col)
    table.insert(self.texts, {text = text, color = col or colors.white})
    self:invalidateLayout()
  end

  function elem:newLine()
    table.insert(self.texts, "")
    self:invalidateLayout()
  end

  function elem:removeLastLine()
    table.remove(self.texts, #self.texts)
    self:invalidateLayout()
  end

  function elem:draw()
    local y = 0
    for _, textData in ipairs(elem.texts) do
      local lines = cc_strings.wrap(textData.text, self.size.x)
      for _, line in ipairs(lines) do
        ui.drawText(0, y, line, textData.color)
        y = y + 1
        if y == self.size.y then return end
      end
    end
  end

  return elem
end
