-- Define constants
local idConstant = 1
local fingerprintConstant = 2
local requestedQuantityConstant = 3
local nameConstant = 4
local craftableConstant = 5
local pausedConstant = 6
local statusConstant = 7
local countConstant = 8

local janus = require('../libjanus')

commands = {
    update = {
        description = "Update the requestedItems list with items from the adjacent inventory",
        handler = function()
            updateRequestedItems()
            print("Inventory updated successfully")
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
                    print("Item '" .. displayName .. "' added with stock amount: " .. stockAmount)
                else
                    print("Item '" .. displayName .. "' already exists in the requested items list")
                end
            end

            janus.save("requestedItems.tmp", requestedItems)
            print("List updated!")
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
                print("Invalid 'min' value provided")
                return
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
                        print("Modified 'min' value for item at index " .. index)
                    else
                        print("Invalid index number: " .. index)
                    end
                end
                janus.save("requestedItems.tmp", requestedItems)
            else
                print("Please provide the index number(s) of the item(s) to modify")
            end
        end
    },
    
    pause = {
        description = "Pause item(s) in the requested items list",
        handler = function(...)
            local args = {...}
            local requestedItems = janus.load("requestedItems.tmp")

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
                -- Set the 'pausedConstant' to true for items in the requested items list using the index numbers
                for _, index in ipairs(indexNumbers) do
                    if index >= 1 and index <= #requestedItems then
                        local item = requestedItems[index]
                        item['paused'] = true
                        print("Item '" .. item['name'] .. "' paused successfully")
                    else
                        print("Invalid index number: " .. index)
                    end
                end
                janus.save("requestedItems.tmp", requestedItems)
            else
                -- No index numbers provided, treat the arguments as the display name
                local displayName = table.concat(args, " ")
                if displayName == "" then
                    print("Please provide the display name or index number(s) of the item(s) to pause")
                else
                    pauseItem(displayName)
                end
            end
        end
    },

    unpause = {
        description = "Unpause item(s) in the requested items list",
        handler = function(...)
            local args = {...}
            local requestedItems = janus.load("requestedItems.tmp")

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
                -- Set the 'pausedConstant' to false for items in the requested items list using the index numbers
                for _, index in ipairs(indexNumbers) do
                    if index >= 1 and index <= #requestedItems then
                        local item = requestedItems[index]
                        item['paused'] = false
                        print("Item '" .. item['name'] .. "' unpaused successfully")
                    else
                        print("Invalid index number: " .. index)
                    end
                end
                janus.save("requestedItems.tmp", requestedItems)
            else
                -- No index numbers provided, treat the arguments as the display name
                local displayName = table.concat(args, " ")
                if displayName == "" then
                    print("Please provide the display name or index number(s) of the item(s) to pause")
                else
                    pauseItem(displayName)
                end
            end
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
            else
                -- No index numbers provided, treat the arguments as the display name
                local displayName = table.concat(args, " ")
                if displayName == "" then
                    print("Please provide the display name or index number(s) of the item(s) to remove")
                else
                    removeItem(displayName)
                end
            end

            janus.save("requestedItems.tmp", requestedItems)
        end
    },
}