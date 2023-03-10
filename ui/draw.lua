require "ui.base"
require "utils.timer"

function ui.Vector(x, y)
  return {x = x, y = y}
end

ui._defDrawPositioning = {pos = ui.Vector(0, 0), size = ui.Vector(term.getSize())}
ui._drawPositioning = ui._defDrawPositioning

local function localisePosition(x, y)
  if x < 0 or x > ui._drawPositioning.size.x then error("Attempt to draw out of range") end
  if y < 0 or y > ui._drawPositioning.size.y then error("Attempt to draw out of range") end
  return x + ui._drawPositioning.pos.x + 1, y + ui._drawPositioning.pos.y + 1
end

local function maintainCursor(f, ...)
  local x, y = term.getCursorPos()
  local textCol = term.getTextColor()
  local bgCol = term.getBackgroundColor()
  f(...)
  term.setCursorPos(x, y)
  term.setTextColor(textCol)
  term.setBackgroundColor(bgCol)
end

function ui.drawPixel(_x, _y, col)
  local x, y = localisePosition(_x, _y)
  maintainCursor(paintutils.drawPixel, x, y, col)
end

function ui.drawLine(_x1, _y1, _x2, _y2, col)
  local x1, y1 = localisePosition(_x1, _y1)
  local x2, y2 = localisePosition(_x2, _y2)
  maintainCursor(paintutils.drawLine, x1, y1, x2, y2, col)
end

function ui.drawBox(_x1, _y1, _x2, _y2, col)
  local x1, y1 = localisePosition(_x1, _y1)
  local x2, y2 = localisePosition(_x2, _y2)
  maintainCursor(paintutils.drawBox, x1, y1, x2, y2, col)
end

function ui.drawFilledBox(_x1, _y1, _x2, _y2, col)
  local x1, y1 = localisePosition(_x1, _y1)
  local x2, y2 = localisePosition(_x2, _y2)
  maintainCursor(paintutils.drawFilledBox, x1, y1, x2, y2, col)
end

function ui.drawText(_x, _y, text, textCol, bgCol)
  _x = _x or 0
  _y = _y or 0
  local x, y = localisePosition(_x, _y)

  if #text > ui._drawPositioning.size.x then
    text = text:sub(1, ui._drawPositioning.size.x)
  end

  textCol = textCol or colors.white
  bgCol = bgCol or colors.black
  textColBlit = string.rep(colors.toBlit(textCol), #text)
  bgColBlit = string.rep(colors.toBlit(bgCol), #text)
  maintainCursor(function()
    term.setCursorPos(x, y)
    term.blit(text, textColBlit, bgColBlit)
  end)
end

function ui.classes.Base:doDraw()
  ui._drawPositioning = {pos = ui.Vector(self:localisePosition(0, 0)), size = self.size}
  ui.drawFilledBox(0, 0, self.size.x - 1, self.size.y - 1, colors.black)
  self:draw()
  ui._drawPositioning = ui._defDrawPositioning
  for _, child in pairs(self.children) do
    child:doDraw()
  end
  self:onDoDraw()
end

function ui.classes.Base:onDoDraw()
end

function ui.classes.Base:invalidateLayout(instantly)
  if instantly and not self.removed then
    timer.remove("invalidateLayout" .. self.id)
    self:doDraw()
    return
  end
  local this = self
  timer.create("invalidateLayout" .. self.id, 0.05, 1, function()
    if this.removed then return end
    this:doDraw()
  end)
end

function ui.classes.Base:onRemove()
  if not self.parent then
    paintutils.drawFilledBox(self.pos.x + 1, self.pos.y + 1, self.pos.x + self.size.x, self.pos.y + self.size.y, colors.black)
  end
  timer.remove("invalidateLayout" .. self.id)
end

function ui.drawAll()
  term.clear()
  for _, element in pairs(ui.elements) do
    element:doDraw()
  end
end
