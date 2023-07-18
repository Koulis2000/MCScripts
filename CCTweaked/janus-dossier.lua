-- Import libraries
inspect = require('inspect') -- Defined as a global (not local). This allows commands.lua to use it.
-- Read commands definition file
require('janus/commands') 	-- Note that this is not commands = require('janus/commands')
									-- The reason is that janus/commands.lua defines the global
									-- variable commands when it is required. Since it is global,
									-- it is available from this file as well.
local janus = require('libjanus')
if not commands then -- Checking that janus/commands.lua managed to define itself
	-- If not, the program still runs, but commands won't work
	print("Commands not defined!")
end

-- Define constants
local idConstant = 1
local fingerprintConstant = 2
local requestedQuantityConstant = 3
local nameConstant = 4
local craftableConstant = 5
local pausedConstant = 6
local statusConstant = 7
local countConstant = 8

-- Define global variables
local programName = "ME Autocraft"
local meBridge = peripheral.find("meBridge")
local validTypes = {"chest", "shulker_box", "barrel", "backpack"}

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

local craftableItems = nil -- When the program runs, craftableItems is initialised to nil
local function getCraftableItems() -- This function delaggifies listCraftableItems() by running it only once per program start
	if craftableItems == nil then -- If it is still nil, run the laggy function to make it not nil
		print("\tUpdating list...")
		craftableItems = meBridge.listCraftableItems()
	end
	return craftableItems -- Return the result
end

-- Function that definitely needs optimization
local function updateRequestedItems()
	-- Update the requested items table with information from the ME network
	print("Loading requestedItems...")
	local requestedItems = janus.load("requestedItems.tmp")
	print("\t" .. #requestedItems .. " items requested.")
	print("Getting list of craftable items in ME network...")
	local craftableItems = getCraftableItems()
	print("\t" .. #craftableItems .. " items craftable by ME network.")
	print("Updating list of items in ME network...")
	local meItemList = meBridge.listItems()
	print("\t" .. #meItemList .. " items in ME network.")

	-- Helper function to extract the last word from a string
	local function getLastWord(str)
		local lastWord = str:match("%S+$")
		return lastWord or ""
	end
	print("Grouping items...")
	-- Create a table to store the grouped items
	local groupedItems = {}

	-- Group items by their last word
	for _, requestedItem in pairs(requestedItems) do
		local displayName = requestedItem['name']
		local lastWord = getLastWord(displayName)

		if not groupedItems[lastWord] then
			groupedItems[lastWord] = {}
		end

		table.insert(groupedItems[lastWord], requestedItem)
	end
	print("Sorting items alphabetically within their respective groups...")
	-- Sort items within each group alphabetically
	for _, group in pairs(groupedItems) do
		table.sort(group, function(a, b)
			return a['name'] < b['name']
			end)
	end
	print("Flattening resulting table back into requested items table...")
	-- Flatten the grouped items back into the requested items table
	requestedItems = {}
	for _, group in pairs(groupedItems) do
		for _, item in pairs(group) do
			table.insert(requestedItems, item)
		end
	end
	print("Updating information about requested and craftable items...")
	-- Update the item information
	for _, requestedItem in pairs(requestedItems) do
		local displayName = requestedItem['name']
		-- Check if the item is available in the ME Craftable Items list and get the details
		for _, craftableItem in pairs(craftableItems) do
			requestedItem['status'] = "Not available"
			if string.lower(craftableItem.displayName) == string.lower(displayName) then
				requestedItem['id'] = craftableItem.name
				requestedItem['fingerprint'] = craftableItem.fingerprint
				requestedItem['craftable'] = craftableItem.isCraftable
				requestedItem['storedQuantity'] = craftableItem.amount or 0
				requestedItem['status'] = "Available"
				break
			end
		end
		-- Check if the item is available in the ME items list and get the details
		for _, listItem in pairs(meItemList) do
			requestedItem['status'] = "No match"
			if string.lower(listItem.displayName) == string.lower(displayName) then
				requestedItem['id'] = listItem.name
				requestedItem['fingerprint'] = listItem.fingerprint
				requestedItem['craftable'] = listItem.isCraftable
				requestedItem['storedQuantity'] = listItem.amount or 0
				requestedItem['status'] = "Match"	
				break
			end
		end
	end

	print("Saving " .. #requestedItems .. " requested items...")
	janus.save("requestedItems.tmp", requestedItems)
end

-- Helper function to find an item index by Display Name
local function finditemIndex(requestedItems, displayName)
    for i, requestedItem in pairs(requestedItems) do
        if item[nameConstant] == displayName then
            return i
        end
    end
    return nil
end

-- Function to pause an item in the requested items list in the settings based on Display Name
local function pauseItem(displayName)
    local requestedItems = janus.load("requestedItems.tmp")
    local itemIndex = finditemIndex(requestedItems, displayName)

    if itemIndex then
        requestedItems[itemIndex][pausedConstant] = true
        print("Item '" .. displayName .. "' paused successfully")
    else
        print("Item '" .. displayName .. "' not found in the requested items list")
    end

    janus.save("requestedItems.tmp", requestedItems)
end

-- Function to unpause an item in the requested items list in the settings based on Display Name
local function unpauseItem(displayName)
    local requestedItems = janus.load("requestedItems.tmp")
    local itemIndex = finditemIndex(requestedItems, displayName)

    if itemIndex then
        requestedItems[itemIndex][pausedConstant] = false
        print("Item '" .. displayName .. "' unpaused successfully")
    else
        print("Item '" .. displayName .. "' not found in the requested items list")
    end

    janus.save("requestedItems.tmp", requestedItems)
end

-- Function to remove an item from the requested items list in the settings based on Display Name
local function removeItem(displayName)
    local requestedItems = janus.load("requestedItems.tmp")
    local itemIndex = finditemIndex(requestedItems, displayName)

    if itemIndex then
        table.remove(requestedItems, itemIndex)
        print("Item '" .. displayName .. "' removed successfully")
    else
        print("Item '" .. displayName .. "' not found in the requested items list")
    end

    janus.save("requestedItems.tmp", requestedItems)
end

-- Function to craft items to match the requested amounts
local function craftCycle()
    local requestedItems = janus.load("requestedItems.tmp")
    for i, requestedItem in pairs(requestedItems) do
        local name = requestedItem['id']
        local fingerprint = requestedItem['fingerprint']
        local craftable = requestedItem['craftable']
        local requestedQuantity = requestedItem['requestedQuantity']
        local displayName = requestedItem['name']
        local count = requestedItem['storedQuantity']
        local paused = requestedItem['paused'] or false

        local displayText = string.format("%d. %s", i, displayName)

        if not paused then
            -- Reset the status message for each item
            requestedItem['status'] = ""

            if count < requestedQuantity then
                if craftable then
                    if not craftable then
                        local craftedItem = { name = name, count = requestedQuantity - count }
                        meBridge.craftItem(craftedItem)
                        requestedItem['status'] = "Attempting to craft..."
                    elseif meBridge.isItemCrafting({ name = name }) then
                        requestedItem['status'] = "Crafting..."
                    end
                elseif not craftable then
                    requestedItem['status'] = "Not craftable :("
                end
            elseif count >= requestedQuantity then
                local ratio = count / requestedQuantity
                if ratio <= 1.1 then
                    requestedItem['status'] = "Stonked!"
                elseif ratio <= 2 then
                    requestedItem['status'] = "Doublestonked!"
                elseif ratio <= 3 then
                    requestedItem['status'] = "T-T-T-TRIPLESTONKED!"
                elseif count == 0 and requestedQuantity == 0 then
                    requestedItem['status'] = "No stock but, no need?"
                elseif count > requestedQuantity and requestedQuantity == 0 then
                    requestedItem['status'] = "Stonked but, no need?"
                else
                    requestedItem['status'] = "Why's on the list?!"
                end
            end
	    else
	    	requestedItem['status'] = "Paused"
	    end
    end
    janus.save("requestedItems.tmp", requestedItems)
end

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
		updateRequestedItems()
		craftCycle()
		janus.nap(60)
	end
end

-- Function to read user inputs
local function inputLoop()
	while true do
		local input = read()
		processCommand(input)
	end
end

parallel.waitForAll(mainLoop, inputLoop)