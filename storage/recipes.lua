dofile("cc_storage/utils/helpers.lua")

storage.crafting.recipes = storage.crafting.recipes or {}

storage.crafting.recipeFilePath = "recipes.txt"

function storage.crafting.addRecipe(itemName, displayName, recipePlacement, count, override)
  if not override and storage.crafting.recipes[itemName] then return end
  local rawRecipe = {
    itemName = itemName,
    displayName = displayName,
    recipePlacement = recipePlacement,
    count = count
  }
  storage.crafting.saveRecipe(rawRecipe)
  storage.crafting.preCacheRecipe(rawRecipe)
end

function storage.crafting.saveRecipe(rawRecipe)
  local recipeData = readFile(storage.crafting.recipeFilePath)
  recipeData[rawRecipe.itemName] = rawRecipe
  writeFile(storage.crafting.recipeFilePath, recipeData)
end

function storage.crafting.loadRecipes()
  local recipeData = readFile(storage.crafting.recipeFilePath)
  if not recipeData then return end
  for _, rawRecipe in pairs(recipeData) do
    storage.crafting.preCacheRecipe(rawRecipe)
  end

  storage.crafting.addRecipe("minecraft:stick", "Stick", {[1] = "minecraft:oak_planks", [4] = "minecraft:oak_planks"}, 4)
  storage.crafting.addRecipe("minecraft:oak_planks", "Oak Planks", {[1] = "minecraft:oak_log"}, 4)
  storage.crafting.addRecipe("minecraft:wooden_sword", "Wooden Planks", {[2] = "minecraft:oak_planks", [5] = "minecraft:oak_planks", [8] = "minecraft:stick"}, 1)
end

function storage.crafting.preCacheRecipe(rawRecipe)
  local count = rawRecipe.count or 1
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
    displayName = rawRecipe.displayName
  }
end
