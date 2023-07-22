-- The commands.lua file is mostly responsible for requestedItems list manipulation.
-- Anything to do with modifying/adding/removing/pausing items should reside here.
-- This file does not interact with the ME Bridge whatsoever.

local janus = require('../libjanus')
local response = "Command executed"

local validTypes = {"chest", "shulker_box", "barrel", "backpack"}

-- Utility functions
-- Helper function to find an item index by Display Name
local function finditemIndex(requestedItems, displayName)
	for i, requestedItem in ipairs(requestedItems) do
		if requestedItem['name'] == displayName then
			return i
		end
	end
	return nil
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

-- List manipulation functions
-- Function to modify an item in the requested items list, based on Display Name
local function modifyItem(requestedItems, displayName, newRequestedQuantity)
	local itemIndex = finditemIndex(requestedItems, displayName)

	if itemIndex then
		requestedItems[itemIndex]['requestedQuantity'] = newRequestedQuantity
		print("Modified requested quantity for item '" .. displayName .. "'")
	else
		print("Item '" .. displayName .. "' not found in the requested items list")
	end
end

-- Function to perform an action (pause, unpause, or remove) on an item in the requested items list, based on Display Name
local function performAction(requestedItems, action, displayName)
	local itemIndex = finditemIndex(requestedItems, displayName)

	if itemIndex then
		if action == "pause" then
			requestedItems[itemIndex]['paused'] = true
			print("Item '" .. displayName .. "' paused successfully")
		elseif action == "unpause" then
			requestedItems[itemIndex]['paused'] = false
			print("Item '" .. displayName .. "' unpaused successfully")
		elseif action == "remove" then
			table.remove(requestedItems, itemIndex)
			print("Item '" .. displayName .. "' removed successfully")
		end
	else
		print("Item '" .. displayName .. "' not found in the requested items list")
	end
end

-- Function to add items from the inventory to the requested items list
local function addInventoryItems(requestedItems)
	if not isInventory() then
		return
	end

	local inventory = getInventory()
	local inventorySize = inventory.size()

	for slot = 1, inventorySize do
		local item = inventory.getItemDetail(slot)

		if item then
			local existingItem = false

			for _, requestedItem in ipairs(requestedItems) do
				if string.lower(requestedItem['name']) == string.lower(item.displayName) then
					existingItem = true
					break
				end
			end

			if not existingItem then
				table.insert(requestedItems, {
					id = "",
					requestedQuantity = requestedQuantity,
					storedQuantity = 0,
					name = displayName,
					craftable = false,
					paused = true,
					status = "Pending update...",
					fingerprint = ""
				})
			end
		end
	end
end

commands = {

	add = {
		description = "Add items to the requestedItems list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")

			if args[1] == "inventory" then
				addInventoryItems(requestedItems)
			else
				local displayName = table.concat(args, " ", 1, #args - 1)
				local requestedQuantity = tonumber(args[#args]) or 0

				local existingItem = false

				for _, requestedItem in ipairs(requestedItems) do
					if string.lower(requestedItem['name']) == string.lower(displayName) then
						existingItem = true
						break
					end
				end

				if not existingItem then
					table.insert(requestedItems, {
						id = "",
						requestedQuantity = requestedQuantity,
						storedQuantity = 0,
						name = displayName,
						craftable = false,
						paused = true,
						status = "Pending update...",
						fingerpring = "",
					})
					response = "Item '" .. displayName .. "' added with requested quantity: " .. requestedQuantity
				else
					response = "Item '" .. displayName .. "' already exists in the requested items list"
				end

			end
			janus.save("requestedItems.tmp", requestedItems)
			print(response)
			print("List updated!")
			return response
		end
	},

	modify = {
		description = "Modify the requested quantity for item(s) in the requested items list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")
			local newRequestedQuantity = tonumber(table.remove(args))

			if not newRequestedQuantity then
				response = "Invalid quantity provided"
			else
				local indexNumbers = {}

				-- Separate index numbers and display names
				for _, arg in ipairs(args) do
					local index = tonumber(arg)
					if index then
						table.insert(indexNumbers, index)
					else
						modifyItem(requestedItems, arg, newRequestedQuantity)
					end
				end

				-- Modify items based on index numbers
				if #indexNumbers > 0 then
					for _, index in ipairs(indexNumbers) do
						if index >= 1 and index <= #requestedItems then
							local item = requestedItems[index]
							item['requestedQuantity'] = newRequestedQuantity
							print("Modified requested quantity for item at index " .. index)
						else
							print("Invalid index number: " .. index)
						end
					end
					response = "Items modified successfully"
				end
			end

			janus.save("requestedItems.tmp", requestedItems)
			print(response)
			return response
		end
	},

	pause = {
		description = "Pause item(s) in the requested items list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")

			if args[1] == "all" then
				for _, item in ipairs(requestedItems) do
					item['paused'] = true
				end
				response = "All items paused with no exception!"
			else
				for _, arg in ipairs(args) do
					local index = tonumber(arg)
					if index then
						local item = requestedItems[index]
						if item then
							item['paused'] = true
							print("Item at index " .. index .. " paused successfully")
						else
							print("Invalid index number: " .. index)
						end
					else
						performAction(requestedItems, "pause", arg)
					end
				end
				response = "Items paused successfully"
			end

			janus.save("requestedItems.tmp", requestedItems)
			print(response)
			return response
		end
	},

	unpause = {
		description = "Unpause item(s) in the requested items list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")

			if args[1] == "all" then
				for _, item in ipairs(requestedItems) do
					item['paused'] = false
				end
				response = "All items unpaused with no exception!"
			else
				for _, arg in ipairs(args) do
					local index = tonumber(arg)
					if index then
						local item = requestedItems[index]
						if item then
							item['paused'] = false
							print("Item at index " .. index .. " unpaused successfully")
						else
							print("Invalid index number: " .. index)
						end
					else
						performAction(requestedItems, "unpause", arg)
					end
				end
				response = "Items unpaused successfully"
			end

			janus.save("requestedItems.tmp", requestedItems)
			print(response)
			return response
		end
	},

	remove = {
		description = "Remove item(s) from the requested items list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")

			if args[1] == "all" then
				requestedItems = {}
				response = "All items removed with no exception!"
			else
				for _, arg in ipairs(args) do
					local index = tonumber(arg)
					if index then
						local item = requestedItems[index]
						if item then
							table.remove(requestedItems, index)
							print("Item at index " .. index .. " removed successfully")
						else
							print("Invalid index number: " .. index)
						end
					else
						performAction(requestedItems, "remove", arg)
					end
				end
				response = "Items removed successfully"
			end

			janus.save("requestedItems.tmp", requestedItems)
			print(response)
			return response
		end
	},
}