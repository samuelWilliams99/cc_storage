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

  -- Recipe list title
  local midLeftX = 2 + math.floor((w - 4) * 0.2)
  local recipesTitleText = "Recipe list (click to remove)"
  term.setCursorPos(math.ceil(midLeftX - #recipesTitleText / 2), 6)
  term.write(recipesTitleText)

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

  local cancelButton = addElem(ui.text.create())
  cancelButton:setPos(lineX + 2, h - 4)
  cancelButton:setSize(12, 3)
  cancelButton:setTextDrawPos(3, 1)
  cancelButton:setText("Cancel")
  function cancelButton:onClick()
    recipesPage.addRecipeStep = nil
    -- do some other stuff
  end

  local function updateCancelbutton()
    if not recipesPage.addRecipeStep then
      cancelButton:setTextColor(colors.white)
      cancelButton:setBgColor(colors.gray)
    else
      cancelButton:setTextColor(colors.black)
      cancelButton:setBgColor(colors.black)
    end
    cancelButton:invalidateLayout(true)
  end

  updateCancelbutton()

  local addRecipeButton = addElem(ui.text.create())
  addRecipeButton:setPos(lineX + 2 + 12 + 2, 7)
  addRecipeButton:setSize(w - lineX - 4 - 12 - 4, 3)
  addRecipeButton:setTextDrawPos(math.floor(addRecipeButton.size.x / 2) - 5, 1)
  addRecipeButton:setText("Add recipe")
  function addRecipeButton:onClick()
    
  end

  -- Make the add recipe menu
  -- have a button saying "add recipe", it gives steps on the right
  -- Put the recipe in the dropper then hit continue -- check if empty
  -- put the crafted item (and amount) in the dropper and hit continue -- check if empty
  -- should this recipe use oredict? -- default to no, or well, dont even implement yet lol
  -- also, need to save ingredient displaynames
  -- added
end

function recipesPage.cleanup()
  for _, elem in ipairs(recipesPage.elems) do
    elem:remove()
  end
end
