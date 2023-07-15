-- Import required APIs
--os.loadAPI("button.lua")

print("Initialising program...")
print("\tLoaded dependencies.")
local inspect = require("inspect")
local waltz = require("waltz")
settings.load()
print("\tLoaded settings.")

theme = {
    titleForegroundColour = 0x200,
    titleBackgroundColour = 0x80,
    textForegroundColour = 0x1,
    textBackgroundColour = 0x8000,
    successForegroundColour = 0x20,
    successBackgroundColour = 0x8000,
    failureForegroundColour = 0x4000,
    failureBackgroundColour = 0x8000,
    buttonForegroundColour = 0x800,
    buttonBackgroundColour = 0x8000,
    textScale = 0.5
}

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
print("\tFound necessary peripherals")

-- Create button instance
--local btnInstance = button.new("top")
local requestButtons = {}

-- Set some settings and preferences
monitor.setTextScale(0.5)
local validTypes = {"chest", "shulker_box", "barrel", "backpack"}

-- Window variables
local sizeX, sizeY
local w = nil
local winButtons = {}

-- Initialise Waltz
print("Redirecting terminal...")
term.redirect(monitor)
if (mode == "CC") then --CC/OC compatibility patch
    monitor = term
    thread = parallel
end
print("Creating window...")
local x, y = 1, 1
if (mode == "CC") then
    sizeX, sizeY = monitor.getSize()
    w = window.create(monitor.current(), x, y, sizeX, sizeY)
else
    sizeX, sizeY = monitor.gpu().getResolution()
    w = Window.create(x, y, sizeX, sizeY)
end

if (w == nil) then
    error("Could not initialise window!")
end

print("Created window: @ " .. x .. "&" .. y .. "/" .. sizeX .. "x" .. sizeY)
sleep(1)
local g = Waltz.create(w, theme, "Autostonk")
print("Initialising status label...")
local lblStatus = nil

--sets the text of the status label
local function setStatus(status)
    local winX, winY = w.getSize()
    local statusText = textutils.formatTime(os.time(), true) .. ": " .. status
    if not lblStatus and lblStatus == nil then
        lblStatus = Label.create(g, statusText, theme['textForegroundColour'], theme['textBackgroundColour'], 1, winY, winX - 1, 1)
        g:addComponent(lblStatus)
    end
    lblStatus:setText(statusText)
end

print("\tIt doesn't work, does it!?")
-- Initialise arrays for holding components
print("Initialising component arrays...")
local lblsDisplayName = {}
local lblsAvailableQuantity = {}
local lblsRequestedQuantity = {}
print("Getting list of items in ME network...")
local meNetworkItemsList, getListFailed = meBridge.listItems()
if not getListFailed then
    print("\t"..#meNetworkItemsList.." items found.")
else
    error("Could not get list of items in ME Network!")
end
print(inspect(meNetworkItemsList))
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
    --monitor.clear()
    --monitor.setCursorPos(1, 1)
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

local function changeItemCount(displayName, calculation, amount)
    local meItems = loadSettings("meItems")

    for _, item in ipairs(meItems) do
        if item[nameConstant] == displayName then
            if calculation == "+" then
                item[countConstant] = item[countConstant] + amount
            elseif calculation == "-" then
                item[countConstant] = item[countConstant] - amount
            elseif calculation == "*" then
                item[countConstant] = item[countConstant] * amount
            elseif calculation == "/" then
                item[countConstant] = item[countConstant] / amount
            end

            print("Item count changed for '" .. displayName .. "' to " .. item[countConstant])
            break
        end
    end

    saveSettings("meItems", meItems)
    --updateMeItems()
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

-- Function to write editable text to window on the monitor
function writeEditableToWindow(win, item, text, line, column, txtback, txtcolor, truncate, fillLine)
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
        x = math.floor(winX * 5 / 8) + 3 -- Start at the position after the second column for the third column
    else
        x = math.floor(winX * 6 / 8) + 1 -- Start at the position after the third column for the fourth column
    end

    -- Calculate the position of the buttons
    local buttonX1 = x - 2
    local buttonX2 = x + columnWidth-4

    local btnMinusId = "btnMinus"..line
    local btnPlusId = "btnPlus"..line
    
    if not winButtons[btnMinusId] then
        winButtons[btnMinusId] = Button.create(g, "-", colours.black, colours.red, buttonX1, line, 1, 1)
        winButtons[btnMinusId]:setAction(function() changeItemCount(item[nameConstant], item[countConstant] - 1) end)
        g:addComponent(winButtons[btnMinusId])
    end
    if not winButtons[btnPlusId] then
        winButtons[btnPlusId] = Button.create(g, "+", colours.black, colours.red, buttonX2, line, 1, 1)
        winButtons[btnPlusId]:setAction(function() changeItemCount(item[nameConstant], item[countConstant] + 1) end)
        g:addComponent(winButtons[btnPlusId])
    end
    winButtons[btnMinusId]:setAction(function() changeItemCount(item[nameConstant], item[countConstant] - 1) end)
    winButtons[btnPlusId]:setAction(function() changeItemCount(item[nameConstant], item[countConstant] + 1) end)


    -- Write the editable text
    win.setBackgroundColor(txtback)
    win.setTextColor(txtcolor)
    win.setCursorPos(x, line)
    win.write(text)

    -- Fill the remaining space in the column with repeatable character if fillLine is true
    --if fillLine and string.len(text) < columnWidth then
      --  local filler = string.rep(".", columnWidth - string.len(text) - 2) -- Generate the filler text
        --win.write(filler)
    --end
    term.redirect(term.native())
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
    
    local winX, winY = w.getSize()
    setStatus("Loading meItems from settings")
    local meItems = loadSettings("meItems")
    setStatus("Updating meItems table with information from the ME network")
    local meItemList = meBridge.listItems()
    setStatus("Updating list of craftable items")
    local craftableItems = meBridge.listCraftableItems()

    -- Helper function to extract the last word from a string
    local function getLastWord(str)
        local lastWord = str:match("%S+$")
        return lastWord or ""
    end
    setStatus("Grouping items")
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
    setStatus("Sorting items within groups alphabetically")
    -- Sort items within each group alphabetically
    for _, group in pairs(groupedItems) do
        table.sort(group, function(a, b)
            return a[nameConstant] < b[nameConstant]
        end)
    end

    setStatus("Flattening the grouped items back into the meItems table")
    -- Flatten the grouped items back into the meItems table
    meItems = {}
    for _, group in pairs(groupedItems) do
        for _, item in ipairs(group) do
            table.insert(meItems, item)
        end
    end
    setStatus("Updating information about requested and craftable items")
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

    setStatus("Generate a label for each item")
    -- Generate a label for each item
    for i, meItem in ipairs(meItems) do
        -- Gather information about the item
        local displayName = meItem[nameConstant]
        local _, itemInMeSystem = pcall(meBridge.getItem, { name = meItem[idConstant] })
        local availableQuantity = itemInMeSystem.amount
        local requestedQuantity = meItem[countConstant]
        -- Generate labels to display the information if they do not exist,
        -- and update the information if they do.
        if not lblsDisplayName[i] then
            lblsDisplayName[i] = Label.create(g, displayName, theme['textForegroundColour'], theme['textBackgroundColour'], 1, i + 1, 25, 1)
            g:addComponent(lblsDisplayName[i])
        else 
            lblsDisplayName[i]:setText(displayName)
        end
        if not lblsAvailableQuantity[i] then
            lblsAvailableQuantity[i] = Label.create(g, availableQuantity, theme['textForegroundColour'], theme['textBackgroundColour'], math.floor(winX * 4 / 8) + 1, i + 1, 25, 1)
            g:addComponent(lblsAvailableQuantity[i])
        else
            lblsAvailableQuantity[i]:setText(availableQuantity)
        end
        if not lblsRequestedQuantity[i] then
            lblsRequestedQuantity[i] = Label.create(g, requestedQuantity, theme['textForegroundColour'], theme['textBackgroundColour'], math.floor(winX * 5 / 8) + 3, i + 1, 25, 1)
            g:addComponent(lblsRequestedQuantity[i])
        else
            lblsRequestedQuantity[i]:setText(requestedQuantity)
        end
    end
    setStatus("Finished updating ME items, saving settings.")
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

        --paintutils.drawLine(1, row+indexPosition, winX, row+indexPosition, lineColor)

        if name and name ~= "" then
            local success, meItem = pcall(meBridge.getItem, { name = name })

            if success then
                local availableAmount = meItem.amount
                --writeToWindow(win, displayText, row+indexPosition, columnName, lineColor, textColor, true, true)

                if prevAvailableAmounts[displayName] ~= availableAmount then
                    --writeToWindow(win, tostring(availableAmount) , row+indexPosition, columnStock, lineColor, textColor, true, true)
                    --writeEditableToWindow(win, item, min, row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    --writeToWindow(win, tostring(min), row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    prevAvailableAmounts[displayName] = availableAmount
                elseif prevAvailableAmounts[displayName] >= availableAmount then
                    --writeToWindow(win, tostring(availableAmount) , row+indexPosition, columnStock, lineColor, textColor, true, true)
                    --writeEditableToWindow(win, item, min, row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    --writeToWindow(win, tostring(min), row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    prevAvailableAmounts[displayName] = availableAmount
                elseif not prevAvailableAmounts[displayName] then
                    --writeToWindow(win, tostring(availableAmount) , row+indexPosition, columnStock, lineColor, textColor, true, true)
                    --writeEditableToWindow(win, item, min, row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    --writeToWindow(win, tostring(min), row+indexPosition, columnRequested, lineColor, textColor, true, true)
                    prevAvailableAmounts[displayName] = availableAmount
                end

                if availableAmount < min then
                    if meBridge.isItemCraftable({ name = name }) then
                        if not meBridge.isItemCrafting({ name = name }) then
                            local craftedItem = { name = name, count = min - availableAmount }
                            meBridge.craftItem(craftedItem)
                            --writeToWindow(win, "Attempting to craft...", row+indexPosition, columnStatus, lineColor, colors.yellow, true, true)
                        elseif meBridge.isItemCrafting({ name = name }) then
                            --writeToWindow(win, "Crafting...", row+indexPosition, columnStatus, lineColor, colors.blue, true, true)
                        end
                    elseif not meBridge.isItemCraftable({ name = name }) then
                        --writeToWindow(win, "Not craftable :(", row+indexPosition, columnStatus, lineColor, colors.orange, true, true)
                    end
                elseif availableAmount >= min then
                    local ratio = availableAmount / min
                    if ratio <= 1.1 then
                        --writeToWindow(win, "Stonked!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    elseif ratio <= 2 then
                        --writeToWindow(win, "Doublestonked!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    elseif ratio <= 3 then
                        --writeToWindow(win, "T-T-T-TRIPLESTONKED!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    elseif availableAmount == 0 and min == 0 then
                        --writeToWindow(win, "No stock but, no need?", row+indexPosition, columnStatus, lineColor, colors.red, true, true)
                    elseif availableAmount > min and min == 0 then
                        --writeToWindow(win, "Stonked but, no need?", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    else
                        --writeToWindow(win, "Why's on the list?!", row+indexPosition, columnStatus, lineColor, colors.green, true, true)
                    end
                end
            else
                --writeToWindow(win, displayText, row+indexPosition, columnName, lineColor, colors.red, true, true)
                --writeToWindow(win, "0", row+indexPosition, columnStock, lineColor, colors.red, true, true)
                --writeToWindow(win, "0", row+indexPosition, columnRequested, lineColor, colors.red, true, true)
                --writeToWindow(win, "N/A", row+indexPosition, columnStatus, lineColor, colors.red, true, true)
            end
        else
            --writeToWindow(win, displayText, row+indexPosition, columnName, lineColor, colors.red, true, true)
            --writeToWindow(win, "0", row+indexPosition, columnStock, lineColor, colors.red, true, true)
            --writeToWindow(win, "0", row+indexPosition, columnRequested, lineColor, colors.red, true, true)
            --writeToWindow(win, "No match", row+indexPosition, columnStatus, lineColor, colors.red, true, true)
        end

        row = row + 1
    
    end

    saveSettings("prevAvailableAmounts", prevAvailableAmounts)
    --btnCount:draw()
    term.redirect(term.native())

end


local function drawUI()
    --clearMonitor()

    -- Draws the buttons
    --btnInstance:draw(monitor)

    -- Draws the frame and the title of the program
    --drawBox(2, winX - 1, 2, winY - 5, "Autostonking v2", colors.lightBlue, colors.blue)

    -- Draws the column headers
    --writeToWindow(winHeaders, "#  Item name", 1, 1, colors.black, colors.lightBlue, false, false)
    --writeToWindow(winHeaders, "Stocked", 1, 2, colors.black, colors.lightBlue, false, false)
    --writeToWindow(winHeaders, "Requested", 1, 3, colors.black, colors.lightBlue, false, false)
    --writeToWindow(winHeaders, "Status", 1, 4, colors.black, colors.lightBlue, false, false)

end

--btnInstance:add(monitor,"listUp","Move list up", function() repositionWindow("up") end, 2, winY - 3, math.floor(winX / 2) - 1, winY - 1, colors.yellow, colors.yellow, colors.black, colors.black)
--btnInstance:add(monitor,"listDown","Move list down", function() repositionWindow("down") end, math.floor(winX / 2) + 2, winY - 3, winX - 1, winY - 1, colors.yellow, colors.yellow, colors.black, colors.black)

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
    setStatus("Starting main loop")
    updateMeItems()
    sleep(2)
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

-- Function to handle button events
local function handleChangeButtonEvents()
    while true do
    -- Handle button events
    local event = {btnCount:handleEvents(os.pullEvent())}
        if event[1] == "button_click" then
            btnCount.buttonList[event[2]].func()
        end
    end
end


local function handleEvenMoreButtons()
    while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
        
    -- Check if the touch event is within the bounds of the buttons
    for _, button in pairs(requestButtons) do
        if button:handleTouch(x, y) then
              button:onClick()
        end
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
--parallel.waitForAll(mainLoop, inputLoop, handleButtonEvents, handleChangeButtonEvents)
--parallel.waitForAll(mainLoop, inputLoop, handleEvenMoreButtons)
g:run(mainLoop)
