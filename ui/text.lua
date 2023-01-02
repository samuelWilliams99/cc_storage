require "ui.base"
require "ui.draw"

ui.text = {}

function ui.text.create(parent)
  local elem = ui.makeElement(parent)
  elem:setSize(4, 1)
  elem.text = "text"
  elem.bgColor = colors.gray
  elem.textColor = colors.white
  elem.drawPos = ui.Vector(0, 0)
  function elem:setText(text)
    self.text = text
    self:invalidateLayout()
  end

  function elem:setBgColor(col)
    self.bgColor = col
    self:invalidateLayout()
  end

  function elem:setTextColor(col)
    self.textColor = col
    self:invalidateLayout()
  end

  function elem:setTextDrawPos(x, y)
    elem.drawPos = ui.Vector(x, y)
  end

  function elem:draw()
    ui.drawFilledBox(0, 0, self.size.x - 1, self.size.y - 1, self.bgColor)
    ui.drawText(elem.drawPos.x, elem.drawPos.y, self.text, self.textColor, self.bgColor)
  end

  elem:invalidateLayout()
  return elem
end
