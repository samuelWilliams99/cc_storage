require "ui.pages.pages"
require "ui.logger"

local dropper = peripheral.find("minecraft:dropper")
if not dropper then error("No dropper found, please connect one to the computer to use") end

local recipesPage = {}

pages.addPage("recipes", recipesPage)

local w, h = term.getSize()

local function addElem(elem)
  table.insert(recipesPage.elems, elem)
  return elem
end

local function getPlacementFromDropper()
  local items = dropper.list()
  if table.isEmpty(items) then
    return false, "No recipe in dropper"
  end
  local placement = {}
  for i, item in pairs(items) do
    if item.count ~= 1 then
      return false, "Must be 0 or 1 item in each slot"
    end
    local itemDetail = dropper.getItemDetail(i)
    if itemDetail.damage and itemDetail.damage ~= 0 then
      return false, "Cannot use damaged items in recipe"
    end
    if itemDetail.enchantments then
      return false, "Cannot use enchanted items in recipe"
    end
    local itemKey = storage.getItemKey(item, itemDetail)
    placement[i] = itemKey
  end

  return true, placement
end

function recipesPage.setup()
  recipesPage.elems = {}
  recipesPage.addRecipeStep = 1

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

  local function updateCancelbutton()
    if recipesPage.addRecipeStep ~= 1 then
      cancelButton:setTextColor(colors.white)
      cancelButton:setBgColor(colors.gray)
    else
      cancelButton:setTextColor(colors.black)
      cancelButton:setBgColor(colors.black)
    end
    cancelButton:invalidateLayout(true)
  end

  local instructionsPanel = addElem(ui.logger.create())
  instructionsPanel:setPos(lineX + 2, 5)
  instructionsPanel:setSize(w - lineX - 5, h - 10)

  updateCancelbutton()

  local addRecipeButton = addElem(ui.text.create())
  addRecipeButton:setPos(lineX + 2 + 12 + 2, h - 4)
  addRecipeButton:setSize(w - lineX - 4 - 12 - 4 - 12 - 2, 3)
  local function updateAddRecipeButton()
    if recipesPage.addRecipeStep == 1 then
      addRecipeButton:setTextDrawPos(math.floor(addRecipeButton.size.x / 2) - 5, 1)
      addRecipeButton:setText("Add recipe")
    else
      addRecipeButton:setTextDrawPos(math.floor(addRecipeButton.size.x / 2) - 4, 1)
      addRecipeButton:setText("Continue")
    end
    if recipesPage.addRecipeStep then
      cancelButton:setTextColor(colors.white)
      cancelButton:setBgColor(colors.gray)
    else
      cancelButton:setTextColor(colors.black)
      cancelButton:setBgColor(colors.black)
    end
  end

  function cancelButton:onClick()
    recipesPage.addRecipeStep = 1
    recipesPage.placement = nil
    recipesPage.removeLastLines = nil
    updateCancelbutton()
    updateAddRecipeButton()
    instructionsPanel:clear()
  end

  updateAddRecipeButton()

  function addRecipeButton:onClick()
    if not recipesPage.addRecipeStep then return end
    for i = 1, recipesPage.removeLastLines or 0 do
      instructionsPanel:removeLastLine()
    end

    if recipesPage.addRecipeStep == 1 then
      recipesPage.addRecipeStep = 2
      updateCancelbutton()
      updateAddRecipeButton()
      instructionsPanel:writeText("Creating a new recipe! Please place the recipe into the dropper, then hit Continue.")
    elseif recipesPage.addRecipeStep == 2 then
      instructionsPanel:writeText("Scanning recipe...")
      recipesPage.addRecipeStep = nil
      updateAddRecipeButton()
      local success, data = getPlacementFromDropper()
      if success then
        recipesPage.placement = data
        recipesPage.addRecipeStep = 3
        updateAddRecipeButton()
        instructionsPanel:removeLastLine()
        instructionsPanel:writeText("Scanning recipe... Successful!")
        instructionsPanel:newLine()
        instructionsPanel:writeText("Place the crafted items (with correct count) in the dropper then hit Continue.")
      else
        recipesPage.addRecipeStep = 2
        updateAddRecipeButton()
        instructionsPanel:removeLastLine()
        instructionsPanel:writeText("Scanning recipe... Failed!")
        instructionsPanel:writeText(data)
        instructionsPanel:writeText("Please fix the recipe and hit Continue.")
        recipesPage.removeLastLines = 3
      end
    elseif recipesPage.addRecipeStep == 3 then
      -- same again, check empty, and not more than 1 slot
      -- also check we dont have a recipe for that already
      -- if all good, add it and move on
    end
    -- later, add thing for oredict
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
