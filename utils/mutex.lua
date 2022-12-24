mutex = {}

function mutex.create()
    return {locked = false, waiting = {}}
end

function mutex.with(m, f)
    if m.locked then
        table.insert(m.waiting, f)
    else
        m.locked = true
        f()
        while #m.waiting > 0 do
            table.remove(m.waiting, 1)()
        end
        m.locked = false
    end
end
