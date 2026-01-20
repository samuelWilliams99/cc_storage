require "utils.hooks"
require "utils.timer"

ui = ui or {}
ui.elements = ui.elements or {}
ui.elementIdCounter = ui.elementIdCounter or 0

ui.classes = {}
ui.classes.Base = {}
local Base = ui.classes.Base

function Base:draw() end

-- 1 = Left, 2 = Right, 3 = Middle
-- Not defined for non buttons
-- Note that by adding an onclick, the element becomes capable of taking a click event, and as such will prevent any parents from recieving the event
-- function Base:onClick(btn) end

function Base:localisePosition(x, y)
  if x < 0 or x > self.size.x then error("Localised outside of element") end
  if y < 0 or y > self.size.y then error("Localised outside of element") end
  local newX, newY = x + self.pos.x, y + self.pos.y
  if self.parent then
    return self.parent:localisePosition(newX, newY)
  else
    return newX, newY
  end
end

function Base:isInBounds(x, y, w, h)
  local wBound, hBound = term.getSize()
  if self.parent then
    wBound, hBound = self.parent.size.x, self.parent.size.y
  end
  if x < 0 or x + w > wBound then return false end
  if y < 0 or y + h > hBound then return false end
  return true
end

function Base:setPos(x, y)
  if not self:isInBounds(x, y, self.size.x, self.size.y) then error("Tried to move such that the element " .. self.id .. " is out of bounds") end
  self.pos.x = x
  self.pos.y = y
  self:invalidateLayout()
end

function Base:setSize(w, h)
  if not self:isInBounds(self.pos.x, self.pos.y, w, h) then error("Tried to move such that the element " .. self.id .. " is out of bounds") end
  self.size.x = w
  self.size.y = h
  self:onResize()
  self:invalidateLayout()
end

function Base:setPosAndSize(x, y, w, h)
  if not self:isInBounds(x, y, w, h) then error("Tried to move such that the element " .. self.id .. " is out of bounds") end
  self.pos.x = x
  self.pos.y = y
  self.size.x = w
  self.size.y = h
  self:onResize()
  self:invalidateLayout()
end

function Base:onResize()
end

function Base:remove()
  if self.removed then return end
  if self.onRemove then self:onRemove() end
  self.removed = true
  if self.parent then
    table.removeByValue(self.parent.children, self)
  else
    table.removeByValue(ui.elements, self)
  end
  for _, child in ipairs(self.children) do
    child:remove()
  end
  if self.parent and not self.parent.removed then
    self.parent:invalidateLayout()
  end
end

function Base:enable()
  if self.removed then return end
  self.disabled = false
end

function Base:disable()
  if self.removed then return end
  self.disabled = false
end

function Base:isEnabled()
  return not self.disabled
end

function ui.makeElement(parent)
  local element = {}
  ui.elementIdCounter = ui.elementIdCounter + 1
  element.pos = ui.Vector(0, 0)
  element.size = ui.Vector(0, 0)
  element.parent = parent
  element.children = {}
  element.id = ui.elementIdCounter
  if parent then
    table.insert(parent.children, element)
  else
    table.insert(ui.elements, element)
  end
  setmetatable(element, {__index = Base})
  return element
end

local function getAtPosition(x, y, element, deepest)
  if element.disabled then return end
  if x < element.pos.x + 1 or x > element.pos.x + element.size.x then return end
  if y < element.pos.y + 1 or y > element.pos.y + element.size.y then return end

  local relX, relY = x - element.pos.x, y - element.pos.y

  if element.onClick then deepest = element end

  for k = #element.children, 1, -1 do
    local child = element.children[k]
    local atPosition = getAtPosition(relX, relY, child, deepest)
    if atPosition then return atPosition end
  end

  return deepest
end

hook.add("mouse_click", "ui_click", function(btn, x, y)
  for k = #ui.elements, 1, -1 do
    local element = ui.elements[k]
    local clickedElement = getAtPosition(x, y, element)
    if clickedElement then
      clickedElement:onClick(btn)
      break
    end
  end
end)
