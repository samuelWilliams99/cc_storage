require "ui.pages.pages"
require "ui.checkbox"

local editItemPage = {
  shouldMakeBackButton = true
}

pages.addPage("editItem", editItemPage)

local w, h = term.getSize()

-- returns a setter
local function addOptionalNumberSetting(str, index, startValue, def, max, updateFunc)
  local y = 3 + index * 4
  local checkbox = pages.elem(ui.checkbox.create())
  checkbox:setPos(2, y + 1)
  checkbox:setSize(math.floor((w - 4) * 0.4), 1)
  checkbox:setText(str)
  checkbox:setChecked(startValue ~= nil)

  local numberInput
  
  local function makeOrRemoveNumberInput(val, noSelect)
    if val and not numberInput then
      numberInput = pages.elem(ui.numberInput.create())
      local x = 2 + math.floor((w - 4) * 0.5)
      numberInput:setPos(x, y)
      numberInput:setSize(w - 2 - x, 3)
      numberInput:setSelected(not noSelect)
      numberInput:setMax(max)
      function numberInput:onDeselect(newVal)
        timer.create("delay" .. str, 0.05, 1, function()
          if not numberInput then return end
          if newVal == 0 then
            numberInput:setValue(def)
            newVal = def
          end
          updateFunc(newVal)
        end)
      end
    elseif numberInput and not val then
      numberInput:remove()
      numberInput = nil
    end
    if not numberInput then return end
    numberInput:setValue(val)
    numberInput:invalidateLayout(true)
  end

  function checkbox:onChange(checked)
    local newVal = checked and def or nil
    makeOrRemoveNumberInput(newVal)
    updateFunc(newVal)
  end

  makeOrRemoveNumberInput(startValue, true)

  return function(newValue)
    checkbox:setChecked(newValue ~= nil)
    makeOrRemoveNumberInput(newValue)
  end
end

function editItemPage.setup(itemKey, returnToList)
  editItemPage.backButtonDest = returnToList and "editItemList" or "itemList"
  local itemName = storage.items[itemKey] and storage.items[itemKey].detail.displayName or storage.crafting.recipes[itemKey].displayName
  pages.writeTitle("Settings for " .. itemName)

  local midX = math.floor(w / 2)

  local hasRecipe = storage.crafting.getRecipeNames()[itemKey] and true or false
  local itemSetting = storage.burnItems.getItemSetting(itemKey)

  local amountText = pages.elem(ui.text.create())
  amountText:setBgColor(colors.black)
  amountText:setPos(2, 5)
  amountText:setSize(midX - 2, 1)

  local function updateAmountText()
    local amt = storage.items[itemKey] and storage.items[itemKey].count or 0
    amountText:setText("Amount in storage: " .. amt)
  end

  local hasRecipeText = pages.elem(ui.text.create())
  hasRecipeText:setBgColor(colors.black)
  hasRecipeText:setPos(midX, 5)
  hasRecipeText:setSize(midX - 1, 1)

  local function updateHasRecipeText()
    hasRecipeText:setText("Has Recipe: " .. (hasRecipe and "Yes" or "No"))
  end

  updateAmountText()
  updateHasRecipeText()

  local limitSetter = addOptionalNumberSetting("Item limit", 1, itemSetting.limit, 10000, 100000, function(new)
    storage.burnItems.setItemLimit(itemKey, new)
  end)

  hook.add("cc_burn_items_setting_change", "update_menu", function(_itemKey, _itemSetting)
    if itemKey ~= _itemKey then return end
    itemSetting = _itemSetting
    limitSetter(itemSetting.limit)
  end)

  hook.add("cc_storage_change", "update_menu", updateAmountText)

  hook.add("cc_recipes_change", "update_menu", function(recipes)
    hasRecipe = recipes[itemKey] and true or false
    updateHasRecipeText()
  end)
end

function editItemPage.cleanup()
  hook.remove("cc_burn_items_setting_change", "update_menu")
  hook.remove("cc_storage_change", "update_menu")
  hook.remove("cc_recipes_change", "update_menu")
end
