-- Import required APIs
os.loadAPI("button.lua")

settings.load()

-- Define constants
local idConstant = 1
local fingerprintConstant = 2
local countConstant = 3
local nameConstant = 4
local craftableConstant = 5

-- Define global variables
local programName = "ME Autocraft"
local meBridge = peripheral.find("meBridge")
local monitor = peripheral.find("monitor")

-- Create button instance
local btnInstance = button.new("top")

-- Set some settings and preferences
monitor.setTextScale(0.5)
local validTypes = {"chest", "shulker_box", "barrel", "backpack"}

-- Window variables
local winX, winY = monitor.getSize()
local winHeaders = window.create(monitor, 4, 4, winX - 8, winY - 10)
local win = window.create(monitor, 4, 5, winX - 8, winY - 10)
local indexPosition = 0

-- Function to check if an inventory exists (or, truthfully, if part of its id matches the above strings)
local function isInventory()
    for _, side in ipairs(peripheral.getNames()) do
        local peripheralType = peripheral.getType(side)
        for _, validType in ipairs(validTypes) do
            if peripheralType and string.find(string.lower(peripheralType), string.lower(validType)) then
                return true
            end
        end
    end
    return false
end

-- Function to get the inventory object
local function getInventory()
    for _, side in ipairs(peripheral.getNames()) do
        local peripheralType = peripheral.getType(side)
        for _, validType in ipairs(validTypes) do
            if peripheralType and string.find(string.lower(peripheralType), string.lower(validType)) then
                return peripheral.wrap(side)
            end
        end
    end
    return nil
end


-- Utility functions

-- Function to clear the monitor
local function clearMonitor()
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

-- Function to draw a frame with title
local function drawBox(xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    monitor.setBackgroundColor(bcolor)
    for xPos = xMin, xMax do
        monitor.setCursorPos(xPos, yMin)
        monitor.write(" ")
        monitor.setCursorPos(xPos, yMax)
        monitor.write(" ")
    end
    for yPos = yMin, yMax do
        monitor.setCursorPos(xMin, yPos)
        monitor.write(" ")
        monitor.setCursorPos(xMax, yPos)
        monitor.write(" ")
    end
    monitor.setCursorPos(xMin+2, yMin)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(tcolor)
    monitor.write(" " .. title .. " ")
    monitor.setTextColor(colors.white)
end

-- Function to create new window
local function createWindow(x, y, width, height)
    local win = window.create(monitor, x, y, width, height)
        win.clear()
    return win
end

-- Function to write to window on the monitor
function writeToWindow(win, text, line, column, txtback, txtcolor, truncate, fillLine)
    local winX, winY = win.getSize()
    win.setBackgroundColor(txtback)
    win.setTextColor(txtcolor)
    local line = line

    -- Determine the column width based on the column number
    local columnWidth
    if column == 1 then
        columnWidth = math.floor(winX * 4 / 8) -- Column width is 4/8th of the screen for the first column
    elseif column == 2 or column == 3 then
        columnWidth = math.floor(winX / 8) -- Column width is 1/8th of the screen for the second and third columns
    else
        columnWidth = math.floor(winX * 2 / 8) -- Column width is 2/8th of the screen for the fourth column
    end

    -- Truncate the text if its length exceeds the column width and if truncate is true
    if truncate and string.len(text) > columnWidth then
        text = string.sub(text, 1, columnWidth) -- Truncate the text to fit the column width
    end
    
    -- Determine the starting position based on the column number
    local x
    if column == 1 then
        x = 1 -- Start at the leftmost position for the first column
    elseif column == 2 then
        x = math.floor(winX * 4 / 8) + 1 -- Start at the position after the first column for the second column
    elseif column == 3 then
        x = math.floor(winX * 5 / 8) + 1 -- Start at the position after the second column for the third column
    else
        x = math.floor(winX * 6 / 8) + 1 -- Start at the position after the third column for the fourth column
    end

    win.setCursorPos(x, line)
    win.write(text)
    win.setTextColor(colors.white)

    local filler
    -- Fill the remaining space in the column with repeatable character if fillLine is true
    if fillLine and string.len(text) < columnWidth then
        filler = " " .. string.rep(".", columnWidth - string.len(text)-2) -- Generate the filler text
        win.write(filler)
    end
end

-- Function to fakescroll the window
local function repositionWindow(direction)
    local winX, winY = win.getSize()
    local monX, monY = monitor.getSize()
    local moveAmount = math.floor(monY / 3)
    local winPosX, winPosY = win.getPosition()

    if direction == "up" then
        indexPosition = indexPosition - moveAmount
        print("Window moved "..moveAmount.." up")
    elseif direction == "down" then
        indexPosition = indexPosition + moveAmount
        print("Window moved "..moveAmount.." down")
    end
    win.redraw()
end

-- Functions that interact with the settings API
-- Load function
function loadSettings(setting)
    settings.load()
    return settings.get(setting, {})
end
-- Save function
function saveSettings(setting, list)
    settings.set(setting, list)
    settings.save()
end

-- Function that definitelly needs optimization
local function updateMeItems()
    -- Update the meItems table with information from the ME network
    local meItems = loadSettings("meItems")
    local meItemList = meBridge.listItems()
    local craftableItems = meBridge.listCraftableItems()

    -- Helper function to extract the last word from a string
    local function getLastWord(str)
        local lastWord = str:match("%S+$")
        return lastWord or ""
    end

    -- Create a table to store the grouped items
    local groupedItems = {}

    -- Group items by their last word
    for _, meItem in ipairs(meItems) do
        local displayName = meItem[nameConstant]
        local lastWord = getLastWord(displayName)

        if not groupedItems[lastWord] then
            groupedItems[lastWord] = {}
        end

        table.insert(groupedItems[lastWord], meItem)
    end

    -- Sort items within each group alphabetically
    for _, group in pairs(groupedItems) do
        table.sort(group, function(a, b)
            return a[nameConstant] < b[nameConstant]
        end)
    end

    -- Flatten the grouped items back into the meItems table
    meItems = {}
    for _, group in pairs(groupedItems) do
        for _, item in ipairs(group) do
            table.insert(meItems, item)
        end
    end

    -- Update the item information
    for _, meItem in ipairs(meItems) do
        local displayName = meItem[nameConstant]
        -- Check if the item is available in the ME Items list and get the details
        for _, listItem in ipairs(meItemList) do
            if string.lower(listItem.displayName) == string.lower(displayName) then
                meItem[idConstant] = listItem.name
                meItem[fingerprintConstant] = listItem.fingerprint
                meItem[craftableConstant] = listItem.isCraftable
                break
            end
        end
        -- Check if the item is available in the ME Craftable Items list and get the details
        for _, craftableItem in ipairs(craftableItems) do
            if string.lower(craftableItem.displayName) == string.lower(displayName) then
                meItem[idConstant] = craftableItem.name
                meItem[fingerprintConstant] = craftableItem.fingerprint
                meItem[craftableConstant] = craftableItem.isCraftable
                break
            end
        end
    end

    saveSettings("meItems", meItems)
end

-- Function to remove an item from the meItems list in the settings based on Display Name
local function removeItem(displayName)
    local meItems = loadSettings("meItems")
    local itemIndex = nil

    for i, item in ipairs(meItems) do
        if item[nameConstant] == displayName then
            itemIndex = i
            break
        end
    end

    if itemIndex then
        table.remove(meItems, itemIndex)
        print("Item '" .. displayName .. "' removed successfully")
    else
        print("Item '" .. displayName .. "' not found in the meItems list")
    end

    saveSettings("meItems", meItems)
end

-- Function to display the meItems list to the windooooooww, to the wall
local function displayItems()
    term.redirect(win)
    -- win.clear()

    local meItems = loadSettings("meItems")

    -- Create a table to store the previous available amounts
    local prevAvailableAmounts = {}
    prevAvailableAmounts = loadSettings("prevAvailableAmounts")

    local row = 1
    for i, item in ipairs(meItems) do
        local name = item[idConstant]
        local fingerprint = item[fingerprintConstant]
        local min = item[countConstant]
        local displayName = item[nameConstant]

        local displayText = string.format("%d. %s", i, displayName)

        local columnName = 1
        local columnStock = 2
        local columnRequested = 3
        local columnStatus = 4

        local lineColor
        if row % 2 == 0 then
            lineColor = colors.black
            textColor = colors.white
        else
            lineColor = colors.black
            textColor = colors.lightGray
        end

        paintutils.drawLine(1, row+indexPosition, winX, row+indexPosition, lineColor)

        if name and name ~= "" then
            local success, meItem = pcall(meBridge.getItem, { name = name })

            if success then
                local availableAmount = meItem.amount
                writeToWindow(win, displayText, row+indexPosition, columnName, lineColor, textColor, true, true)

                if prevAvailableAmounts[displayName] ~= availableAmount then
                    writeToWindow(win, tostring(availableAmount) , row+indexPosition, columnStock, lineColor, textColor, true, true)
                    writeToWindow(win, tostring(min), row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    prevAvailableAmounts[displayName] = availableAmount
                elseif prevAvailableAmounts[displayName] >= availableAmount then
                    writeToWindow(win, tostring(availableAmount) , row+indexPosition, columnStock, lineColor, textColor, true, true)
                    writeToWindow(win, tostring(min), row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    prevAvailableAmounts[displayName] = availableAmount
                elseif not prevAvailableAmounts[displayName] then
                    writeToWindow(win, tostring(availableAmount) , row+indexPosition, columnStock, lineColor, textColor, true, true)
                    writeToWindow(win, tostring(min), row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    prevAvailableAmounts[displayName] = availableAmount
                end

                if availableAmount < min then
                    if meBridge.isItemCraftable({ name = name }) then
                        if not meBridge.isItemCrafting({ name = name }) then
                            local craftedItem = { name = name, count = min - availableAmount }
                            meBridge.craftItem(craftedItem)
                            writeToWindow(win, "Attempting to craft...", row+indexPosition, columnStatus, lineColor, colors.yellow, true, true)
                        elseif meBridge.isItemCrafting({ name = name }) then
                            writeToWindow(win, "Crafting...", row+indexPosition, columnStatus, lineColor, colors.blue, true, true)
                        end
                    elseif not meBridge.isItemCraftable({ name = name }) then
                        writeToWindow(win, "Not craftable :(", row+indexPosition, columnStatus, lineColor, colors.orange, true, true)
                    end
                elseif availableAmount >= min then
                    local ratio = availableAmount / min
                    if ratio <= 1.1 then
                        writeToWindow(win, "Stonked!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    elseif ratio <= 2 then
                        writeToWindow(win, "Doublestonked!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    elseif ratio <= 3 then
                        writeToWindow(win, "T-T-T-TRIPLESTONKED!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    elseif availableAmount == 0 and min == 0 then
                        writeToWindow(win, "No stock but, no need?", row+indexPosition, columnStatus, lineColor, colors.red, true, true)
                    elseif availableAmount > min and min == 0 then
                        writeToWindow(win, "Stonked but, no need?", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    else
                        writeToWindow(win, "Why's on the list?!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    end
                end
            else
                writeToWindow(win, displayText, row+indexPosition, columnName, lineColor, colors.red, true, true)
                writeToWindow(win, "0/" .. min, row+indexPosition, columnStock, lineColor, colors.red, true, true)
                writeToWindow(win, "Not available", row+indexPosition, columnRequested, lineColor, colors.red, true, true)
            end
        else
            writeToWindow(win, displayText, row+indexPosition, columnName, lineColor, colors.red, true, true)
            writeToWindow(win, "0/" .. min, row+indexPosition, columnStock, lineColor, colors.red, true, true)
            writeToWindow(win, "No match", row+indexPosition, columnRequested, lineColor, colors.red, true, true)
        end

        row = row + 1
    
    end

    saveSettings("prevAvailableAmounts", prevAvailableAmounts)
    term.redirect(term.native())

end


local function drawUI()
    -- clearMonitor()

    -- Draws the buttons
    btnInstance:draw()  

    -- Draws the frame and the title of the program
    drawBox(2, winX - 1, 2, winY - 5, "Autostonking v2", colors.lightBlue, colors.blue)

    -- Draws the column headers
    writeToWindow(winHeaders, "#  Item name", 1, 1, colors.black, colors.lightBlue, false, false)
    writeToWindow(winHeaders, "Stocked", 1, 2, colors.black, colors.lightBlue, false, false)
    writeToWindow(winHeaders, "Requested", 1, 3, colors.black, colors.lightBlue, false, false)
    writeToWindow(winHeaders, "Status", 1, 4, colors.black, colors.lightBlue, false, false)

end

btnInstance:add("Move list up", function() repositionWindow("up") end, 2, winY - 3, math.floor(winX / 2) - 1, winY - 1, colors.yellow, colors.yellow, colors.black, colors.black)
btnInstance:add("Move list down", function() repositionWindow("down") end, math.floor(winX / 2) + 2, winY - 3, winX - 1, winY - 1, colors.yellow, colors.yellow, colors.black, colors.black)

local commands = {
    update = {
        description = "Update the meItems list with items from the adjacent inventory",
        handler = function()
            updateMeItems()
            print("Inventory updated successfully")
        end
    },
    add = {
        description = "Add items to the meItems list",
        handler = function(...)
            local args = {...}
            local meItems = loadSettings("meItems")

            if args[1] == "inventory" then
                if isInventory() then
                    local inventory = getInventory()
                    local inventorySize = inventory.size()
                    print("Inventory size is ".. inventorySize)
                    for slot = 1, inventorySize do
                        local item = inventory.getItemDetail(slot)

                        if item then
                            local existingItem = false

                            for _, meItem in ipairs(meItems) do
                                if string.lower(meItem[nameConstant]) == string.lower(item.displayName) then
                                    existingItem = true
                                    break
                                end
                            end

                            if not existingItem then
                                local isCraftable = meBridge.isItemCraftable(item)
                                table.insert(meItems, {item.name, "", item.count, item.displayName, isCraftable})
                            end
                        end
                    end

                    saveSettings("meItems", meItems)
                    updateMeItems()
                    print("Inventory items added successfully")
                end
            else
                local displayName
                local stockAmount

                -- Check if the last argument is a number
                if tonumber(args[#args]) then
                    displayName = table.concat(args, " ", 1, #args - 1)
                    stockAmount = tonumber(args[#args])
                else
                    displayName = table.concat(args, " ")
                    stockAmount = 0
                end

                local existingItem = false

                for _, meItem in ipairs(meItems) do
                    if string.lower(meItem[4]) == string.lower(displayName) then
                        existingItem = true
                        break
                    end
                end

                if not existingItem then
                    table.insert(meItems, {"", "", stockAmount, displayName, false})
                    print("Item '" .. displayName .. "' added with stock amount: " .. stockAmount)
                else
                    print("Item '" .. displayName .. "' already exists in the meItems list")
                end
            end

            saveSettings("meItems", meItems)
            updateMeItems()
            print("List updated!")
        end
    },

    modify = {
        description = "Modify the 'min' value for item(s) in the meItems list",
        handler = function(...)
            local args = {...}
            local meItems = loadSettings("meItems")

            -- Check if the arguments contain index numbers and the new 'min' value
            local indexNumbers = {}
            local newMinValue = tonumber(table.remove(args))
            if not newMinValue then
                print("Invalid 'min' value provided")
                return
            end

            for _, arg in ipairs(args) do
                local index = tonumber(arg)
                if index then
                    table.insert(indexNumbers, index)
                end
            end

            -- Check if index numbers are present
            if #indexNumbers > 0 then
            -- Modify the 'min' value for items in the meItems list using the index numbers
            for _, index in ipairs(indexNumbers) do
                if index >= 1 and index <= #meItems then
                    meItems[index][countConstant] = newMinValue
                    print("Modified 'min' value for item at index " .. index)
                else
                    print("Invalid index number: " .. index)
                end
            end

            saveSettings("meItems", meItems)
            updateMeItems()
            else
                print("Please provide the index number(s) of the item(s) to modify")
            end
        end
    },

    remove = {
        description = "Remove item(s) from the meItems list",
        handler = function(...)
            local args = {...}
            local meItems = loadSettings("meItems")

            -- Check if the arguments contain index numbers
            local indexNumbers = {}
            for _, arg in ipairs(args) do
                local index = tonumber(arg)
                if index then
                    table.insert(indexNumbers, index)
                end
            end

            -- Check if index numbers are present
            if #indexNumbers > 0 then
            -- Sort the index numbers in descending order to ensure correct removal
            table.sort(indexNumbers, function(a, b) return a > b end)

            -- Remove items from the meItems list using the index numbers
            for _, index in ipairs(indexNumbers) do
                if index >= 1 and index <= #meItems then
                    local removedItem = table.remove(meItems, index)
                    print("Item '" .. removedItem[nameConstant] .. "' removed successfully")
                else
                    print("Invalid index number: " .. index)
                end
            end

            else
            -- No index numbers provided, treat the arguments as the display name
            local displayName = table.concat(args, " ")
                if displayName == "" then
                    print("Please provide the display name or index number(s) of the item(s) to remove")
                else
                    removeItem(displayName)
                end
            end
            saveSettings("meItems", meItems)
            updateMeItems()
        end
    },
}

-- Function to process user commands
local function processCommand(input)
    local command, args = input:match("(%S+)%s*(.*)")

    if commands[command] then
        local commandArgs = {}
        for arg in args:gmatch("%S+") do
            table.insert(commandArgs, arg)
        end

        commands[command].handler(table.unpack(commandArgs))
    else
        print("Invalid command")
    end
end

-- Main program loop
local function mainLoop()
    while true do
        drawUI()
        displayItems()
        sleep(2)
    end
end

-- Function to handle button events
local function handleButtonEvents()
    while true do
    -- Handle button events
    local event = {btnInstance:handleEvents(os.pullEvent())}
        if event[1] == "button_click" then
            btnInstance.buttonList[event[2]].func()
        end
    end
end

-- Function to read user inputs
local function inputLoop()
    while true do
        local input = read()
        processCommand(input)
    end
end

-- Run the main program and other required functions in a loop
parallel.waitForAll(mainLoop, inputLoop, handleButtonEvents)
