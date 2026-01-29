require "ui.pages.pages"
require "ui.buttonListPaged"

local defragPage = {
  shouldMakeBackButton = true,
  title = "Defragment storage",
  configName = "Defragment storage"
}

pages.addPage("defrag", defragPage)

local w, h = term.getSize()

function defragPage.setup()
  local defragSummary = storage.getDefragSummary()

  local text = defragSummary.wastedSlotCount .. " slots, " .. defragSummary.suboptimalItemCount .. " items"
  term.setCursorPos(math.floor(w / 2 - #text / 2), math.floor(h / 2))
  term.write(text)
end

function defragPage.cleanup()

end
