-- set up peripherals
colony = peripheral.find("colonyIntegrator")
monitor = peripheral.find("monitor")
me = peripheral.find("meBridge")
-- load settings
settings.load()


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

-- Previous size of activeWorkOrders
local prevNumOrders = 0

-- Returns the nearest value of a table array?
function nearestValue(table, number)
    local _, index = math.min(table, function(_, value)
        return math.abs(number - value)
    end)
    return index
end


-- Returns the Monitor resolution
local function getMonitorResolution(mon)
    local x,y = mon.getSize()
    return x,y
end

-- Returns the Monitor size in Minecraft Blocks measuring system
local function getMonitorSize(mon, scale)
    local x,y = getMonitorResolution(mon)
    return nearestValue(resolutionTable[tostring(scale)][1], x), nearestValue(resolutionTable[tostring(scale)][2], y)
end

-- Returns the Monitor scaled resolution
local function getScaledMonitorResolution(mon, scale)
    local x,y = getMonitorSize(mon, scale)
    return resolutionTable[tostring(scale)][1][x],resolutionTable[tostring(scale)][2][y]
end


-- "centers" text either at head height, to the left or to the right, but not to the centre.
-- :text [string] - the text to be centered.
-- :line [int] - the line to centre to text on
-- :txtBack [?] - the background colour to centre the text on
-- :txtColor [?] - the colour of the text to be centered
-- :pos [string] - centering strategy
function centerText(mon, text, line, txtback, txtcolor, pos)
    local monX, monY = getMonitorResolution(mon)
    local length = #text
    local dif = math.floor(monX - length)
    local x

    if pos == "head" then
        x = math.floor(dif / 2) + 1
    elseif pos == "left" then
        x = 2
    elseif pos == "right" then
        x = monX - length
    end

    mon.setBackgroundColor(txtback)
    mon.setTextColor(txtcolor)
    mon.setTextScale(0.5)
    mon.setCursorPos(x, line)
    mon.write(text)
end


-- Function to create a new window on the monitor
local function createWindow(mon, x, y, width, height)
    local win = window.create(mon, x, y, width, height)
    win.reposition(x, y, width, height)
    win.clear()
    return win
end

-- Function to write to window on the monitor
function writeToWindow(win, text, line, txtback, txtcolor, column, truncate)
    winX, winY = win.getSize()
    win.setBackgroundColor(txtback)
    win.setTextColor(txtcolor)
    
    -- Determine the column width based on the column number
    if column == 1 then
        columnWidth = math.floor(winX / 2) -- Column width is half of the screen for the first column
    else
        columnWidth = math.floor(winX / 4) -- Column width is a quarter of the screen for the second and third columns
    end
    
    -- Truncate the text if its length exceeds the column width and if truncate is true
    if truncate and string.len(text) > columnWidth-1 then
        text = string.sub(text, 1, columnWidth - 4) .. "..." -- Truncate the text and add three dots
    end
    
    -- Determine the starting position based on the column number
    if column == 1 then
        x = 1 -- Start at the leftmost position for the first column
    elseif column == 2 then
        x = math.floor(winX / 2) + 1 -- Start at the middle position for the second column
    else
        x = math.floor((winX / 4) * 3) + 1 -- Start at the rightmost position for the third column
    end
    
    win.setCursorPos(x, line)
    win.write(text)
end



-- Function to create or recreate windows based on the size of activeWorkOrders
local function createOrUpdateWindows()
  local monitorWidth, monitorHeight = getMonitorResolution(monitor)
  local numOrders = getNumberOfOrders()
  local winWidth = math.floor(monitorWidth / numOrders)

  if numOrders ~= prevNumOrders then
    -- Number of active work orders has changed, recreate windows
    windows = {}
    for i = 1, numOrders do
      local x = (i - 1) * winWidth + 1
      local win = createWindow(monitor, x, 3, winWidth, monitorHeight)
      table.insert(windows, win)
    end
    prevNumOrders = numOrders
  else
    -- Number of active work orders remains the same, update window size
    for i, win in ipairs(windows) do
      local x = (i - 1) * winWidth + 1
      win.reposition(x, 3, winWidth, monitorHeight)
      win.clear()
    end
  end
end


-- clears the monitor and prints a header
function prepareMonitor() 
    monitor.clear()
    monitor.setTextScale(0.5)
    centerText(monitor,"Active Work Order Requirements", 1, colors.black, colors.white, "head")
end

-- Returns all the active work orders
function getActiveWorkOrders()
    local activeWorkOrders = {}
    local allWorkOrders = colony.getWorkOrders()

    for _, order in pairs(allWorkOrders) do
        if order.isClaimed and order.workOrderType == "BUILD" then
            table.insert(activeWorkOrders, order)
        end
    end

    return activeWorkOrders
end


-- Returns the number of active work orders
function getNumberOfOrders()
    local activeOrders = getActiveWorkOrders()
    print(tostring(#activeOrders))
    return #activeOrders
end

-- saves a list of processed work orders, so we know which ones we don't need to do again..?
-- what if the same (ie identical) work order comes in again after having been completed?
-- say if you build two Nordic Spruce Level 2 Residences?
-- would that count as a different work order?
-- :processedWorkOrders [table] - a table containing all previously processed work orders
function saveProcessedWorkOrders(workOrders)
    settings.set("processedWorkOrders", workOrders)
    settings.save()
end

-- loads aforementioned list (table) of processed work orders into settings with the key "processedWorkOrders",
-- or returns an empty table if the file ".settings" does not exist in the cwd
function loadProcessedWorkOrders()
    if fs.exists(".settings") then
        settings.load()
        return settings.get("processedWorkOrders")
    else
        return {}
    end
end

prepareMonitor()

-- Function to process each builder resource
-- Locates, or crafts if it fails to locate, the required item and exports it
-- :item [item] - the item to process
local function processBuilderResource(item)
    local itemName = item.item
    local itemDetails = item.details or {}  -- Initialize itemDetails if it is nil
    local itemNeeded = item.needed or 0
    local itemAvailable = item.available or 0
    local itemDelivering = item.delivering or 0
    local itemCrafted = item.crafted or 0
    local itemExported = item.exported or 0
    local itemDisplayName = item.displayName

    -- Check if the item exists in meItems
    local foundInMEItems = false
    for _, meItem in pairs(me.listItems()) do
        if meItem.name == itemName then
            foundInMEItems = true
            break
        end
    end

    -- Check if the item exists in meCraftableItems
    local foundInMECraftableItems = false
    local meCraftableItems = me.listCraftableItems()
    if meCraftableItems then
        for _, meCraftableItem in pairs(meCraftableItems) do
            if meCraftableItem.name == itemName then
                foundInMECraftableItems = true
                break
            end
        end
    end

    -- Calculate the amount to craft and export
    local amountToCraft = itemNeeded - (itemAvailable + itemCrafted)
    local amountToExport = itemNeeded - (itemAvailable + itemExported)

    if foundInMEItems then
        -- Export the required amount
        local exportedAmount, exportErr = me.exportItem({name = itemName, count = amountToExport}, "down")
        if exportErr then
            itemDetails.exported = 0
            print("  Error exporting item: " .. exportErr)
        else
            itemDetails.exported = (itemDetails.exported or 0) + exportedAmount
            print("  Exported " .. exportedAmount .. " " .. itemDisplayName)
        end

    elseif foundInMECraftableItems then
        -- Craft the required amount
        local crafted = me.craftItem({name = itemName, count = amountToCraft})
        if not crafted then
            itemDetails.crafted = 0
            print("  Error crafting item: " .. craftErr)
        else
            itemDetails.crafted = (itemDetails.crafted or 0) + amountToCraft
            print("  Crafted " .. amountToCraft .. " " .. itemDisplayName)
        end
    else
        itemDetails.exported = 0
        itemDetails.crafted = 0
        -- Item not found in ME system, take appropriate action
        print("  Item " .. itemDisplayName .. " not found in ME system")
    end

    -- Update the item details in builderResources
    item.details = itemDetails
end


-- Function to print builder resources on a specific window
function printBuilderResources(win, resources, row)
    for key, resource in pairs(resources) do
        local displayName = resource.displayName
        local available = resource.available or resource.details.available or 0
        local needed = resource.needed or resource.details.needed or 0
        local exported = resource.details.exported or 0
        local crafted = resource.details.crafted or 0

        writeToWindow(win, displayName, row, colors.black, colors.white, 1, true)
        writeToWindow(win, available.."/"..needed, row, colors.black, colors.white, 2, true)
        writeToWindow(win, exported.."|"..crafted, row, colors.black, colors.white, 3, true)

        row = row + 1
    end
end


function writeTableToFile(tableData, filename)
    local file = fs.open(filename, "w")  -- Open file in write mode
    if file then
        file.write(textutils.serialize(tableData))  -- Serialize table and write to file
        file.close()  -- Close the file
        print("Table successfully written to file: " .. filename)
    else
        print("Failed to open file: " .. filename)
    end
end


function updateProcessedWorkOrders()
    local activeWorkOrders = getActiveWorkOrders()
    local processedWorkOrders = loadProcessedWorkOrders()

    -- Add orders from activeWorkOrders that are not in processedWorkOrders
    for _, order in ipairs(activeWorkOrders) do
        local found = false
        for _, processedOrder in ipairs(processedWorkOrders) do
            if order.id == processedOrder.id then
                found = true
                break
            end
        end
        if not found then
            table.insert(processedWorkOrders, order)
        end
    end

    -- Remove orders from processedWorkOrders that are not in activeWorkOrders
    for i = #processedWorkOrders, 1, -1 do
        local order = processedWorkOrders[i]
        local found = false
        for _, activeOrder in ipairs(activeWorkOrders) do
            if order.id == activeOrder.id then
                found = true
                break
            end
        end
        if not found then
            table.remove(processedWorkOrders, i)
        end
    end

    -- Save the updated processedWorkOrders if needed
    saveProcessedWorkOrders(processedWorkOrders)
end

function compareAndRunUpdate()
  local activeSize = #getActiveWorkOrders()
  local processedSize = #loadProcessedWorkOrders()

  if activeSize ~= processedSize then
    updateProcessedWorkOrders()
  end
end



-- loads the active work order and exports the required items one by one
function builderResources()
    local processedWorkOrders = loadProcessedWorkOrders()
    local activeWorkOrders = getActiveWorkOrders()
    for i, win in pairs(windows) do
            local order = activeWorkOrders[i] -- Get the current work order

            -- Print active work order details on the screen
        writeToWindow(win, "Work Order ID: " .. tostring(order.id), 3, colors.black, colors.white, 1, false)
        writeToWindow(win, "Building Name: " .. tostring(order.buildingName), 4, colors.black, colors.white, 1, false)
        writeToWindow(win, "Target Level: " .. tostring(order.targetLevel), 5, colors.black, colors.white, 1, false)
        local row = 7

       local workResources = {} -- Create an empty table for work resources

        for _, item in pairs(order.workResources) do
            processBuilderResource(item)
            table.insert(workResources, item) -- Insert the processed item into workResources table
        end

        printBuilderResources(win, workResources, row)

        -- Update the workResources table in the activeWorkOrders list
        order.workResources = workResources
        activeWorkOrders[i] = order
    end

    -- Save the updated processed work orders
    saveProcessedWorkOrders(processedWorkOrders)
end

-- Run the builderResources function in a loop
while true do
    createOrUpdateWindows()
    compareAndRunUpdate()
    builderResources()
    sleep(5)
end