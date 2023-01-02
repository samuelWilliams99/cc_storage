require "ui.pages.pages"

local craftCountPage = {}

pages.addPage("craftCount", craftCountPage)

local w = term.getSize()

local function addElem(elem)
  table.insert(craftCountPage.elems, elem)
  return elem
end

-- probably better to have a typing and button mode
-- click on the typing thing, you can type any number (including empty, for typing small numbers)
-- click outside it anywhere (buttons included - before the button handler), or press enter, it should parse the value and put the right thing
-- e.g., if it empty or 0, make it 1

-- once you have a value, you can press a "make plan" button
-- when the plan is made, it shows in a list view the ingredients, maybe paginated? (we'll have to abstract the pagination logic)

-- then theres a craft button which will actually run the plan and a cancel button that unreserves

-- later we'll need an active plans page.
-- for now though we can do a "x crafting plans running" in the corner or some shit

function craftCountPage.setup(itemName)
  craftCountPage.elems = {}
  local count = 1

  local countText = addElem(ui.text.create())
  countText:setPos(5, 5)
  countText:setSize(20, 1)
  countText:setText(tostring(count))

  -- bigger buttons +1 in all directions
  -- reset button - back to 1
  local function countChangeButton(num, x)
    local btn = addElem(ui.text.create())
    local str = tostring(num)
    if num > 0 then str = "+" .. str end
    str = " " .. str .. " "
    btn:setText(str)
    btn:setSize(#str, 3)
    btn:setTextDrawPos(0, 1)
    btn:setPos(math.floor(x * w - #str / 2), 10) -- 10?
    function btn:onClick()
      if count == 1 and num == 64 then count = 0 end -- If running +64 on 1, it should go to 64 for convenience
      count = math.max(count + num, 1)
      countText:setText(tostring(count))
      countText:invalidateLayout(true)
    end
  end

  countChangeButton(-64, 0.25)
  countChangeButton(-1, 0.4)
  countChangeButton(1, 0.6)
  countChangeButton(64, 0.75)

  -- hook.add("key", "key", function(num, ...)
  --   if isNumber(num) then
  --     count = count * 10 + num
  --   elseif num == backspace then
  --     count = math.floor(count / 10)
  --   end
  -- end)
end

function craftCountPage.cleanup()
  hook.remove("key", "key")
  for _, elem in ipairs(craftCountPage.elems) do
    elem:remove()
  end
end
