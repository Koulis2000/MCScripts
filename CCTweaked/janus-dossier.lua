-- janus-dossier.lua is responsible for updating items with the correct information acquired
-- from the ME Bridge. It will process commands and decide how to proceed with them.

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

-- Define global variables
local programName = "ME Autocraft"
local meBridge = peripheral.find("meBridge")

local isFileLocked = false -- Virtual lock file

-- Utility functions
-- Helper function to check if an item has only one word in its name
local function hasOneWord(name)
	return not name:find("%s")
end

-- Helper function to extract the last word from a string
-- Helper function to extract the last word from a string
local function getLastWord(str)
	local words = {}
	for word in str:gmatch("%S+") do
		table.insert(words, word)
	end
	return words[#words] or ""
end

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
	if not isFileLocked then
		isFileLocked = true
		-- Update the requested items table with information from the ME network
		print("Loading requestedItems...")
		local requestedItems = janus.load("requestedItems.tmp")
		if (requestedItems == nil) then
			print("\trequestedItems" .. " is nil!")
			return
		end
		print("\t" .. #requestedItems .. " items requested.")
		print("Getting list of craftable items in ME network...")
		local craftableItems = getCraftableItems()
		if (craftableItems == nil) then
			print("\tcraftableItems" .. " is nil!")
			return
		end
		print("\t" .. #craftableItems .. " items craftable by ME network.")
		print("Updating list of items in ME network...")
		local meItemList = meBridge.listItems()
		if (meItemList == nil) then
			print("\tmeItemList" .. " is nil!")
			return
		end
		print("\t" .. #meItemList .. " items in ME network.")

		print("Sorting items alphabetically...")
		-- Sort items alphabetically first
		table.sort(requestedItems, function(a, b)
			if a['name'] == b['name'] then
				return a['originalIndex'] < b['originalIndex'] -- Compare original indexes as a secondary criterion
			end
			return a['name'] < b['name']
		end)

		-- Sorting function with optimization
		local addedItems = {} -- Table to keep track of added items
		local sortedList = {} -- Initialize the sorted list

		-- Iterate through each item in requestedItems
		for index, requestedItem in ipairs(requestedItems) do
			local displayName = requestedItem['name']
			local lastWord = getLastWord(displayName)

			print("Processing item: " .. displayName .. ", lastWord: " .. lastWord)

			if hasOneWord(displayName) or not addedItems[displayName] then
				-- If the item has only one word or is not already added, add it to sortedList
				table.insert(sortedList, requestedItem)
				addedItems[displayName] = true -- Mark the full display name as added

				-- Check the rest of the list and find items with multiple words whose last word matches the current item
				for i = index + 1, #requestedItems do
					local nextItem = requestedItems[i]
					local nextDisplayName = nextItem['name']
					local nextLastWord = getLastWord(nextDisplayName)

					if nextLastWord == lastWord and not addedItems[nextDisplayName] then
						table.insert(sortedList, nextItem)
						addedItems[nextDisplayName] = true -- Mark the full display name of the next item as added
					end
				end
			end
		end

		print("Flattening resulting table back into requested items table...")
		-- Update requestedItems with the grouped items
		requestedItems = sortedList


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
	isFileLocked = false
end

-- Function to craft items to match the requested quantity
local function craftCycle()
	if not isFileLocked then
		isFileLocked = true
		local requestedItems = janus.load("requestedItems.tmp")
		local statusStore = janus.load("statusStore.tmp")
		statusStore = {}
		for i, requestedItem in pairs(requestedItems) do
			local name = requestedItem['id']
			local matchingMeItem = meBridge.getItem({name = name}) -- Always get live, accurate information

			if not matchingMeItem then
				releaseFileLock() -- Must release the file lock; otherwise, the craftCycle() hangs indefinitely
				return -- Loop can't continue because requestedItems is essentially corrupted
			elseif matchingMeItem then
				requestedItem['storedQuantity'] = matchingMeItem['amount']
				requestedItem['craftable'] = matchingMeItem['isCraftable']
			end

			local craftable = requestedItem['craftable']
			local requestedQuantity = requestedItem['requestedQuantity']
			local displayName = requestedItem['name']
			local storedQuantity = requestedItem['storedQuantity']

			if requestedItem['paused'] == nil then
				requestedItem['paused'] = false
			end
			local itemPaused = requestedItem['paused']

			-- If the item is paused, we skip processing
			if not itemPaused then
				-- Reset the status message for each item
				requestedItem['status'] = ""
				-- If the item is already crafting, we skip processing
				if not meBridge.isItemCrafting({ name = name }) then
					-- If the stored quantity is lower than the requested Quantity, we move to the next step...
					if storedQuantity < requestedQuantity then
						-- ...which checks if the item is craftable...
						if craftable then
							-- if it is craftable, we order the crafting
							local craftOrder = { name = name, count = requestedQuantity - storedQuantity }
							local maxRetryCount = 5
							local retryCount = 0

							while retryCount <= maxRetryCount do
								meBridge.craftItem(craftOrder)
								os.sleep(0.2)
								if not meBridge.isItemCrafting(craftOrder) then
									-- Crafting failed, reduce the craft order quantity by 25% and retry
									craftOrder.count = math.max(1, math.floor(craftOrder.count * 0.75))
									retryCount = retryCount + 1
								else
									requestedItem['status'] = "Attempting to craft..."
									break
								end
							end

							if retryCount > maxRetryCount then
								requestedItem['status'] = "Waiting for items..."
								print("Waiting for items...")
							end
						elseif not craftable then
							requestedItem['status'] = "Not craftable :("
						end
					elseif storedQuantity >= requestedQuantity then
						local ratio = storedQuantity / requestedQuantity
						if ratio <= 1.1 then
							requestedItem['status'] = "Stonked!"
						elseif ratio <= 2 then
							requestedItem['status'] = "Doublestonked!"
						elseif ratio <= 3 then
							requestedItem['status'] = "T-T-T-TRIPLESTONKED!"
						elseif storedQuantity == 0 and requestedQuantity == 0 then
							requestedItem['status'] = "No stonk but, no need?"
						elseif storedQuantity > requestedQuantity and requestedQuantity == 0 then
							requestedItem['status'] = "Stonked but, no need?"
						else
							requestedItem['status'] = "Why's on the list?!"
						end
					end
				else
					requestedItem['status'] = "Crafting..."
				end
			else
				requestedItem['status'] = "Paused"
			end
			-- Save the status message, displayName, and id to the statusStore table
			table.insert(statusStore, { displayName = displayName, id = name, status = requestedItem['status'] })
		end
		janus.save("statusStore.tmp", statusStore)
	end
	isFileLocked = false
end


-- Function to check if a command is already processed
local function isCommandProcessed(commandId, responseQueue)
	for _, responseData in ipairs(responseQueue) do
		if responseData.id == commandId then
			return true
		end
	end
	return false
end

-- Function to process user commands
local function processCommand(input, override)
	getFileLock()
	local command, args = input:match("(%S+)%s*(.*)")

	if commands[command] then
		local commandArgs = {}
		for arg in args:gmatch("%S+") do
			table.insert(commandArgs, arg)
		end

		commands[command].handler(unpack(commandArgs))
		
		releaseFileLock()
		return "command finished processing"
	else
		
		releaseFileLock()
		return "Invalid command"
	end
	releaseFileLock()
end

-- Function to read and process commands from the command queue
local function processLensCommands()
	getFileLock()
	local commandQueue = janus.load("commandQueue.tmp", {})
	local responseQueue = janus.load("commandResponses.tmp", {})
	for _, commandData in ipairs(commandQueue) do
		local commandId = commandData.id
		if not isCommandProcessed(commandId, responseQueue) then
			local response = processCommand(commandData.cmd, true)
			print(commandId .. " " .. response)
			table.insert(responseQueue, { id = commandId, response = response })
		else
			print(commandId .. " command already processed")
		end
	end

	janus.save("commandResponses.tmp", responseQueue)
	releaseFileLock()
end


-- Main program loop
local function mainLoop()

	while true do
		updateRequestedItems()

		janus.nap(30)
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