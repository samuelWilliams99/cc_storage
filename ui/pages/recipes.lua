require "ui.pages.pages"

local recipesPage = {}

pages.addPage("recipes", recipesPage)

local w, h = term.getSize()

local function addElem(elem)
  table.insert(recipesPage.elems, elem)
  return elem
end

function recipesPage.setup()
  local backButton = addElem(ui.text.create())
  backButton:setPos(2, h - 4)
  backButton:setSize(11, 3)
  backButton:setTextDrawPos(3, 1)
  backButton:setText("Back")
  function backButton:onClick()
    pages.setPage("itemList")
  end
end

function recipesPage.cleanup()
  for _, elem in ipairs(craftCountPage.elems) do
    elem:remove()
  end
end
