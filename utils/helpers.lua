function filter(xs, p)
  local out = {}
  for i, x in ipairs(xs) do
    if p(x, i) then
      table.insert(out, x)
    end
  end
  return out
end

function startsWith(s, s2)
  return s:sub(1, #s2) == s2
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
