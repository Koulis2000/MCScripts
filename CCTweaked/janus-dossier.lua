-- Import libraries
inspect = require('inspect') -- Defined as a global (not local). This allows commands.lua to use it.
-- Read commands definition file
require('janus/commands') 	-- Note that this is not commands = require('janus/commands')
									-- The reason is that janus/commands.lua defines the global
									-- variable commands when it is required. Since it is global,
									-- it is available from this file as well.

if not commands then -- Checking that janus/commands.lua managed to define itself
	-- If not, the program still runs, but commands won't work
	print("Commands not defined!")
end

-- Define constants
local idConstant = 1
local fingerprintConstant = 2
local countConstant = 3
local nameConstant = 4
local craftableConstant = 5

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

-- Save function
function save(file, data)
	local fileName = "janus/" .. file
	local serialisedData = textutils.serialise(data)
	local file = fs.open(fileName, "w")
	file.write(serialisedData)
	file.close()
end
-- Load function
function load(file)
	local fileName = "janus/" .. file
	if not fs.exists(fileName) then
		error("File " .. fileName .. " does not exist!")
	end
	local file = fs.open(fileName, "r")
	local serialisedData = file.readAll()
	file.close()
	local data = textutils.unserialize(serialisedData)
	return data
end

-- Function that definitelly needs optimization
local function updateMeItems()
	-- Update the meItems table with information from the ME network
	print("Loading requestedItems...")
	local requestedItems = load("requestedItems.tmp")
	print("Updating list of items in ME network...")
	local meItemList = meBridge.listItems()
	print("Updating list of craftable items in ME network...")
	local craftableItems = meBridge.listCraftableItems()

	-- Helper function to extract the last word from a string
	local function getLastWord(str)
		local lastWord = str:match("%S+$")
		return lastWord or ""
	end
	print("Grouping items...")
	-- Create a table to store the grouped items
	local groupedItems = {}

	-- Group items by their last word
	for _, meItem in pairs(requestedItems) do
		local displayName = meItem[nameConstant]
		local lastWord = getLastWord(displayName)

		if not groupedItems[lastWord] then
			groupedItems[lastWord] = {}
		end

		table.insert(groupedItems[lastWord], meItem)
	end
	print("Sorting items alphabetically within their respective groups...")
	-- Sort items within each group alphabetically
	for _, group in pairs(groupedItems) do
		table.sort(group, function(a, b)
			return a[nameConstant] < b[nameConstant]
			end)
	end
	print("Flattening resulting table back into meItems table...")
	-- Flatten the grouped items back into the meItems table
	requestedItems = {}
	for _, group in pairs(groupedItems) do
		for _, item in pairs(group) do
			table.insert(requestedItems, item)
		end
	end
	print("Updating information about requested and craftable items...")
	-- Update the item information
	for _, meItem in pairs(requestedItems) do
		local displayName = meItem[nameConstant]
	-- Check if the item is available in the ME Items list and get the details
		for _, listItem in pairs(meItemList) do
			if string.lower(listItem.displayName) == string.lower(displayName) then
				meItem[idConstant] = listItem.name
				meItem[fingerprintConstant] = listItem.fingerprint
				meItem[craftableConstant] = listItem.isCraftable
				break
			end
		end
		-- Check if the item is available in the ME Craftable Items list and get the details
		for _, craftableItem in pairs(craftableItems) do
			if string.lower(craftableItem.displayName) == string.lower(displayName) then
				meItem[idConstant] = craftableItem.name
				meItem[fingerprintConstant] = craftableItem.fingerprint
				meItem[craftableConstant] = craftableItem.isCraftable
				break
			end
		end
	end
	print("Saving requested items...")
	save("requestedItems.tmp", requestedItems)
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
		updateMeItems()
		print("Resting for 60 seconds")
		for i = 60, 0, -1 do
			sleep(1)
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

parallel.waitForAll(mainLoop, inputLoop)