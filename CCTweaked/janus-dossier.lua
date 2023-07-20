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

-- Assign intercommunication files
local commandQueue = "commandQueue.txt"
local commandRespond = "response.txt"

-- Define global variables
local programName = "ME Autocraft"
local meBridge = peripheral.find("meBridge")
local validTypes = {"chest", "shulker_box", "barrel", "backpack"}

local isFileLocked = false -- Virtual lock file

-- Function to get file lock
local function getFileLock()
	while isFileLocked do
		os.sleep(0.1) -- Wait until the file is unlocked
	end
	isFileLocked = true
end

-- Function to release file lock
local function releaseFileLock()
	isFileLocked = false
end

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


-- Helper function to find an item index by Display Name
local function finditemIndex(requestedItems, displayName)
	for i, requestedItem in pairs(requestedItems) do
		if item['name'] == displayName then
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
		requestedItems[itemIndex]['paused'] = true
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
		requestedItems[itemIndex]['paused'] = false
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

-- Function that definitely needs optimization
local function updateRequestedItems()
	getFileLock()
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
	releaseFileLock()
end

-- Function to craft items to match the requested amounts
local function craftCycle()
	getFileLock()
	local requestedItems = janus.load("requestedItems.tmp")
	for i, requestedItem in pairs(requestedItems) do
		local name = requestedItem['id']
		local matchingMeItem = meBridge.getItem({name = name}) -- Always get live, accurate, information
		if not matchingMeItem then -- Gotta check if it's nil!
			-- Handle the problem properly so the loop may continue
			-- Possible solutions: 
				-- Remove the offending item and suggest the user add it through the chest instead
				-- Attempt another method of getting the required information about the item
				-- Ask the user to manually enter the required information
			print("No match found for item " .. name .. "! Cannot continue craft cycle!")
			releaseFileLock() -- Must release the file lock, otherwise the craftCycle() hangs indefinitely
			return -- Loop can't continue because requestedItems is essentially corrupted
		end
		requestedItem['storedQuantity'] = matchingMeItem['amount']
		requestedItem['craftable'] = matchingMeItem['isCraftable']
		local fingerprint = requestedItem['fingerprint']
		local craftable = requestedItem['craftable']
		local requestedQuantity = requestedItem['requestedQuantity']
		local displayName = requestedItem['name']
		local count = requestedItem['storedQuantity']
		if requestedItem['paused'] == nil then
			requestedItem['paused'] = false
		end
		local itemPaused = requestedItem['paused']

		-- If the item is paused, we skip processing
		if not itemPaused then
			-- Reset the status message for each item
			 requestedItem['status'] = ""
			-- If the item is already crafting, we skip processing
			if not meBridge.isItemCrafting({ name = name}) then
				-- If the stored quantity is lower than the requested Quantity, we move to the next step...
				if count < requestedQuantity then
					-- ...which checks if the item is craftable...
						if craftable then
							-- if it is craftable, we order the crafting
							local craftOrder = { name = name, count = requestedQuantity - count }
							meBridge.craftItem(craftOrder)
								requestedItem['status'] = "Attempting to craft..."
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
					requestedItem['status'] = "Crafting..."
			 end
	elseif itemPaused and meBridge.isItemCrafting({ name = name}) then -- Case where the item is paused but some other source started a crafting job
			requestedItem['status'] = "Manual crafting..."
	else
			requestedItem['status'] = "Paused"
		end
	end
	janus.save("requestedItems.tmp", requestedItems)
	releaseFileLock()
end

-- Function to check if a command is alreay processed
local function isCommandProcessed(commandId, responseFile)
	local file = io.open(responseFile, "r")
	if file then
		for line in file:lines() do
			local responseData = textutils.unserializeJSON(line)
			if responseData.id == commandId then
				file:close()
				return true
			end
		end
		file:close()
	end
	return false
end

-- Function to process user commands
local function processCommand(input, override)
	if not isFileLocked or override then -- Override is used when the processCommand is called from processLensCommands
		isFileLocked = true
		local command, args = input:match("(%S+)%s*(.*)")

		if commands[command] then
			local commandArgs = {}
			for arg in args:gmatch("%S+") do
				table.insert(commandArgs, arg)
			end

			commands[command].handler(unpack(commandArgs))
			print(unpack(commandArgs))

			-- Return a simple response string
			isFileLocked = false
			return "command finished processing"
		else
			isFileLocked = false
			return "Invalid command"
		end
	end
end

-- Function to read and process commands from the command queue
local function processLensCommands()
    if not isFileLocked then
        isFileLocked = true
        local file = io.open(commandQueue, "r")
        if file then
            local responseQueue = {}
            for line in file:lines() do
                local commandData = textutils.unserializeJSON(line)
                local commandId = commandData.id
                if not isCommandProcessed(commandId, commandRespond) then
                    local response = processCommand(commandData.cmd, true)
                    print(commandId .. " " .. response)
                    table.insert(responseQueue, { id = commandId, response = response })
                else
                    print(commandId .. " command already processed")
                end
            end
            file:close()

            file = io.open(commandRespond, "a") -- Use "a" mode to append to the response file
            if file then
                for _, responseData in ipairs(responseQueue) do
                    local serializedResponse = textutils.serializeJSON(responseData)
                    file:write(serializedResponse .. "\n")
                end
                file:close()
            end
        end
        isFileLocked = false
    end
end


-- Main program loop
local function mainLoop()
	while true do
		updateRequestedItems()
		janus.nap(60)
	end
end

-- Craft loop
local function craftLoop()
	while true do
		craftCycle()
		sleep(2) -- Make UI more responsive, can change if it affect performance, I use sleep as to not spam the console every second
	end
end

-- Function to process commands coming from janus-lens
local function lensCommandLoop()
	while true do
		processLensCommands()
		sleep(0.1)
	end
end

-- Function to process user commands
local function userCommandLoop()
	while true do
		local input = read()
		processCommand(input, false)
		sleep(0.1)
	end
end

parallel.waitForAll(mainLoop, craftLoop, lensCommandLoop, userCommandLoop)