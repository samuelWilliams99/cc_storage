require "ui.pages.pages"
require "ui.buttonListPaged"

local editItemListPage = {
  shouldMakeBackButton = true,
  title = "Item settings list",
  configName = "Item settings list"
}

pages.addPage("editItemList", editItemListPage)

local w, h = term.getSize()

function editItemListPage.setup()
  local itemSettings = storage.burnItems.getItemSettings()
  local burnTime = storage.burnItems.getNextBurnTime()
  local slotsUsed = storage.burnItems.getBurnSlotsUsed()
  local maxSlots = storage.burnItems.getMaxBurnSlots()

  local settingsList = pages.elem(ui.buttonListPaged.create())
  settingsList:setPos(2, 5)
  settingsList:setSize(w - 4, h - 10)
  settingsList:setHeader("Item name")
  function settingsList:handleClick(_, data)
    pages.setPage("editItem", data.itemKey, true)
  end

  local reclaimButton = pages.elem(ui.text.create())
  reclaimButton:setText("Reclaim items")
  reclaimButton:setPos(math.floor(w * 0.3) - 11, h - 4)
  reclaimButton:setSize(23, 3)
  reclaimButton:setTextDrawPos(5, 1)
  function reclaimButton:onClick()
    if slotsUsed == 0 then return end
    slotsUsed = 0
    storage.burnItems.reclaimItems()
  end

  local burnButton = pages.elem(ui.text.create())
  burnButton:setText("Burn items")
  burnButton:setPos(math.floor(w * 0.6) - 10, h - 4)
  burnButton:setSize(20, 3)
  burnButton:setTextDrawPos(5, 1)
  function burnButton:onClick()
    if slotsUsed == 0 then return end
    slotsUsed = 0
    storage.burnItems.burnChestNow()
  end

  local function updateActionButtons()
    if slotsUsed == 0 then
      reclaimButton:setTextColor(colors.black)
      reclaimButton:setBgColor(colors.black)
      burnButton:setTextColor(colors.black)
      burnButton:setBgColor(colors.black)
    else
      reclaimButton:setTextColor(colors.white)
      reclaimButton:setBgColor(colors.gray)
      burnButton:setTextColor(colors.white)
      burnButton:setBgColor(colors.gray)
    end
  end

  updateActionButtons()

  local function updateSettingsList()
    local options = {}
    for itemKey, itemSetting in pairs(itemSettings) do
      table.insert(options, {itemKey = itemKey, displayText = itemSetting.displayName})
    end
    settingsList:setOptions(options)
  end

  updateSettingsList()

  local function updateBurnTime()
    term.setCursorPos(w - 20, h - 3)
    term.write("                    ")
    if not burnTime then return end
    local time = os.unixTime()
    term.setCursorPos(w - 20, h - 3)
    term.write("Next burn: " .. os.date("%M:%S", math.max(burnTime - time, 0)))
  end

  local function updateSlotCount()
    term.setCursorPos(w - 20, h - 1)
    term.write("                    ")
    term.setCursorPos(w - 20, h - 1)
    term.write("Slots used: " .. slotsUsed .. "/" .. maxSlots)
  end

  updateSlotCount()
  updateBurnTime()

  timer.create("cc_burn_items_timer", 1, 0, updateBurnTime)

  hook.add("cc_burn_items_settings_change", "update_menu", function(_itemSettings)
    itemSettings = _itemSettings
    updateSettingsList()
  end)

  hook.add("cc_burn_items_next_burn_time", "update_menu", function(_burnTime)
    burnTime = _burnTime
  end)

  hook.add("cc_burn_items_slots_change", "update_menu", function(_slotsUsed)
    slotsUsed = _slotsUsed
    updateSlotCount()
    updateActionButtons()
  end)
end

function editItemListPage.cleanup()
  hook.remove("cc_burn_items_settings_change", "update_menu")
  hook.remove("cc_burn_items_next_burn_time", "update_menu")
  hook.remove("cc_burn_items_slots_change", "update_menu")
  timer.remove("cc_burn_items_timer")
end
