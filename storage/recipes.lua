require "utils.helpers"

storage.crafting.recipes = storage.crafting.recipes or {}

storage.crafting.recipeFilePath = "recipes.txt"

shell.run("cc_storage/debug/setupMonPrint")

function storage.crafting.addRecipe(itemName, displayName, recipePlacement, count, maxCount, names, override)
  if not override and storage.crafting.recipes[itemName] then return end
  local rawRecipe = {
    itemName = itemName,
    displayName = displayName,
    recipePlacement = recipePlacement,
    ingredientDisplayNames = names,
    count = count,
    maxCount = maxCount
  }
  storage.crafting.saveRecipe(rawRecipe)
  storage.crafting.preCacheRecipe(rawRecipe)
end

local function migrateRecipes(recipeData)
  -- TODO: remove this after migration
  -- also the code in precache
  local missing = {}
  for _, r in pairs(recipeData) do
    if r.maxStack then
      r.maxCount = r.maxStack
      r.maxStack = nil
    end
    r.ingredientDisplayNames = r.ingredientDisplayNames or {}  
    for _, itemName in pairs(r.recipePlacement) do
      if not r.ingredientDisplayNames[itemName] then
        if storage.items[itemName] then
          r.ingredientDisplayNames[itemName] = storage.items[itemName].detail.displayName
        elseif recipeData[itemName] then
          r.ingredientDisplayNames[itemName] = recipeData[itemName].displayName
        else
          missing[itemName] = true
        end
      end
    end
  end
  for itemName in pairs(missing) do
    printMon(itemName)
  end
end

function storage.crafting.updateRecipe(itemName, rawRecipe)
  local recipeData = readFile(storage.crafting.recipeFilePath) or {}
  migrateRecipes(recipeData)
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
    ingredientDisplayNames = rawRecipe.ingredientDisplayNames,
    itemName = rawRecipe.itemName,
    count = count,
    displayName = rawRecipe.displayName,
    -- max crafts to fit all output
    -- turtle has 16 slots, so can fit 16 * maxCount in its inventory
    maxCrafts = math.floor((16 * maxCount) / count)
  }
end
