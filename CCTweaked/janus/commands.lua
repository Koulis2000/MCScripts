local janus = require('../libjanus')
local response = "Command executed"
commands = {
	update = {
		description = "Update the requestedItems list with items from the adjacent inventory",
		handler = function()
			response = "Inventory updated successfully"
			updateRequestedItems()
			print(response)
			return response
		end
	},
	add = {
		description = "Add items to the requestedItems list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")

			if args[1] == "inventory" then
				if isInventory() then
					local inventory = getInventory()
					local inventorySize = inventory.size()
					print("Inventory size is ".. inventorySize)
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
								local isCraftable = meBridge.isItemCraftable(item)
								--table.insert(requestedItems, {item.name, "", item.count, item.displayName, isCraftable})
								local requestedItem = {}
								requestedItem['id'] = item.name
								requestedItem['requestedQuantity'] = item.count
								requestedItem['name'] = item.displayName
								requestedItem['craftable'] = item.isCraftable
								table.insert(requestedItems, requestedItem)
							end
						end
					end

					janus.save("requestedItems.tmp", requestedItems)
					response = "Inventory items added successfully"
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

				for _, requestedItem in ipairs(requestedItems) do
					if string.lower(requestedItem['name']) == string.lower(displayName) then
						existingItem = true
						break
					end
				end

				if not existingItem then
					--table.insert(requestedItems, {"", "", stockAmount, displayName, false})
					local requestedItem = {}
					requestedItem['id'] = ""
					requestedItem['requestedQuantity'] = stockAmount
					requestedItem['name'] = displayName
					requestedItem['craftable'] = false
					table.insert(requestedItems, requestedItem)
					response = "Item '" .. displayName .. "' added with stock amount: " .. stockAmount
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
		description = "Modify the 'min' value for item(s) in the requested items list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")

			-- Check if the arguments contain index numbers and the new 'min' value
			local indexNumbers = {}
			local newMinValue = tonumber(table.remove(args))
			if not newMinValue then
				response = "Invalid 'min' value provided"
				return response
			end

			-- This for loop is probably unecessary. The call to table.remove() with args
			-- removes the last element of the args array. That last element was the new min
			-- value. The remaining elements of args should now all be index numbers, which
			-- means there is no point in copying the array (which is all this for loop does)
			for _, arg in ipairs(args) do
				local index = tonumber(arg)
				if index then
					table.insert(indexNumbers, index)
				end
			end

			-- Check if index numbers are present
			if #indexNumbers > 0 then
				-- Modify the 'min' value for items in the requested items list using the index numbers
				for _, index in ipairs(indexNumbers) do
					if index >= 1 and index <= #requestedItems then -- Check if index is within bounds :thumbsup:
						local item = requestedItems[index]
						item['requestedQuantity'] = newMinValue
						print("Modified requested quantity for item at index " .. index)
					else
						print("Invalid index number: " .. index)
					end
				end
				response = "Items modified successfully"
				janus.save("requestedItems.tmp", requestedItems)
			else
				response = "Please provide the index number(s) of the item(s) to modify"
			end

			print(response)
			return response
		end
	},

	pause = {
		description = "Pause item(s) in the requested items list",
		handler = function(...)
			local args = {...}
			local requestedItems = janus.load("requestedItems.tmp")

			-- Check if the arguments contain index numbers or "all"
			local indexNumbers = {}
			local pauseAll = false
			for _, arg in ipairs(args) do
				if arg == "all" then
					pauseAll = true
					break
				end

				local index = tonumber(arg)
				if index then
					table.insert(indexNumbers, index)
				end
			end

			-- If "all" is provided, pause all items
			if pauseAll then
				for _, item in ipairs(requestedItems) do
					item['paused'] = true
				end
				response = "All items paused with no exception!"
			else
				-- Check if index numbers are present
				if #indexNumbers > 0 then
					-- Set the 'paused' key to true for items in the requested items list using the index numbers
					for _, index in ipairs(indexNumbers) do
						if index >= 1 and index <= #requestedItems then
							local item = requestedItems[index]
							item['paused'] = true
							print("Item '" .. item['name'] .. "' paused successfully")
						else
							print("Invalid index number: " .. index)
						end
					end
					response = "Items paused successfully"
				else
					-- No index numbers provided, treat the arguments as the display name
					local displayName = table.concat(args, " ")
					if displayName == "" then
						respone = "Please provide the display name or index number(s) of the item(s) to pause"
					else
						pauseItem(displayName)
						response = "Item ".. displayName .." paused successfully"
					end
				end
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

			-- Check if the arguments contain index numbers or "all"
			local indexNumbers = {}
			local unpauseAll = false
			for _, arg in ipairs(args) do
				if arg == "all" then
					unpauseAll = true
					break
				end

				local index = tonumber(arg)
				if index then
					table.insert(indexNumbers, index)
				end
			end

			-- If "all" is provided, unpause all items
			if unpauseAll then
				for _, item in ipairs(requestedItems) do
					item['paused'] = false
				end
				response = "All items unpaused with no exception!"
			else
				-- Check if index numbers are present
				if #indexNumbers > 0 then
					-- Set the 'pause' to false for items in the requested items list using the index numbers
					for _, index in ipairs(indexNumbers) do
						if index >= 1 and index <= #requestedItems then
							local item = requestedItems[index]
							item['paused'] = false
							print("Item '" .. item['name'] .. "' paused successfully")
						else
							print("Invalid index number: " .. index)
						end
					end
					response = "Items unpaused successfully"
				else
					-- No index numbers provided, treat the arguments as the display name
					local displayName = table.concat(args, " ")
					if displayName == "" then
						response = "Please provide the display name or index number(s) of the item(s) to pause"
					else
						unpauseItem(displayName)
						response = "Item ".. displayName .." unpaused successfully"
					end
				end
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

			-- Helper function to remove items based on indexes
			local function removeItemsByIndexes(indexNumbers)
				-- Sort the index numbers in descending order to ensure correct removal
				table.sort(indexNumbers, function(a, b) return a > b end)

				-- Remove items from the requestedItems list using the index numbers
				for _, index in ipairs(indexNumbers) do
					if index >= 1 and index <= #requestedItems then
						local removedItem = table.remove(requestedItems, index)
						print("Item '" .. removedItem['name'] .. "' removed successfully")
					else
						print("Invalid index number: " .. index)
					end
				end
			end

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
				removeItemsByIndexes(indexNumbers)
				response = "Items removed successfully"
			else
				-- No index numbers provided, treat the arguments as the display name
				local displayName = table.concat(args, " ")
				if displayName == "" then
					response = "Please provide the display name or index number(s) of the item(s) to remove"
				else
					removeItem(displayName)
					response = "Item ".. displayName .." removed successfully"
				end
			end

			janus.save("requestedItems.tmp", requestedItems)

			print(response)
			return response
		end
	},
}