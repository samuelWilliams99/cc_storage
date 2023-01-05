require "utils.helpers"

storage.crafting.recipes = storage.crafting.recipes or {}

storage.crafting.recipeFilePath = "recipes.txt"

function storage.crafting.addRecipe(itemName, displayName, recipePlacement, count, maxStack, override)
  if not override and storage.crafting.recipes[itemName] then return end
  local rawRecipe = {
    itemName = itemName,
    displayName = displayName,
    recipePlacement = recipePlacement,
    count = count,
    maxStack = maxStack
  }
  storage.crafting.saveRecipe(rawRecipe)
  storage.crafting.preCacheRecipe(rawRecipe)
end

function storage.crafting.updateRecipe(itemName, rawRecipe)
  local recipeData = readFile(storage.crafting.recipeFilePath) or {}
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

  storage.crafting.addRecipe("minecraft:stick", "Stick", {[1] = "minecraft:oak_planks", [4] = "minecraft:oak_planks"}, 4, nil, true)
  storage.crafting.addRecipe("minecraft:oak_planks", "Oak Planks", {[1] = "minecraft:oak_log"}, 4, nil, true)
  storage.crafting.addRecipe("minecraft:wooden_sword552887824c43124013fd24f6edcde0fb", "Wooden Sword", {[2] = "minecraft:oak_planks", [5] = "minecraft:oak_planks", [8] = "minecraft:stick"}, nil, 1, true)
end

function storage.crafting.preCacheRecipe(rawRecipe)
  local count = rawRecipe.count or 1
  local maxStack = rawRecipe.maxStack or 64
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
    -- turtle has 16 slots, so can fit 16 * maxStack in its inventory
    maxCrafts = math.floor((16 * maxStack) / count)
  }
end
