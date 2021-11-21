sleep(1)
local settings = require "ae2.autostocksettings"
local logged = { item={}, fluid={} }
local displayProperties = 0
local CPUs = ae2.getCraftingCPUs()

local Status = { OK = 1, CRAFTABLE = 2, UNCRAFTABLE = 3, CRAFTING = 4 }
local StatusColours = {
  [Status.OK] = colours.green,
  [Status.CRAFTABLE] = colours.orange,
  [Status.UNCRAFTABLE] = colours.red,
  [Status.CRAFTING] = colours.lightBlue,
}

local monitor = peripheral.find( "monitor" )
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

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

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

function shorten(s,w)
    local ellipsis = "..."
    local n_ellipsis = utf8.len(ellipsis)
    assert_string(1,s)
    if utf8.len(s) > w then
        return s:sub(1,w-n_ellipsis) .. ellipsis
    end
    return s
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
    local programName = "AutoStock  v1.0.4"
    local programTitle = "<- "..programName.." ->"
    monitor.setTextScale(scale)
    monitor.setTextColour(colours.white)
    monitor.setCursorPos(1, 1)
    monitor.write("/"..string.rep("¯", resX-2).."\\")
    monitor.setCursorPos(1, 2)
    monitor.write("|")
    monitor.setCursorPos((scaledMonitorResolutionX/2)-(string.len(programTitle))/2+1, 2)
    monitor.write(programTitle)
    monitor.setCursorPos(scaledMonitorResolutionX, 2)
    monitor.write("|")
    monitor.setCursorPos(1, 3)
    monitor.write("\\"..string.rep("_", scaledMonitorResolutionX-2).."/")
end

local function drawCPU(posX, posY, cpu, noCPU)
    local CPUWindow = columnTable["columnWindow99"]
    local coprocessors = cpu["coprocessors"].."T"
    local storage = getSlim(cpu["storage"])
    local descriptionPosition = (math.floor((11-(string.len(coprocessors..storage)))/2)+0.1)
    local status = ae2.getCraftingCPUs()[noCPU]["busy"]
    local statusText
    local sizeX,sizeY = CPUWindow.getSize()
    if status then
        CPUWindow.setTextColour(colours.cyan)
        statusText = "busy"
    else
        CPUWindow.setTextColour(colours.green)
        statusText = "idle"
    end
    CPUWindow.setCursorPos(posX,posY)
    CPUWindow.write(string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x94)..string.char(0x94)..string.char(0x94)..string.char(0x94)..string.char(0x94)..string.char(0x80)..string.char(0x80))
    CPUWindow.setCursorPos(posX,posY+1)
    CPUWindow.write(string.char(0x80)..string.char(0x80)..string.char(0x9c)..string.char(0x8d)..string.char(0x8d)..string.char(0x8d)..string.char(0x8d)..string.char(0x8d)..string.char(0x94)..string.char(0x80))
    CPUWindow.setCursorPos(posX,posY+2)
    CPUWindow.write(string.char(0x88)..string.char(0x86)..string.char(0x95).."CPU"..noCPU..string.char(0x80)..string.char(0x97)..string.char(0x8c))
    CPUWindow.setCursorPos(posX,posY+3)
    CPUWindow.write(string.char(0x88)..string.char(0x86)..string.char(0x95)..string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x97)..string.char(0x8c))
    CPUWindow.setCursorPos(posX,posY+4)
    CPUWindow.write(string.char(0x88)..string.char(0x86)..string.char(0x95)..string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x97)..string.char(0x8c))
    CPUWindow.setCursorPos(posX,posY+5)
    CPUWindow.write(string.char(0x88)..string.char(0x86)..string.char(0x95)..string.char(0x80)..statusText..string.char(0x97)..string.char(0x8c))
    CPUWindow.setCursorPos(posX,posY+6)
    CPUWindow.write(string.char(0x80)..string.char(0x80)..string.char(0x83)..string.char(0x97)..string.char(0x97)..string.char(0x97)..string.char(0x97)..string.char(0x97)..string.char(0x81)..string.char(0x80))
    CPUWindow.setCursorPos(posX,posY+7)
    CPUWindow.write(string.char(0x80)..string.char(0x80)..string.char(0x80)..string.char(0x81)..string.char(0x81)..string.char(0x81)..string.char(0x81)..string.char(0x81)..string.char(0x80)..string.char(0x80))
    CPUWindow.setCursorPos(posX+descriptionPosition,posY+8)
    CPUWindow.setTextColour(colours.magenta)
    CPUWindow.write(coprocessors)
    CPUWindow.setCursorPos(posX+descriptionPosition+string.len(coprocessors)+1,posY+8)
    CPUWindow.setTextColour(colours.yellow)
    CPUWindow.write(storage)
end

local function drawCPUs(xSize)
    local cpuSize = 10
    local cpuMargin = (xSize-cpuSize)/(#CPUs-1)
    for i,v in ipairs(CPUs) do
            drawCPU(1+(cpuMargin*(i-1)),1,CPUs[i],i)
    end
    local CPUWindow = columnTable["columnWindow99"]
    CPUWindow.setCursorPos(1,cpuSize)
    CPUWindow.setTextColour(colours.white)
    CPUWindow.write(string.rep("-", scaledMonitorResolutionX))
end

function initializeScreen()
    local max_summary = 10
    local max_name = 20
    local requiredSpace = max_name+1+max_summary
    local cpuColSize = 11

    monitor.setTextScale(resolutionScale)

    monitorResolutionX, monitorResolutionY = getMonitorResolution(monitor)

    monitorSizeX, monitorSizeY = getMonitorSize(monitor, resolutionScale)
    oldMonitorSizeX, oldMonitorSizeY = monitorSizeX, monitorSizeY
    print("New Monitor Size: "..monitorSizeX.."x"..monitorSizeY)

    scaledMonitorResolutionX, scaledMonitorResolutionY = getScaledMonitorResolution(monitor, resolutionScale)
    print("New Year's Resolution: "..scaledMonitorResolutionX.."x"..scaledMonitorResolutionY)

    availableLines = scaledMonitorResolutionY-14
    amountOfColumns = math.floor((scaledMonitorResolutionX / requiredSpace)+0.1)
    columnWidth = ((scaledMonitorResolutionX) / amountOfColumns)
    print("It will comfortably fit "..amountOfColumns.." columns.".."\n")

    writeTitle(scaledMonitorResolutionX, scaledMonitorResolutionY, resolutionScale)

    for key = 1, amountOfColumns,1  do
            columnTable["columnWindow"..tostring(key)] = window.create(monitor, columnWidth*(key-1)+2, monitorResolutionY-availableLines, columnWidth, availableLines)
    end
    columnTable["columnWindow99"] = window.create(monitor, 1, 4, scaledMonitorResolutionX, 10)
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

local function report(info, msg)
    if msg then
        monitor.setBackgroundColour(colours.red)
        monitor.setTextColour(colours.white)
        monitor.setCursorPos((scaledMonitorResolutionX - string.len(msg))/2+1, scaledMonitorResolutionY/2+1)
        monitor.write(msg)
    else
        monitor.setBackgroundColour(colours.black)
        monitor.setTextColour(colours.white)

        for x = 1, amountOfColumns,1 do
            columnTable["columnWindow"..tostring(x)].clear()
        end
        local lineIndex = 1
        local column = 1
        for line,v in ipairs(info) do
            local columnWindow = columnTable["columnWindow"..tostring(column)]

            columnWindow.setTextColour(colours.white)
            columnWindow.setCursorPos(1, lineIndex)
            columnWindow.write(string.format("%02d",line)..". ")
            columnWindow.setCursorPos(5, lineIndex)
            columnWindow.write(shorten(v.name,columnWidth-(utf8.len(v.summary)+6)))
            columnWindow.setTextColour(StatusColours[v.status])
            columnWindow.setCursorPos((columnWidth) - string.len(tostring(v.summary)), lineIndex)
            columnWindow.write(v.summary)
            columnWindow.setTextColour(colours.white)
            lineIndex = lineIndex +1
            if lineIndex > (availableLines) then
                column = column + 1
                lineIndex = 1
            end
            if lineIndex > (availableLines) and column == amountOfColumns then break end
        end
        drawCPUs(scaledMonitorResolutionX)
    end
end

local function wait(seconds)
    local t = os.startTimer(seconds)
    while true do
        local event = {os.pullEventRaw()}
        if event[1] == "timer" and event[2] == t then return true end
        if event[1] == "monitor_resize" then
            print("\nMonitor size changed.")
            initializeScreen()
        end
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
initializeScreen()
while run do
    inv, msg = inventory()
    info = check(inv)
    restock(info)
    report(info, msg)
    run = wait(settings.getRefresh())
end

monitor.setBackgroundColour(colours.black)
monitor.clear()
