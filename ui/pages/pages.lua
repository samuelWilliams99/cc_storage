pages = {}
pages.pages = {}

local w, h = term.getSize()

function pages.addBackButton(page)
  local text = page.backButtonText or "Back"
  local backButton = pages.elem(ui.text.create())
  backButton:setPos(2, h - 4)
  backButton:setSize(6 + #text, 3)
  backButton:setTextDrawPos(3, 1)
  backButton:setText(text)
  function backButton:onClick()
    pages.setPage(page.backButtonDest or "itemList")
  end
end

function pages.writeTitle(text, noLine)
  -- Main title
  local titleText = text
  term.setCursorPos(math.floor(w / 2 - #titleText / 2), 2)
  term.write(titleText)

  if noLine then return end
  -- Horizontal line
  term.setTextColor(colors.gray)
  term.setCursorPos(3, 4)
  term.write(string.rep("_", w - 4))
  term.setTextColor(colors.white)
end

-- Adds an element to the active page, deletes on cleanup
function pages.elem(elem)
  if not pages.activePage then return elem end
  table.insert(pages.pages[pages.activePage].elems, elem)
  return elem
end

function pages.addPage(name, page)
  pages.pages[name] = page
  page.pageName = name
  page.elems = {}
end

function pages.setPage(name, ...)
  if pages.activePage then
    pages.pages[pages.activePage].active = false
    local cleanup = pages.pages[pages.activePage].cleanup
    if cleanup then cleanup() end
    for _, elem in ipairs(pages.pages[pages.activePage].elems) do
      elem:remove()
    end
  end
  if not pages.pages[name] then error("Page " .. name .. " does not exist") end
  local newPage = pages.pages[name]
  newPage.active = true
  pages.activePage = name
  term.clear()
  term.setCursorPos(1, 1)
  if newPage.title then
    pages.writeTitle(newPage.title, newPage.noLine)
  end
  if newPage.shouldMakeBackButton then
    pages.addBackButton(newPage)
  end
  newPage.setup(...)
end
