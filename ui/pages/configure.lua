require "ui.pages.pages"

-- Set `configName` on a page for it to show here

local configurePage = {
  shouldMakeBackButton = true,
  title = "Configuration pages"
}

pages.addPage("configure", configurePage)

function configurePage.setupOtherPages()
  for _, page in pairs(pages.pages) do
    if page.configName then
      page.backButtonDest = "configure"
    end
  end
end

local w = term.getSize()

function configurePage.setup()
  local configPages = {}
  for _, page in pairs(pages.pages) do
    if page.configName then
      local shouldAdd = true
      if page.configCondition then shouldAdd = page.configCondition() end
      if shouldAdd then table.insert(configPages, page) end
    end
  end

  table.sort(configPages, function(a, b) return a.configName < b.configName end)

  for i, page in ipairs(configPages) do
    local pageButton = pages.elem(ui.text.create())
    pageButton:setSize(w - 8, 3)
    pageButton:setPos(4, i * 4 + 1)
    pageButton:setTextDrawPos(math.floor(pageButton.size.x / 2 - #page.configName / 2), 1)
    pageButton:setText(page.configName)
    function pageButton:onClick()
      pages.setPage(page.pageName)
    end
  end
end
