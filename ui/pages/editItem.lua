require "ui.pages.pages"

local editItemPage = {
  shouldMakeBackButton = true
}

pages.addPage("editItem", editItemPage)

local w, h = term.getSize()

function editItemPage.setup(itemKey)
  local itemName = storage.items[itemKey] and storage.items[itemKey].detail.displayName or storage.crafting.recipes[itemKey].displayName
  pages.writeTitle("Settings for " .. itemName)
end
