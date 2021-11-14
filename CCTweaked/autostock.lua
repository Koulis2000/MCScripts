local settings = require "ae2.autostocksettings"
local logged = { item={}, fluid={} }
local displayProperties = 0
local oldSizeX, oldSizeY = 0,0

local Status = { OK = 1, CRAFTABLE = 2, UNCRAFTABLE = 3, CRAFTING = 4 }
local StatusColours = {
  [Status.OK] = colours.green,
  [Status.CRAFTABLE] = colours.orange,
  [Status.UNCRAFTABLE] = colours.red,
  [Status.CRAFTING] = colours.lightBlue,
}

local monitor = peripheral.find("monitor")
local width,height
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
local screenSizeX, screenResX
local screenSizeY, screenResY
local scaledResX, scaledResY
local columns
local columnWidth
local availableLines

function NearestValue(table, number)
    local smallestSoFar, smallestIndex
    for i, y in ipairs(table) do
        if not smallestSoFar or (math.abs(number-y) < smallestSoFar) then
            smallestSoFar = math.abs(number-y)
            smallestIndex = i
        end
    end
    return smallestIndex, table[smallestIndex]
end

local function getMonSize(x,y,scale)
   return resolutionTable[scale][1][x],resolutionTable[scale][2][y]
end

function initializeScreen()
    monitor.setTextScale(1)
    width,height = monitor.getSize()
    monitor.setTextScale(resolutionScale)
    screenSizeX, screenResX = NearestValue(resolutionTable["1"][1],width)
    screenSizeY, screenResY = NearestValue(resolutionTable["1"][2],height)
    scaledResX, scaledResY = getMonSize(screenSizeX,screenSizeY,tostring(resolutionScale))
    availableLines = scaledResY-3

    if screenSizeX <= 2 then
        columns = 1
    elseif screenSizeX == 3 then
        columns = 2
    elseif screenSizeX == 4 then
        columns = 3
    elseif screenSizeX == 5 then
        columns = 3
    elseif screenSizeX == 6 then
        columns = 4
    elseif screenSizeX == 7 then
        columns = 4
    elseif screenSizeX == 8 then
        columns = 5
    end

    columnWidth = scaledResX / columns

    if oldSizeX ~= screenSizeX or oldSizeY ~= screenSizeY then
        displayUpdate = 1
    end
    if displayUpdate == 1 then
        oldSizeX = screenSizeX
        oldSizeY = screenSizeY
        print("\nNew Monitor Size: "..screenSizeX.."x"..screenSizeY)
        --print("New Standard Resolution: "..width.."x"..height)
        print("New Year's Resolution: "..scaledResX.."x"..scaledResY)
        displayUpdate = 0
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


local function writeTitle(resX, resY, scale)
    local programName = "AutoStock  v1.0.2"
    local programTitle = "<- "..programName.." ->"
    monitor.setTextScale(scale)
    monitor.setCursorPos(1, 1)
    monitor.write("/"..string.rep("-", resX-2).."\\")
    monitor.setCursorPos(1, 2)
    monitor.write("|")
    monitor.setCursorPos((scaledResX/2)-(string.len(programTitle))/2+1, 2)
    monitor.write(programTitle)
    monitor.setCursorPos(scaledResX, 2)
    monitor.write("|")
    monitor.setCursorPos(1, 3)
    monitor.write("\\"..string.rep("-", scaledResX-2).."/")
end

local function report(info, msg)
    initializeScreen()
    local columnIndex = 0
    if msg then
        monitor.setBackgroundColour(colours.red)
        monitor.setTextColour(colours.white)
        monitor.clear()
        writeTitle(scaledResX,scaledResY,resolutionScale)
        monitor.setCursorPos((scaledResX - string.len(msg))/2+1, scaledResY/2+1)
        monitor.write(msg)
    else
        monitor.setBackgroundColour(colours.black)
        monitor.setTextColour(colours.white)
        monitor.clear()

        writeTitle(scaledResX,scaledResY,resolutionScale)

        for line,v in ipairs(info) do
            if line > (availableLines)*(columnIndex+1) and columnIndex < columns then
                columnIndex = columnIndex + 1
            elseif line > (availableLines)*(columnIndex+1) and columnIndex == columns then break end
            monitor.setCursorPos(2 + (columnWidth*columnIndex), line + 3 - ((availableLines)*columnIndex))
            monitor.write(v.name)
            monitor.setTextColour(StatusColours[v.status])
            monitor.setCursorPos((columnWidth*(columnIndex + 1))- 2 - string.len(tostring(x)), line + 3 -((availableLines)*columnIndex))
            monitor.write(v.summary)
            monitor.setTextColour(colours.white)
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
