require "ui.pages.pages"

local craftCountPage = {}

pages.addPage("craftCount", craftCountPage)

function craftCountPage.setup(item)
  print("So you wanna make an item, huh punk??")
  timer.simple(3, function() pages.setPage("itemList") end)
end

function craftCountPage.cleanup()

end
