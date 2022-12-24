dofile("cc_storage/ui/base.lua")
dofile("cc_storage/ui/draw.lua")
dofile("cc_storage/ui/text.lua")

ui.buttonList = {}

function ui.buttonList.create(parent)
  local elem = ui.makeElement(parent)
  elem.options = {}
  elem.buttons = {}

  --[[ Options:
  {
    {
      displayText: text
      ...
    }
  }
  ]]
  function elem:setOptions(options)
    self.options = options
    self:update()
  end

  function elem:update()
    for i = #self.buttons + 1, #self.options do
      if i > self.size.y then error("Ya dun added too many things ya dangus") end
      local button = ui.text.create(self)
      button:setSize(self.size.x, 1)
      button:setPos(0, #self.buttons)
      button:setBgColor(i % 2 == 1 and colors.black or colors.gray)
      function button:onClick(btn)
        self.parent:handleClick(btn, self.data)
      end
      table.insert(self.buttons, button)
    end

    for i = #self.buttons, #self.options + 1, -1 do
      self.buttons[i]:remove()
      table.remove(self.buttons, i)
    end

    for i, btn in ipairs(self.buttons) do
      btn.data = self.options[i]
      btn:setText(btn.data.displayText)
    end
    self:invalidateLayout()
  end

  function elem:handleClick(btn, data, i)
  end

  function elem:draw()
  end

  elem:invalidateLayout()
  return elem
end
