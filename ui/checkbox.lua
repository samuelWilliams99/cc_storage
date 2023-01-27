require "ui.base"
require "ui.draw"

ui.checkbox = {}

function ui.checkbox.create(parent)
  local elem = ui.text.create(parent)
  elem.checked = false

  elem.oldSetText = elem.setText

  function elem:setText(text)
    self.checkboxText = text
    self:updateText()
  end

  function elem:setChecked(checked)
    if self.checked == checked then return end
    self.checked = checked
    self:updateText()
    self:onChange(self.checked)
  end

  function elem:onChange(checked)
  end

  function elem:updateText()
    local w = self.size.x
    local text = self.checkboxText
    if #text > w - 4 then
      text = text:sub(0, #text - 3) .. "..."
    end
    text = text .. string.rep(" ", w - 3 - #text)
    if self.checked then
      text = text .. " [X]"
    else
      text = text .. " [ ]"
    end
    self:oldSetText(text)
  end

  function elem:onClick()
    self:setChecked(not self.checked)
  end

  return elem
end
