dofile("cc_storage/utils/hooks.lua")
dofile("cc_storage/utils/timer.lua")

ui = {}
ui.elements = {}
ui.elementIdCounter = 0

ui.classes = {}
ui.classes.Base = {}
local Base = ui.classes.Base

function Base:draw() end

-- 1 = Left, 2 = Right, 3 = Middle
function Base:onClick(btn) end

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
  if not self:isInBounds(x, y, self.size.x, self.size.y) then error("Tried to move such that the element is out of bounds") end
  self.pos.x = x
  self.pos.y = y
  self:invalidateLayout()
end

function Base:setSize(w, h)
  if not self:isInBounds(self.pos.x, self.pos.y, w, h) then error("Tried to move such that the element is out of bounds") end
  self.size.x = w
  self.size.y = h
  self:invalidateLayout()
end

function Base:setPosAndSize(x, y, w, h)
  if not self:isInBounds(x, y, w, h) then error("Tried to move such that the element is out of bounds") end
  self.pos.x = x
  self.pos.y = y
  self.size.x = w
  self.size.y = h
  self:invalidateLayout()
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

hook.add("mouse_click", "ui_click", function(btn, x, y)
  print(x, y)
  -- for k = #ui.elements, 1, -1 do
  --   local element = ui.elements[k]
  --   local clickedElement = getAtPosition(x, y, element)
  --   if clickedElement then
  --     clickedElement:onClick(btn)
  --     break
  --   end
  -- end
end)

local function getAtPosition(x, y, element)
  if x < element.pos.x or x > element.pos.x + element.size.x then return end
  if y < element.pos.y or y > element.pos.y + element.size.y then return end

  local relX, relY = x - element.pos.x, y - element.pos.y

  for k = #element.children, 1, -1 do
    local child = element.children[k]
    local atPosition = getAtPosition(relX, relY)
    if atPosition then return atPosition end
  end

  return element
end
