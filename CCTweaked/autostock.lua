local settings = require "ae2.autostocksettings"
local logged = { item={}, fluid={} }
local displayProperties = 0

local Status = { OK = 1, CRAFTABLE = 2, UNCRAFTABLE = 3, CRAFTING = 4 }
local StatusColours = {
  [Status.OK] = colours.green,
  [Status.CRAFTABLE] = colours.orange,
  [Status.UNCRAFTABLE] = colours.red,
  [Status.CRAFTING] = colours.lightBlue,
}

local monitor = peripheral.wrap( "left" )
local monitorResolutionXX, monitorResolutionXY
local resolutionScale = 0.5
local resolutionTable = {
        ["0.5"] = {{15,36,57,79,100,121,143,164},{10,24,38,52,67,81}},
        ["1"]   = {{7,18,29,39,50,61,71,82},{5,12,19,26,33,40}},
        ["1.5"] = {{5,12,19,26,33,40,48,55},{3,8,13,17,22,27}},
        ["2"]   = {{4,9,14,20,25,30,36,41},{2,6,10,13,17,20}},
        ["2.5"] = {{3,7,11,16,20,24,29,33},{2,5,8,10,13,16}},
        ["3"]   = {{2,6,10,13,17,20,24,27},{2,4,6,9,11,13}},
        ["3.5"] = {{2,5,8,11,14,17,20,23},{1,3,5,7,10,12}},
        ["4"]   = {{2,5,7,10,13,15,18,21},{1,3,5,7,8,10}},
        ["4.5"] = {{2,4,6,9,11,13,16,18},{1,3,4,6,7,9}},
        ["5"]   = {{1,4,6,8,10,12,14,16},{1,2,4,5,7,8}},
    }
local monitorSizeX, monitorResolutionXX, scaledMonitorResolutionX
local monitorSizeY, monitorResolutionXY, scaledMonitorResolutionY
local oldMonitorSizeX, oldMonitorSizeY = 0,0
local availableLines
local columnTable = {}
local amountOfColumns
local currentColumn

function assert_arg (n,val,tp,verify,msg,lev)
    if type(val) ~= tp then
        error(("argument %d expected a '%s', got a '%s'"):format(n,tp,type(val)),lev or 2)
    end
    if verify and not verify(val) then
        error(("argument %d: '%s' %s"):format(n,val,msg),lev or 2)
    end
    return val
end

local function assert_string (n,s)
    assert_arg(n,s,'string')
end

function nearestValue(table, number)
    local smallestSoFar, smallestIndex
    for i, y in ipairs(table) do
        if not smallestSoFar or (math.abs(number-y) < smallestSoFar) then
            smallestSoFar = math.abs(number-y)
            smallestIndex = i
        end
    end
    return smallestIndex
end

local function getMonitorResolution(mon)
    local x,y = mon.getSize()
    return x,y
end

local function getMonitorSize(mon, scale)
    local x,y = mon.getSize()
    return nearestValue(resolutionTable[tostring(scale)][1], x), nearestValue(resolutionTable[tostring(scale)][2], y)
end

local function getScaledMonitorResolution(mon, scale)
    local x,y = getMonitorSize(mon, scale)
    return resolutionTable[tostring(scale)][1][x],resolutionTable[tostring(scale)][2][y]
end

local function writeTitle(resX, resY, scale)
    local programName = "AutoStock  v1.0.2"
    local programTitle = "<- "..programName.." ->"
    monitor.setTextScale(scale)
    monitor.setCursorPos(1, 1)
    monitor.write("/"..string.rep("-", resX-2).."\\")
    monitor.setCursorPos(1, 2)
    monitor.write("|")
    monitor.setCursorPos((scaledMonitorResolutionX/2)-(string.len(programTitle))/2+1, 2)
    monitor.write(programTitle)
    monitor.setCursorPos(scaledMonitorResolutionX, 2)
    monitor.write("|")
    monitor.setCursorPos(1, 3)
    monitor.write("\\"..string.rep("-", scaledMonitorResolutionX-2).."/")
end

function initializeScreen()
    local max_summary = 10
    local max_name = 20
    local requiredSpace = max_name+1+max_summary

    monitor.setTextScale(resolutionScale)

    monitorResolutionX, monitorResolutionY = getMonitorResolution(monitor)

    monitorSizeX, monitorSizeY = getMonitorSize(monitor, resolutionScale)
    oldMonitorSizeX, oldMonitorSizeY = monitorSizeX, monitorSizeY
    print("New Monitor Size: "..monitorSizeX.."x"..monitorSizeY)

    scaledMonitorResolutionX, scaledMonitorResolutionY = getScaledMonitorResolution(monitor, resolutionScale)
    print("New Year's Resolution: "..scaledMonitorResolutionX.."x"..scaledMonitorResolutionY)

    availableLines = scaledMonitorResolutionY-3
    amountOfColumns = math.floor((scaledMonitorResolutionX / requiredSpace)+0.1)
    columnWidth = (scaledMonitorResolutionX / amountOfColumns)-2
    print("It will comfortably fit "..amountOfColumns.." columns.".."\n")

    writeTitle(scaledMonitorResolutionX, scaledMonitorResolutionY, resolutionScale)

    for key = 1, amountOfColumns, 1  do
            columnTable["columnWindow"..tostring(key)] = window.create(monitor, columnWidth*(key-1)+2, 4, columnWidth, availableLines)
            --columnTable["columnWindow"..tostring(key)].write("This is window "..key)
    end
end

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


function shorten(s,w)
    local ellipsis = "..."
    local n_ellipsis = utf8.len(ellipsis)
    assert_string(1,s)
    if utf8.len(s) > w then
        return s:sub(1,w-n_ellipsis) .. ellipsis
    end
    return s
end

local function report(info, msg)
    if msg then
        monitor.setBackgroundColour(colours.red)
        monitor.setTextColour(colours.white)
        --monitor.clear()
        monitor.setCursorPos((scaledMonitorResolutionX - string.len(msg))/2+1, scaledMonitorResolutionY/2+1)
        monitor.write(msg)
    else
        monitor.setBackgroundColour(colours.black)
        monitor.setTextColour(colours.white)
        --monitor.clear()

        for x = 1, amountOfColumns,1 do
            columnTable["columnWindow"..tostring(x)].clear()
        end
        for line,v in ipairs(info) do
            local column = math.floor((line/availableLines)+1)
            local columnWindow = columnTable["columnWindow"..tostring(column)]

            if line > (availableLines)*(column+1) and column == amountOfColumns then break end

            columnWindow.setTextColour(colours.white)
            columnWindow.setCursorPos(1, line-(availableLines*(column-1)))
            columnWindow.write(shorten(v.name,columnWidth-(utf8.len(v.summary)+1)))
            columnWindow.setTextColour(StatusColours[v.status])
            columnWindow.setCursorPos((columnWidth+1) - string.len(tostring(v.summary)), line-(availableLines*(column-1)))
            columnWindow.write(v.summary)
            columnWindow.setTextColour(colours.white)
        end
    end
end

function getSlim(n)
    if n >= 10^9 then
        return string.format("%.1fb", n / 10^9)
    elseif n >= 10^6 then
        return string.format("%.1fm", n / 10^6)
    elseif n >= 10^3 then
        return string.format("%.0fk", n / 10^3)
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
    monitorSizeX, monitorSizeY = getMonitorSize(monitor, resolutionScale)
    if oldMonitorSizeX ~= monitorSizeX or oldMonitorSizeY ~= monitorSizeY then
        print("\nMonitor size changed.")
        initializeScreen()
    end
    inv, msg = inventory()
    info = check(inv)
    restock(info)
    report(info, msg)
    run = wait(settings.getRefresh())
end

monitor.setBackgroundColour(colours.black)
monitor.clear()
