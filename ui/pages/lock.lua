require "ui.pages.pages"
require "utils.helpers"

local lockPage = {}

pages.addPage("lock", lockPage)

local w, h = term.getSize()

function lockPage.setup()
  hook.add("terminate", "preventTerminate", function()
    return true
  end)

  local text = "Awaiting fingerprint..."
  term.setCursorPos(math.floor(w / 2 - #text / 2), math.floor(h / 2))
  term.setTextColor(colors.gray)
  term.write(text)
  term.setTextColor(colors.white)
end

function lockPage.cleanup()
  hook.remove("terminate", "preventTerminate")
end
