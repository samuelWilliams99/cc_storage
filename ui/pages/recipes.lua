require "ui.pages.pages"

local recipesPage = {}

pages.addPage("recipes", recipesPage)

local w, h = term.getSize()

local function addElem(elem)
  table.insert(recipesPage.elems, elem)
  return elem
end

function recipesPage.setup()
  recipesPage.elems = {}

  local backButton = addElem(ui.text.create())
  backButton:setPos(2, h - 4)
  backButton:setSize(10, 3)
  backButton:setTextDrawPos(3, 1)
  backButton:setText("Back")
  function backButton:onClick()
    pages.setPage("itemList")
  end

  -- Main title
  local titleText = "Recipe Manager"
  term.setCursorPos(math.floor(w / 2 - #titleText / 2), 2)
  term.write(titleText)

  -- Horizontal line
  term.setTextColor(colors.gray)
  term.setCursorPos(3, 4)
  term.write(string.rep("_", w - 4))

  -- Vertical line
  local lineX = 2 + math.floor((w - 4) * 0.4)
  for y = 5, h - 1 do
    term.setCursorPos(lineX, y)
    term.write("|")
  end
  term.setTextColor(colors.white)

  -- Count title
  local midLeftX = 2 + math.floor((w - 4) * 0.2)
  local countTitleText = "Recipe list (click to remove)"
  term.setCursorPos(math.ceil(midLeftX - #countTitleText / 2), 6)
  term.write(countTitleText)

  local recipesList = addElem(ui.buttonList.create())
  recipesList:setPos(2, 7)
  recipesList:setSize(lineX - 4, h - 13)
  
  local function updateRecipeList()
    local options = {}
    for name, recipe in pairs(storage.crafting.recipes) do
      if #options == recipesList.size.y then break end
      table.insert(options, {displayText = recipe.displayName, name = name})
    end
    recipesList:setOptions(options)
  end
  updateRecipeList()

  function recipesList:handleClick(_, data)
    storage.crafting.removeRecipe(data.name)
    updateRecipeList()
  end
end

function recipesPage.cleanup()
  for _, elem in ipairs(recipesPage.elems) do
    elem:remove()
  end
end
