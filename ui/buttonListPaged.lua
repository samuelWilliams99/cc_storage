require "ui.base"
require "ui.draw"
require "ui.text"
require "ui.buttonList"

ui.buttonListPaged = {}

function ui.buttonListPaged.create(parent)
  local elem = ui.makeElement(parent)
  elem.buttonList = ui.buttonList.create(elem)
  elem.options = {}
  elem.page = 1
  function elem:preProcess(x)
    return x
  end

  function elem:onResize()
    self.buttonList:setSize(self.size.x, self.size.y - 2)
  end

  -- Either same format as buttonList, or arbitrary format alongside setPreProcess
  function elem:setOptions(options)
    self.options = options
  end

  -- Takes an element in options and converts to buttonList compliant entry
  function elem:setPreProcess(f)
    self.preProcess = f
  end

  function elem:getElemsPerPage()
    if #self.options > self.buttonList.size.y then
      return self.buttonList.size.y - 2
    end
    return self.buttonList.size.y
  end

  function elem:setPage(n)
    local pageCount = math.max(1, math.ceil(#self.options / self:getElemsPerPage()))
    self.page = math.max(1, math.min(pageCount, n))
    self:updatePage()
  end

  function elem:updatePage()

  end

  -- make a list view, probably need an "on resize" hook of some sort
  -- make the buttons and stuff at the bottom
  -- need headers support, maybe setHeader? sets the display text for a first row, for every page (naturally, reduces the row per page by 1)
  --   should support having and not having this
  -- provide a setOptions
  -- provide optional preProcess, which takes one elem from options and does something to it
  -- provide set page functions
  -- provide handleClick, passing in button, original data, parsed data and index

  -- if number of options is <= elem.size.y (or just <, if headers set), size up the list to the full elem and hide the page buttons

  -- also sort the recipes alphabetically, or maybe by recent? seems overkill and not worth the migration


  --[[

    local pageCounter = pages.elem(ui.text.create())
    local function updatePageCounter()
      local pageCountStr = tostring(pageCount)
      local pageStr = tostring(page)
      pageStr = string.rep(" ", #pageCountStr - #pageStr) .. pageStr
      local pageCounterStr = pageStr .. "/" .. pageCountStr

      pageCounter:setSize(#pageCounterStr, 1)
      pageCounter:setPos(math.floor(w / 2) - #pageStr, h - 1)
      pageCounter:setText(pageCounterStr)

      leftBtn:setText(page == 1 and "" or "<<<")
      leftBtn:setBgColor(page == 1 and colors.black or colors.gray)
      rightBtn:setText(page == pageCount and "" or ">>>")
      rightBtn:setBgColor(page == pageCount and colors.black or colors.gray)
    end

    updatePageCounter()

    local btnGap = 4

    local leftBtn = pages.elem(ui.text.create())
    leftBtn:setSize(3, 1)
    leftBtn:setPos(math.floor(w / 2) - 3 - btnGap, h - 1)
    leftBtn:setText("")

    local rightBtn = pages.elem(ui.text.create())
    rightBtn:setSize(3, 1)
    rightBtn:setPos(math.floor(w / 2) + btnGap + 1, h - 1)
    rightBtn:setText("")

    function leftBtn:onClick()
      if page == 1 then return end
      page = page - 1
      updateDisplay()
    end

    function rightBtn:onClick()
      if page == pageCount then return end
      page = page + 1
      updateDisplay()
    end

    -- maybe???
    with self:onRemove, but must call old onRemove
    hook.add("mouse_scroll", "menu_shift", function(dir)
      if dir == 1 then
        rightBtn:onClick()
      else
        leftBtn:onClick()
      end
    end)

  ]]

  elem:invalidateLayout()
  return elem
end
