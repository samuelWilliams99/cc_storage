pages = {}
pages.pages = {}

function pages.addPage(name, page)
  pages.pages[name] = page
end

function pages.setPage(name, ...)
  if pages.activePage then
    pages.pages[pages.activePage].active = false
    pages.pages[pages.activePage].cleanup()
  end
  if not pages.pages[name] then error("Page " .. name .. " does not exist") end
  pages.pages[name].active = true
  pages.pages[name].setup(...)
  pages.activePage = name
end
