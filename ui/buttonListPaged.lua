require "ui.base"
require "ui.draw"
require "ui.text"
require "ui.buttonList"

ui.buttonListPaged = {}

function ui.buttonListPaged.create(parent)
  local elem = ui.makeElement(parent)
  elem.buttonList = ui.buttonList.create(elem)

  function elem.buttonList:handleClick(btn, data)
    if data._isHeader then return end
    elem:handleClick(btn, data, elem.options[data.index], data.index)
  end

  elem.allowPageHide = true
  elem.options = {}
  elem.page = 1
  -- Header row
  elem.header = nil

  -- Takes an element in options and converts to buttonList compliant entry
  function elem:preProcess(x)
    return x
  end

  function elem:onResize()
    self.buttonList:setSize(self.size.x, self:getButtonListHeight())
  end

  function elem:setHeader(header)
    elem.header = header
  end

  function elem:setAllowPageHide(allowPageHide)
    self.allowPageHide = allowPageHide
  end

  -- Either same format as buttonList, or arbitrary format alongside setPreProcess
  function elem:setOptions(options)
    self.options = options
    self:updatePage()
  end

  function elem:setSplits(...)
    self.buttonList:setSplits(...)
  end

  function elem:getPageSize()
    local elemsPerPage = self.size.y
    if self.header then
      elemsPerPage = elemsPerPage - 1
    end
    if #self.options > elemsPerPage or not self.allowPageHide then
      elemsPerPage = elemsPerPage - 2
    end
    return elemsPerPage
  end

  function elem:getButtonListHeight()
    if #self.options > self.size.y or not self.allowPageHide then
      return self.size.y - 2
    end
    return self.size.y
  end

  function elem:getPageCount(pageSize)
    return math.max(1, math.ceil(#self.options / pageSize))
  end

  function elem:setPage(n, noUpdate)
    local pageSize = self:getPageSize()
    local pageCount = self:getPageCount(pageSize)
    self.page = math.max(1, math.min(pageCount, n))
    if not noUpdate then
      self:updatePage(pageSize, pageCount)
    end
  end

  function elem:updatePage(pageSize, pageCount)
    pageSize = pageSize or self:getPageSize()
    pageCount = pageCount or self:getPageCount(pageSize)

    if self.page > pageCount then self.page = pageCount end

    local startIndex = (self.page - 1) * pageSize + 1
    local options = {}
    if self.header then
      options[1] = {displayText = self.header, _isHeader = true}
    end
    for i = startIndex, math.min(startIndex + pageSize - 1, #self.options) do
      local option = self:preProcess(self.options[i])
      option.index = i
      table.insert(options, option)
    end
    
    local listHeight = self:getButtonListHeight()
    if self.buttonList.size.y ~= listHeight then
      self.buttonList:setSize(self.size.x, listHeight)
    end
    self.buttonList:setOptions(options)
    self:makeOrRemovePageButtons(pageCount)

    self:updatePageCounter(pageCount)
    self:invalidateLayout(true)
  end

  function elem:updatePageCounter(pageCount)
    if not self.pageCounter then return end
    local pageCountStr = tostring(pageCount)
    local pageStr = tostring(self.page)
    pageStr = string.rep(" ", #pageCountStr - #pageStr) .. pageStr
    local pageCounterStr = pageStr .. "/" .. pageCountStr

    self.pageCounter:setSize(#pageCounterStr, 1)
    self.pageCounter:setPos(math.floor(self.size.x / 2) - #pageStr, self.size.y - 1)
    self.pageCounter:setText(pageCounterStr)

    self.leftButton:setText(self.page == 1 and "" or "<<<")
    self.leftButton:setBgColor(self.page == 1 and colors.black or colors.gray)
    self.rightButton:setText(self.page == pageCount and "" or ">>>")
    self.rightButton:setBgColor(self.page == pageCount and colors.black or colors.gray)
  end

  function elem:makeOrRemovePageButtons(pageCount)
    if pageCount == 1 and self.allowPageHide then
      if not self.pageCounter then return end
      self.pageCounter:remove()
      self.pageCounter = nil
      self.leftButton:remove()
      self.leftButton = nil
      self.rightButton:remove()
      self.rightButton = nil
      return
    end
    if self.pageCounter then
      self.rightButton.pageCount = pageCount
      return
    end

    self.pageCounter = ui.text.create(self)

    local btnGap = 4
    local w, h = self.size.x, self.size.y

    self.leftButton = ui.text.create(self)
    self.leftButton:setSize(3, 1)
    self.leftButton:setPos(math.floor(w / 2) - 3 - btnGap, h - 1)
    self.leftButton:setText("")

    self.rightButton = ui.text.create(self)
    self.rightButton:setSize(3, 1)
    self.rightButton:setPos(math.floor(w / 2) + btnGap + 1, h - 1)
    self.rightButton:setText("")
    self.rightButton.pageCount = pageCount

    function self.leftButton:onClick()
      if self.parent.page == 1 then return end
      self.parent:setPage(self.parent.page - 1)
    end

    function self.rightButton:onClick()
      if self.parent.page == self.pageCount then return end
      self.parent:setPage(self.parent.page + 1)
    end
  end

  function elem:handleClick(btn, data, preData, i)
  end

  hook.add("mouse_scroll", "page_scroll_" .. elem.id, function(dir)
    if dir == 1 then
      if elem.rightButton then
        elem.rightButton:onClick()
      end
    else
      if elem.leftButton then
        elem.leftButton:onClick()
      end
    end
  end)
  
  local oldOnRemove = elem.onRemove
  function elem:onRemove()
    hook.remove("mouse_scroll", "page_scroll_" .. self.id)
    oldOnRemove(self)
  end

  elem:invalidateLayout()
  return elem
end
