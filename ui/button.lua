dofile("cc_storage/ui/base.lua")
dofile("cc_storage/ui/draw.lua")

ui.button = {}

function ui.button.create(parent)
  local elem = ui.makeElement(parent)
  elem:setSize(6, 1)
  elem.text = "button"
  elem.bgColor = colors.gray
  elem.textColor = colors.white
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

  function elem:draw()
    ui.drawFilledBox(0, 0, self.size.x, self.size.y, self.bgColor)
    ui.drawText(0, 0, self.text, self.textColor)
  end

  self:invalidateLayout()
end
