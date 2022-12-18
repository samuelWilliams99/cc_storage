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