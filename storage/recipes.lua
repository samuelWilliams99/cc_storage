require "utils.helpers"

storage.crafting.recipes = storage.crafting.recipes or {}

storage.crafting.recipeFilePath = "recipes.txt"

local dropper = peripheral.find("minecraft:dropper")

function storage.crafting.hasDropper()
  return dropper and true or false
end

function storage.crafting.addRecipe(itemName, displayName, modName, recipePlacement, count, maxCount, names, override)
  if not override and storage.crafting.recipes[itemName] then return end
  local rawRecipe = {
    itemName = itemName,
    displayName = displayName,
    modName = modName,
    recipePlacement = recipePlacement,
    ingredientDisplayNames = names,
    count = count,
    maxCount = maxCount
  }
  storage.crafting.preCacheRecipe(rawRecipe)
  storage.crafting.saveRecipe(rawRecipe)
end

function storage.crafting.getRecipeDisplayNamesAndMods()
  local nameData = {}
  for itemName, recipe in pairs(storage.crafting.recipes) do
    nameData[itemName] = {displayName = recipe.displayName, modName = recipe.modName}
  end
  return nameData
end

function storage.crafting.updateRecipe(itemName, rawRecipe)
  local recipeData = readFile(storage.crafting.recipeFilePath) or {}
  recipeData[itemName] = rawRecipe
  writeFile(storage.crafting.recipeFilePath, recipeData)
  hook.run("cc_recipes_change", storage.crafting.getRecipeDisplayNamesAndMods())
end

function storage.crafting.removeRecipe(itemName)
  storage.crafting.recipes[itemName] = nil
  storage.crafting.updateRecipe(itemName, nil)
end

function storage.crafting.saveRecipe(rawRecipe)
  storage.crafting.updateRecipe(rawRecipe.itemName, rawRecipe)
end

function storage.crafting.loadRecipes()
  print("Loading recipes...")
  local recipeData = readFile(storage.crafting.recipeFilePath)

  if not recipeData then
    recipeData = {}
    writeFile(storage.crafting.recipeFilePath, recipeData)
    print("No recipe file found, created blank file.")
  else
    print("Precaching " .. table.count(recipeData) .. " recipes.")
  end

  for _, rawRecipe in pairs(recipeData) do
    storage.crafting.preCacheRecipe(rawRecipe)
  end
end

function storage.crafting.getRecipe(itemName)
  return storage.crafting.recipes[itemName]
end

-- move both to recipes
local function getChestAndWidth(isDropper, chestName)
  if isDropper then
    return dropper, 3
  else
    return peripheral.wrap(chestName), 9
  end
end

function storage.crafting.getPlacementFromInventory(isDropper, chestName)
  local chest, chestWidth = getChestAndWidth(isDropper, chestName)
  local items = chest.list()
  if table.isEmpty(items) then
    return false, "No recipe found"
  end
  local placement = {}
  local names = {}

  local recipeXPosition = 0

  while recipeXPosition <= chestWidth - 2 do
    recipeXPosition = recipeXPosition + 1
    if items[recipeXPosition] or items[recipeXPosition + chestWidth] or items[recipeXPosition + 2 * chestWidth] then
      break
    end
  end

  for i, item in pairs(items) do
    -- x, y such that top left is 1,1
    local x = ((i - 1) % chestWidth) + 1
    local y = math.floor((i - 1) / chestWidth) + 1
    if x > recipeXPosition + 2 then
      return false, "Recipe not within a 3x3 grid"
    end

    local slot = (y - 1) * 3 + x - recipeXPosition + 1
    
    if item.count ~= 1 then
      return false, "Must be 0 or 1 item in each slot"
    end
    local itemDetail = chest.getItemDetail(i)
    if itemDetail.damage and itemDetail.damage ~= 0 then
      return false, "Cannot use damaged items in recipe"
    end
    if itemDetail.enchantments then
      return false, "Cannot use enchanted items in recipe"
    end
    local itemKey = storage.getItemKey(item)
    placement[slot] = itemKey
    names[itemKey] = itemDetail.displayName
  end

  return true, placement, names
end

function storage.crafting.getCraftedItemFromInventory(isDropper, chestName)
  local chest = getChestAndWidth(isDropper, chestName)
  local items = chest.list()
  if table.count(items) ~= 1 then
    return false, "Cannot craft multiple item stacks/types"
  end
  local i, item = next(items)
  local itemDetail = chest.getItemDetail(i)
  if itemDetail.damage and itemDetail.damage ~= 0 then
    return false, "Cannot craft damaged items in recipe"
  end
  if itemDetail.enchantments then
    return false, "Cannot craft enchanted items in recipe"
  end
  local itemKey = storage.getItemKey(item)
  if storage.crafting.recipes[itemKey] then
    return false, "Recipe for this item already exists.\nTo replace, remove this recipe on the left"
  end
  local modName = string.gmatch(item.name, "([^:]+)")()
  return true, itemKey, itemDetail.displayName, modName, item.count, itemDetail.maxCount
end

function storage.crafting.preCacheRecipe(rawRecipe)
  local count = rawRecipe.count or 1
  local maxCount = rawRecipe.maxCount or 64
  local ingredients = {}
  for i = 1, 9 do
    if rawRecipe.recipePlacement[i] then
      ingredients[rawRecipe.recipePlacement[i]] = (ingredients[rawRecipe.recipePlacement[i]] or 0) + 1
    end
  end

  storage.crafting.recipes[rawRecipe.itemName] = {
    placement = rawRecipe.recipePlacement,
    ingredients = ingredients,
    ingredientDisplayNames = rawRecipe.ingredientDisplayNames,
    itemName = rawRecipe.itemName,
    count = count,
    displayName = rawRecipe.displayName,
    modName = rawRecipe.modName,
    -- max crafts to fit all output
    -- turtle has 16 slots, so can fit 16 * maxCount in its inventory
    maxCrafts = math.floor((16 * maxCount) / count)
  }
end
