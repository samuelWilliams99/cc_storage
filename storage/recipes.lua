require "utils.helpers"

storage.crafting.recipes = storage.crafting.recipes or {}

storage.crafting.recipeFilePath = "recipes.txt"

function storage.crafting.addRecipe(itemName, displayName, recipePlacement, count, maxCount, names, override)
  -- TODO: use names (itemName: displayName), could put crafted item displayName in there
  if not override and storage.crafting.recipes[itemName] then return end
  local rawRecipe = {
    itemName = itemName,
    displayName = displayName,
    recipePlacement = recipePlacement,
    count = count,
    maxCount = maxCount
  }
  storage.crafting.saveRecipe(rawRecipe)
  storage.crafting.preCacheRecipe(rawRecipe)
end

function storage.crafting.updateRecipe(itemName, rawRecipe)
  local recipeData = readFile(storage.crafting.recipeFilePath) or {}
  -- TODO: remove this after migration
  -- also the code in precache
  for _, r in pairs(recipeData) do
    if r.maxStack then
      r.maxCount = r.maxStack
      r.maxStack = nil
    end
  end
  recipeData[itemName] = rawRecipe
  writeFile(storage.crafting.recipeFilePath, recipeData)
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

function storage.crafting.preCacheRecipe(rawRecipe)
  local count = rawRecipe.count or 1
  local maxCount = rawRecipe.maxCount or rawRecipe.maxStack or 64 -- Support maxStack for legacy
  local ingredients = {}
  for i = 1, 9 do
    if rawRecipe.recipePlacement[i] then
      ingredients[rawRecipe.recipePlacement[i]] = (ingredients[rawRecipe.recipePlacement[i]] or 0) + 1
    end
  end

  storage.crafting.recipes[rawRecipe.itemName] = {
    placement = rawRecipe.recipePlacement,
    ingredients = ingredients,
    itemName = rawRecipe.itemName,
    count = count,
    displayName = rawRecipe.displayName,
    -- max crafts to fit all output
    -- turtle has 16 slots, so can fit 16 * maxCount in its inventory
    maxCrafts = math.floor((16 * maxCount) / count)
  }
end
