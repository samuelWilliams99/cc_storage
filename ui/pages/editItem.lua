require "ui.pages.pages"

local editItemPage = {
  shouldMakeBackButton = true
}

pages.addPage("editItem", editItemPage)

local w, h = term.getSize()

function editItemPage.setup(itemKey)
  local itemName = storage.items[itemKey] and storage.items[itemKey].detail.displayName or storage.crafting.recipes[itemKey].displayName
  pages.writeTitle("Settings for " .. itemName)

  local itemSetting = storage.burnItems.getItemSetting(itemKey)
  -- Use storage.burnItems.setItemLimit to update the limit, maybe a typeable box or numpad thing like with crafting?
  -- Need some way to remove limits tho

  hook.add("cc_burn_items_settings_change", "update_menu", function(_itemKey, _itemSetting)
    if itemKey ~= _itemKey then return end
    itemSetting = _itemSetting
    -- Update some menu
  end)
end

function editItemPage.cleanup()
  hook.remove("cc_burn_items_settings_change", "update_menu")
end
