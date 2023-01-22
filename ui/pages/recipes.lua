require "ui.pages.pages"
require "ui.logger"
require "ui.buttonListPaged"

local recipesPage = {
  shouldMakeBackButton = true,
  title = "Recipe Manager",
  configName = "Recipe Manager"
}

-- TODO: Recipe made on phone was broken

pages.addPage("recipes", recipesPage)

local w, h = term.getSize()

function recipesPage.setup()
  local recipeNames = storage.crafting.getRecipeNames()
  recipesPage.addRecipeStep = 1

  -- Vertical line
  term.setTextColor(colors.gray)
  local lineX = 2 + math.floor((w - 4) * 0.4)
  for y = 5, h - 1 do
    term.setCursorPos(lineX, y)
    term.write("|")
  end
  term.setTextColor(colors.white)

  -- Recipe list title
  local midLeftX = 2 + math.floor((w - 4) * 0.2)
  local recipesTitleText = "Recipe list"
  term.setCursorPos(math.ceil(midLeftX - #recipesTitleText / 2), 6)
  term.write(recipesTitleText)

  local removeText = "Click twice to remove"
  term.setCursorPos(math.ceil(midLeftX - #removeText / 2), 7)
  term.setTextColor(colors.gray)
  term.write(removeText)
  term.setTextColor(colors.white)

  local recipesList = pages.elem(ui.buttonListPaged.create())
  recipesList:setPos(2, 8)
  recipesList:setSize(lineX - 4, h - 14)

  local selectedToRemove = nil
  
  local function updateRecipeList()
    local options = {}
    for name, displayName in pairs(recipeNames) do
      table.insert(options, {displayText = displayName, name = name, bgColor = selectedToRemove == name and colors.red or nil})
    end
    table.sort(options, function(a, b) return a.displayText < b.displayText end)
    recipesList:setOptions(options)
  end
  updateRecipeList()

  function recipesList:handleClick(_, data)
    if selectedToRemove == data.name then
      selectedToRemove = nil
      timer.remove("recipeListRemoveTimeout")
      storage.crafting.removeRecipe(data.name)
    else
      selectedToRemove = data.name
      timer.create("recipeListRemoveTimeout", 1, 1, function()
        selectedToRemove = nil
        updateRecipeList()
      end)
      updateRecipeList()
    end
  end

  local cancelButton = pages.elem(ui.text.create())
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

  local instructionsPanel = pages.elem(ui.logger.create())
  instructionsPanel:setPos(lineX + 2, 5)
  instructionsPanel:setSize(w - lineX - 5, h - 10)

  updateCancelbutton()

  local addRecipeButton = pages.elem(ui.text.create())
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
      addRecipeButton:setTextColor(colors.white)
      addRecipeButton:setBgColor(colors.gray)
    else
      addRecipeButton:setTextColor(colors.black)
      addRecipeButton:setBgColor(colors.black)
    end
  end

  function cancelButton:onClick()
    recipesPage.addRecipeStep = 1
    recipesPage.placement = nil
    recipesPage.names = nil
    recipesPage.removeLastLines = nil
    if storage.remote.isRemote then
      storage.enderChest.itemPauseChest(storage.remote.clientChestName)
      storage.enderChest.unpauseChest(storage.remote.clientChestName)
    end
    updateCancelbutton()
    updateAddRecipeButton()
    instructionsPanel:clear()
  end

  updateAddRecipeButton()

  function addRecipeButton:onClick()
    if not recipesPage.addRecipeStep then return end
    for _ = 1, recipesPage.removeLastLines or 0 do
      instructionsPanel:removeLastLine()
    end
    recipesPage.removeLastLines = nil

    if recipesPage.addRecipeStep == 1 then
      instructionsPanel:clear()
      recipesPage.addRecipeStep = 2
      updateCancelbutton()
      updateAddRecipeButton()
      local chestText = "the dropper"
      if storage.remote.isRemote then
        storage.enderChest.pauseChest(storage.remote.clientChestName)
        chestText = "your ender chest"
      end
      instructionsPanel:writeText("Creating a new recipe! Please place the recipe into " .. chestText .. ", then hit Continue.")
      instructionsPanel:newLine()
    elseif recipesPage.addRecipeStep == 2 then
      instructionsPanel:writeText("Scanning recipe...")
      recipesPage.addRecipeStep = nil
      updateAddRecipeButton()
      local success, placement, names = storage.crafting.getPlacementFromInventory(not storage.remote.isRemote, storage.remote.clientChestName)
      if success then
        recipesPage.placement = placement
        recipesPage.names = names
        recipesPage.addRecipeStep = 3
        updateAddRecipeButton()
        instructionsPanel:removeLastLine()
        instructionsPanel:writeText("Scanning recipe... Successful!", colors.green)
        instructionsPanel:newLine()
        instructionsPanel:writeText("Place the crafted items (with correct count) in the dropper then hit Continue.")
        instructionsPanel:newLine()
      else
        local errorMessage = placement
        recipesPage.addRecipeStep = 2
        updateAddRecipeButton()
        instructionsPanel:removeLastLine()
        instructionsPanel:writeText("Scanning recipe... Failed!", colors.red)
        instructionsPanel:writeText(errorMessage, colors.red)
        instructionsPanel:newLine()
        instructionsPanel:writeText("Please fix the recipe and hit Continue.")
        recipesPage.removeLastLines = 4
      end
    elseif recipesPage.addRecipeStep == 3 then
      instructionsPanel:writeText("Scanning crafted items...")
      recipesPage.addRecipeStep = nil
      updateAddRecipeButton()
      local success, itemName, displayName, count, maxCount = storage.crafting.getCraftedItemFromInventory(not storage.remote.isRemote, storage.remote.clientChestName)
      if success then
        storage.crafting.addRecipe(itemName, displayName, recipesPage.placement, count, maxCount, recipesPage.names)
        if storage.remote.isRemote then
          storage.enderChest.itemPauseChest(storage.remote.clientChestName)
          storage.enderChest.unpauseChest(storage.remote.clientChestName)
        end
        recipesPage.addRecipeStep = 1
        recipesPage.placement = nil
        recipesPage.names = nil
        updateAddRecipeButton()
        updateCancelbutton()
        instructionsPanel:removeLastLine()
        instructionsPanel:writeText("Scanning crafted items... Successful!", colors.green)
        instructionsPanel:newLine()
        instructionsPanel:writeText("Added recipe for " .. displayName .. " to database.", colors.green)
      else
        local errorMessage = itemName
        recipesPage.addRecipeStep = 3
        updateAddRecipeButton()
        instructionsPanel:removeLastLine()
        instructionsPanel:writeText("Scanning crafted items... Failed!", colors.red)
        instructionsPanel:writeText(errorMessage, colors.red)
        instructionsPanel:newLine()
        instructionsPanel:writeText("Please fix the crafted items and hit Continue.")
        recipesPage.removeLastLines = 4
      end
    end
    -- later, add thing for oredict
    -- as well as option for computer to take items from recipe
  end

  hook.add("cc_recipes_change", "update_menu", function(_recipeNames)
    recipeNames = _recipeNames
    updateRecipeList()
  end)
end

function recipesPage.cleanup()
  hook.remove("cc_recipes_change", "update_menu")
  if storage.remote.isRemote then
    storage.enderChest.itemPauseChest(storage.remote.clientChestName)
    storage.enderChest.unpauseChest(storage.remote.clientChestName)
  end
end
