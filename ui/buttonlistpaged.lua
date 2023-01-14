require "ui.base"
require "ui.draw"
require "ui.text"
require "ui.buttonlist"

ui.buttonListPaged = {}

function ui.buttonListPaged.create(parent)
  local elem = ui.makeElement(parent)
  local buttonList = ui.buttonList.create(elem)

  function elem:onResize()
    buttonList:setSize(self.size.x, self.size.y - 2)
  end

  -- make a list view, probably need an "on resize" hook of some sort
  -- make the buttons and stuff at the bottom
  -- need headers support, maybe setHeader? sets the display text for a first row, for every page (naturally, reduces the row per page by 1)
  --   should support having and not having this
  -- provide a setOptions
  -- provide optional preProcess, which takes one elem from options and does something to it
  -- provide set page functions
  -- provide handleClick, passing in button, original data, parsed data and index

  -- if number of options is <= elem.size.y (or just <, if headers set), size up the list to the full elem and hide the page buttons

  -- also sort the recipes alphabetically, or maybe by recent? seems overkill and not worth the migration

  elem:invalidateLayout()
  return elem
end
