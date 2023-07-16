-- Define constants
local idConstant = 1
local fingerprintConstant = 2
local countConstant = 3
local nameConstant = 4
local craftableConstant = 5

commands = {
    update = {
        description = "Update the requestedItems list with items from the adjacent inventory",
        handler = function()
            updateMeItems()
            print("Inventory updated successfully")
        end
    },
    add = {
        description = "Add items to the requestedItems list",
        handler = function(...)
            local args = {...}
            local requestedItems = load("requestedItems.tmp")

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
                                if string.lower(requestedItem[nameConstant]) == string.lower(item.displayName) then
                                    existingItem = true
                                    break
                                end
                            end

                            if not existingItem then
                                local isCraftable = meBridge.isItemCraftable(item)
                                table.insert(requestedItems, {item.name, "", item.count, item.displayName, isCraftable})
                            end
                        end
                    end

                    save("requestedItems.tmp", requestedItems)
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
                    if string.lower(requestedItem[4]) == string.lower(displayName) then
                        existingItem = true
                        break
                    end
                end

                if not existingItem then
                    table.insert(requestedItems, {"", "", stockAmount, displayName, false})
                    print("Item '" .. displayName .. "' added with stock amount: " .. stockAmount)
                else
                    print("Item '" .. displayName .. "' already exists in the meItems list")
                end
            end

            save("requestedItems.tmp", requestedItems)
            print("List updated!")
        end
    },

    modify = {
        description = "Modify the 'min' value for item(s) in the meItems list",
        handler = function(...)
            local args = {...}
            local requestedItems = load("requestedItems.tmp")

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
                -- Modify the 'min' value for items in the meItems list using the index numbers
                for _, index in ipairs(indexNumbers) do
                    if index >= 1 and index <= #requestedItems then -- Check if index is within bounds :thumbsup:
                        local item = requestedItems[index]
                        item[countConstant] = newMinValue
                        print("Modified 'min' value for item at index " .. index)
                    else
                        print("Invalid index number: " .. index)
                    end
                end
                save("requestedItems.tmp", requestedItems)
            else
                print("Please provide the index number(s) of the item(s) to modify")
            end
        end
    },

    remove = {
        description = "Remove item(s) from the meItems list",
        handler = function(...)
            local args = {...}
            local requestedItems = load("requestedItems.tmp")

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
            -- obamanotbad.svg
            table.sort(indexNumbers, function(a, b) return a > b end)

            -- Remove items from the meItems list using the index numbers
            for _, index in ipairs(indexNumbers) do
                if index >= 1 and index <= #requestedItems then
                    local removedItem = table.remove(requestedItems, index)
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
            save("requestedItems.tmp", requestedItems)
        end
    },
}