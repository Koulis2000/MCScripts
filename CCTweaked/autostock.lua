local settings = require "ae2.autostocksettings"
local monitor = peripheral.find("monitor")
local logged = { item={}, fluid={} }

local Status = { OK = 1, CRAFTABLE = 2, UNCRAFTABLE = 3, CRAFTING = 4 }
local StatusColours = {
  [Status.OK] = colours.green,
  [Status.CRAFTABLE] = colours.orange,
  [Status.UNCRAFTABLE] = colours.red,
  [Status.CRAFTING] = colours.lightBlue,
}

local function inventory()
    local inv,err = ae2.getInventory()
    if not inv then return nil, "Storage offline" end

    local map = { item = {}, fluid = {} }
    for _,v in ipairs(inv) do
        local handlers, stack = settings.getHandlers(v)
        if handlers then
            local k = stack.name .. ':' .. (stack.nbt or "")
            map[handlers.type][k] = v
        end
    end
    return map
end

local function find(inv, handlers, stack)
    local k = stack.name .. ':' .. (stack.nbt or "")
    local v = inv[handlers.type][k]
    if v then
        v[handlers.type].craftable = v.craftable
        v[handlers.type].crafting = v.crafting
        return v[handlers.type]
    end
    return handlers.find(stack)
end

local function check(inv)
    if not inv then return {} end
    local info = {}
    for _,v in ipairs(settings.getStock()) do
        local handlers, stack = settings.getHandlers(v)
        if handlers then
            local stored = find(inv, handlers, stack)
            local state = {
                handlers = handlers,
                stack = stack,
                target = handlers.getQuantity(stack),
                quantity = handlers.getQuantity(stored),
                crafting = stored.crafting or 0,
                name = stored.displayName or stack.name,
            }

            if state.quantity >= state.target then
                state.status = Status.OK
            elseif state.crafting > 0 then
                state.status = Status.CRAFTING
            elseif stored.craftable then
                state.status = Status.CRAFTABLE
            else
                state.status = Status.UNCRAFTABLE
            end
            state.summary = string.format("%s/%s", handlers.formatQuantity(getSlim(state.quantity)), handlers.formatQuantity(getSlim(state.target)))
            table.insert(info, state)
        end
    end
    return info
end

local function restock(info)
    for _,v in ipairs(info) do
        local k = v.stack.name
        -- for AE2 we don't start extra crafting tasks if there's one in progress due to limited CPUs
        if v.status == Status.CRAFTABLE then
            local remaining = v.target - v.quantity
            if remaining > 0 then
                local t,err = v.handlers.craft(v.stack, remaining)
                if t then
                    v.status = Status.CRAFTING
                    if logged[v.handlers.type][k] ~= true then
                        local handlers, stack = settings.getHandlers(t.stack)
                        print(string.format("%s at %s, started crafting %s", v.name, v.summary,
                                handlers.formatQuantity(handlers.getQuantity(stack))))
                        logged[v.handlers.type][k] = true
                    end
                elseif err and logged[v.handlers.type][k] ~= err then
                    print(string.format("%s at %s, %s", v.name, v.summary, err))
                    logged[v.handlers.type][k] = err
                end
            end
        else
            logged[v.handlers.type][k] = nil
        end
    end
end

local function report(info, msg)
    local width,height = monitor.getSize()
    monitor.setTextScale(0.5)
    if msg then
        monitor.setBackgroundColour(colours.red)
        monitor.setTextColour(colours.white)
        monitor.clear()
        monitor.setCursorPos((width - string.len(msg))/2+1, height/2+1)
        monitor.write(msg)
    else
        monitor.setBackgroundColour(colours.black)
        monitor.setTextColour(colours.white)
        monitor.clear()
        monitor.setCursorPos(0, 1)
        monitor.write(" /-------------------------------------------------------\\ ")
        monitor.setCursorPos(0, 2)
        monitor.write(" |                <- AutoStock  v1.0.2 ->                | ")
        monitor.setCursorPos(0, 3)
        monitor.write(" \\-------------------------------------------------------/ ")

        local maxsummary = 0
        for _,v in ipairs(info) do
            maxsummary = math.max(maxsummary, string.len(v.summary))
        end

        local column = 30-2
        local vt = 0
        for line,v in ipairs(info) do
            vt=vt+1
            if info[vt] ~= nil then
                monitor.setCursorPos(2, line+3)
                monitor.write(info[vt].name)
                monitor.setTextColour(StatusColours[info[vt].status])
                monitor.setCursorPos(column - string.len(info[vt].summary), line+3)
                monitor.write(info[vt].summary)
                monitor.setTextColour(colours.white)

                vt=vt+1
                if info[vt] ~= nil then
                    monitor.setCursorPos(column + 2, line+3)
                    monitor.write(info[vt].name)
                    monitor.setTextColour(StatusColours[info[vt].status])
                    monitor.setCursorPos(2 + column * 2 - string.len(info[vt].summary)-1, line+3)
                    monitor.write(info[vt].summary)
                    monitor.setTextColour(colours.white)
                end
            end
            if line > height then break end
        end
    end
end

function getSlim(n)
    if n >= 10^9 then
        return string.format("%.1fb", n / 10^9)
    elseif n >= 10^6 then
        return string.format("%.1fm", n / 10^6)
    elseif n >= 10^3 then
        return string.format("%.1fk", n / 10^3)
    else
        return tostring(n)
    end
end

local function wait(seconds)
    local t = os.startTimer(seconds)
    while true do
        local event = {os.pullEventRaw()}
        if event[1] == "timer" and event[2] == t then return true end
        if event[1] == "terminate" then return false end
        if event[1] == "key" and event[2] == keys.enter then return false end
    end
end

if not ae2 then
    printError("Error: unable to find ME peripheral.")
    return
end
if not monitor then
    printError("Error: unable to find monitor.")
    return
end

if not monitor.isColour() then
    printError("Warning: attached monitor is not colour, please replace.")
end

print("AutoStock running, press ENTER to halt")

local run = true
while run do
    inv, msg = inventory()
    info = check(inv)
    restock(info)
    report(info, msg)
    run = wait(settings.getRefresh())
end

monitor.setBackgroundColour(colours.black)
monitor.clear()
