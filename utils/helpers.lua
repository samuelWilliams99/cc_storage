function startsWith(s, s2)
  return s:sub(1, #s2) == s2
end

function table.filter(xs, p)
  local out = {}
  for i, x in ipairs(xs) do
    if p(x, i) then
      table.insert(out, x)
    end
  end
  return out
end

function table.map(t, f)
  local out = {}
  for k, v in pairs(t) do
    out[k] = f(v)
  end
  return out
end

function table.count(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

function table.isEmpty(t)
  return next(t) == nil
end

function table.keys(t)
  local out = {}
  for k in pairs(t) do
    table.insert(out, k)
  end
  return out
end

function table.removeByValue(t, valueToRemove)
  for k, v in pairs(t) do
    if v == valueToRemove then
      table.remove(t, k)
      break
    end
  end
end

function table.shallowCopy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

function readFile(path)
  local handle = io.open(path, "r")
  if not handle then return end
  local data = handle:read("a")
  handle:close()
  return textutils.unserialize(data)
end

function writeFile(path, t)
  local handle = io.open(path, "w")
  if not handle then error("Couldn't create file") end
  handle:write(textutils.serialize(t, {compact = true}))
  handle:close()
end

function handleFailure(success, msg, ...)
  if success then return msg, ... else error(msg, 2) end
end
