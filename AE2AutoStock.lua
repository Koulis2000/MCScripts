local shell = require("shell")
local component = require("component")
local sides = require("sides")
local fs = require("filesystem")
local serialization = require("serialization")
local meInterface = component.proxy(component.me_interface.address)
local gpu = component.gpu
gpu.setResolution(160,50)
local gui = require("gui")
local event = require("event")
local inventory_controller = component.inventory_controller
local screenWidth, screenHeight = gpu.getResolution()

local redrawCall = 0

local finalChestSide = 0
local finalChestSize = 0

gui.checkVersion(2,5)

local prgName = "Applied Energistics 2 Auto Stock"
local version = "v1.3"
local lines = {}
local items = {}
local chestItems = {}
local craftTasks = {}
local maxCpuUsage = 1
local currentCpuUsage = 0

local function LoadSide()
	local file,err = io.open("side.cfg", "r")
	if err == nil then
		local data = file:read("*n")
		finalChestSide = tonumber(data)
		file:close()
	end
end

local function SaveSide(side)
	local file,err = io.open("side.cfg", "w")
	file:write(side)
	file:close()
end

local function LoadSize()
	local file,err = io.open("size.cfg", "r")
	if err == nil then
		local data = file:read("*n")
		finalChestSize = tonumber(data)
		file:close()
	end
end

local function SaveSize(size)
	local file,err = io.open("size.cfg", "w")
	file:write(size)
	file:close()
end

local function LoadConfig()
	local file,err = io.open("config.cfg", "r")
	if err == nil then
		local data = file:read("*n")
		maxCpuUsage = tonumber(data)
		gui.setText(mainGui, CpuMaxUsage, maxCpuUsage .. "")
		file:close()
	end
end

local function SaveConfig()
	local file,err = io.open("config.cfg", "w")
	file:write(maxCpuUsage)
	file:close()
end

local function LoadItems()
	local file,err = io.open("items.cfg", "r")
	if err == nil then
		local data = file:read("*a")
		file:close()

		local itemsToLoad = serialization.unserialize(data)
		items = {}
		for index = 1, #itemsToLoad do
			items[index] = itemsToLoad[index]
		end

		for index = 1, #items do
			items[index]["Name"] = ""
			items[index]["CurrentCraftPerOperation"] = 0
			items[index]["CurrentValue"] = 0
			items[index]["Message"] = ""
		end
	end
end

local function SaveItems()
	local file,err = io.open("items.cfg", "w")
	local itemsToSave = {}
	for index = 1, #items do
		itemsToSave[index] = {}
		itemsToSave[index]["rawItemName"] = items[index]["rawItemName"]
		itemsToSave[index]["rawItemNBT"] = items[index]["rawItemNBT"]
		itemsToSave[index]["StockRequirement"] = items[index]["StockRequirement"]
		itemsToSave[index]["CraftPerOperation"] = items[index]["CraftPerOperation"]
	end
	file:write(serialization.serialize(itemsToSave))
	file:close()

	LoadItems()
end

mainGui = gui.newGui(1, 2, 159, 48, true)

local function DrawHeaders()
	Header_Name = gui.newLabel(mainGui, 4, 2, "Name", 0x02243F, 0xF36E21, 30)
	Header_Current = gui.newLabel(mainGui, 35, 2, "Current (Requirement)", 0x02243F, 0xF36E21, 18)
	Header_Crafting = gui.newLabel(mainGui, 54, 2, "Crafting", 0x02243F, 0xF36E21, 8)
	Header_Message = gui.newLabel(mainGui, 63, 2, "Message", 0x02243F, 0xF36E21, 15)
	Header_Line = gui.newHLine(mainGui, 1, 3, 76)
	Header2_Name = gui.newLabel(mainGui, 84, 2, "Name", 0x02243F, 0xF36E21, 30)
	Header2_Current = gui.newLabel(mainGui, 115, 2, "Current (Requirement)", 0x02243F, 0xF36E21, 18)
	Header2_Crafting = gui.newLabel(mainGui, 134, 2, "Crafting", 0x02243F, 0xF36E21, 8)
	Header2_Message = gui.newLabel(mainGui, 143, 2, "Message", 0x02243F, 0xF36E21, 15)
	Header2_Line = gui.newHLine(mainGui, 81, 3, 76)
end

local function DrawLines()
	local rowCount = 1
	for index = 1, 86 do
		if index % 2 == 1 then
			lines[index] = {}
			lines[index]["Radio"] = gui.newRadio(mainGui, 1, 3 + rowCount)
			lines[index]["Name"] = gui.newLabel(mainGui, 4, 3 + rowCount, "", 0x02243F, 0xF36E21, 30)
			lines[index]["Current"] = gui.newLabel(mainGui, 35, 3 + rowCount, "", 0x02243F, 0xF36E21, 18)
			lines[index]["Crafting"] = gui.newLabel(mainGui, 54, 3 + rowCount, "", 0x02243F, 0xF36E21, 8)
			lines[index]["Message"] = gui.newLabel(mainGui, 63, 3 + rowCount, "", 0x02243F, 0xF36E21, 15)
		else
			lines[index] = {}
			lines[index]["Radio"] = gui.newRadio(mainGui, 81, 3 + rowCount)
			lines[index]["Name"] = gui.newLabel(mainGui, 84, 3 + rowCount, "", 0x02243F, 0xF36E21, 30)
			lines[index]["Current"] = gui.newLabel(mainGui, 115, 3 + rowCount, "", 0x02243F, 0xF36E21, 18)
			lines[index]["Crafting"] = gui.newLabel(mainGui, 134, 3 + rowCount, "", 0x02243F, 0xF36E21, 8)
			lines[index]["Message"] = gui.newLabel(mainGui, 143, 3 + rowCount, "", 0x02243F, 0xF36E21, 15)
			rowCount = rowCount + 1
		end
	end

	for index = 1, 86 do
		gui.setVisible(mainGui, lines[index]["Radio"], false, true)
	end
end

local function EmptyLines()
	for index = 1, 86 do
		gui.setVisible(mainGui, lines[index]["Radio"], false, true)
		gui.setText(mainGui, lines[index]["Name"], "")
		gui.setText(mainGui, lines[index]["Current"], "")
		gui.setText(mainGui, lines[index]["Crafting"], "")
		gui.setText(mainGui, lines[index]["Message"], "")
	end
end

local function FillLines()
	for index = 1, #items do
		gui.setVisible(mainGui, lines[index]["Radio"], true, true)
		gui.setEnable(mainGui, lines[index]["Radio"], true, true)
		gui.setText(mainGui, lines[index]["Name"], items[index]["Name"])
		gui.setText(mainGui, lines[index]["Current"], items[index]["CurrentValue"] .. " (" .. items[index]["StockRequirement"] .. ")")
		if items[index]["CurrentCraftPerOperation"] > 0 then
			gui.setText(mainGui, lines[index]["Crafting"], items[index]["CurrentCraftPerOperation"] .. "")
		else
			gui.setText(mainGui, lines[index]["Crafting"], "")
		end
		gui.setText(mainGui, lines[index]["Message"], items[index]["Message"])
	end
end

local addGui_Open
local changeGui_Open
local addItem = {}
local changeItemIndex

local function ItemName_Callback(guiID, textID, text)
   addItem["Name"] = text
end

local function StockRequirement_Callback(guiID, textID, text)
   addItem["StockRequirement"] = tonumber(text)
end

local function ItemNBT_Callback(guiID, textID, text)
   addItem["NBT"] = tonumber(text)
end

local function CraftPerOperation_Callback(guiID, textID, text)
   addItem["CraftPerOperation"] = tonumber(text)
end

local function addButtonCallback(guiID, id)
	index = #items + 1
	if index <= 86 then
		items[index] = {}
		items[index]["rawItemName"] = addItem["Name"]
		items[index]["rawItemNBT"] = addItem["NBT"]
		items[index]["StockRequirement"] = addItem["StockRequirement"]
		items[index]["CraftPerOperation"] = addItem["CraftPerOperation"]

		SaveItems()

		addGui_Open = false
	else
		addGui_Open = false
		gui.showMsg("Maximum number of items reached (86 items).")
	end
end

local function changeButtonCallback(guiID, id)
	index = changeItemIndex
	items[index] = {}
	items[index]["rawItemName"] = addItem["Name"]
	items[index]["rawItemNBT"] = addItem["NBT"]
	items[index]["StockRequirement"] = addItem["StockRequirement"]
	items[index]["CraftPerOperation"] = addItem["CraftPerOperation"]

	SaveItems()

	changeGui_Open = false
end

local function isValidSide(side)
	if inventory_controller.getStackInSlot(side, 1) ~= nil then
		print("Side " ..  side .. " is valid")
		return true
	end
end

local function getSideContainerSize(side)
	if isValidSide(side) then
		local s, slotCounter = 1, 0;
		while true do
			local stat, stk = pcall(inventory_controller.getStackInSlot, side, s)
			if stat then slotCounter = s; s = s + 1 else break end
		end
		print("Contrainer at side " ..  side .. " has " .. slotCounter .. " slots")
		return slotCounter
	end
end

local function isSideComputer(side)
	if isValidSide(side) and getSideContainerSize(side) <= 10 then 
		print("Contrainer at side " ..  side .. " is a computer")
		return true
	end
end

local function getChestSide()
	for sideCounter = 0, 5 do
		if isValidSide(sideCounter) and isSideComputer(sideCounter) ~= true then 
			print("Contrainer at side " ..  sideCounter .. " is a chest")
			return sideCounter
		end
	end
end

local function getChestSize()
	local chestSize = getSideContainerSize(getChestSide())
	print("Connected Chest has " .. chestSize .. " slots")
	return chestSize
end

local function addFromChestButton_Callback()
	gpu.setBackground(0x000000)
  	gpu.fill(1, 1, screenWidth, screenHeight, " ")
  		if finalChestSide == 0 then
		SaveSide(getChestSide())
	end
	if finalChestSize == 0 then
		SaveSize(getChestSize())
	end

	chestItems = {}
	for index = 1, finalChestSize do
		local item = inventory_controller.getStackInSlot(finalChestSide, index)
		if item then
			print("Item name: ", item.name)
			print("Item count: ", item.size)
			print("Item NBT: ", item.damage)
			chestItems[index] = {}
			chestItems[index]["rawItemName"] = item.name
			chestItems[index]["rawItemNBT"] = item.damage
			chestItems[index]["StockRequirement"] = item.size
			chestItems[index]["CraftPerOperation"] = 16
		else
			--print("Slot " .. index .. " is empty")
		end
	end
	for slot = 1, #chestItems do
		index = #items + 1
		if index <= 86 then
			local duplicateFound = 0
			for dupliCheck = 1, #items do
				if chestItems[slot]["rawItemName"] == items[dupliCheck]["rawItemName"] and chestItems[slot]["rawItemNBT"] == items[dupliCheck]["rawItemNBT"] then
					duplicateFound = 1
					print("Duplicate found, merging Stock requirements...")
					items[dupliCheck]["StockRequirement"] = items[dupliCheck]["StockRequirement"]+chestItems[slot]["StockRequirement"]
					break
				end
			end
			if duplicateFound == 0 then
				print("Adding " .. chestItems[slot]["rawItemName"] .. " with NBT " .. chestItems[slot]["rawItemNBT"] .. " and Stock requirement " .. chestItems[slot]["StockRequirement"] .. " (16 per Operation)")
				items[index] = {}
				items[index]["rawItemName"] = chestItems[slot]["rawItemName"]
				items[index]["rawItemNBT"] = chestItems[slot]["rawItemNBT"]
				items[index]["StockRequirement"] = chestItems[slot]["StockRequirement"]
				items[index]["CraftPerOperation"] = chestItems[slot]["CraftPerOperation"]
			end
			SaveItems()
		else
			gui.showMsg("Maximum number of items reached (86 items).")
		end
	end

	redrawCall = 1
end

local function scanForChestButton_Callback(guiID, id)
	gpu.setBackground(0x000000)
  	gpu.fill(1, 1, screenWidth, screenHeight, " ")

  	SaveSize(getChestSize())
	SaveSide(getChestSide())
	LoadSize()
	LoadSide()

	redrawCall = 1
end

local function cancelButtonCallback(guiID, id)
	addGui_Open = false
	changeGui_Open = false
end

local function exitButtonCallback(guiID, id)
	addGui_Open = false
	changeGui_Open = false
	gpu.setBackground(0x000000)
  	gpu.setForeground(0xFFFFFF)
  	gpu.fill(1, 1, screenWidth, screenHeight, " ")
  	os.exit()
end

local function AddItem_Callback(guiID, buttonID)
	local addGui = gui.newGui("center", "center", 62, 10, true, "Add Item")
	Item_Name_Label = gui.newLabel(addGui, 1, 1, "   Item Name: ", 0x02243F, 0xF36E21, 7)
	Item_Name = gui.newText(addGui, 15, 1, 30, "", ItemName_Callback, 30, false)
	Item_NBT_Label = gui.newLabel(addGui, 1, 3, " Item NBT: ", 0x02243F, 0xF36E21, 7)
	Item_NBT = gui.newText(addGui, 15, 3, 8, "", ItemNBT_Callback, 8, false)
	Item_NBT_Help = gui.newLabel(addGui, 24, 3, "(Metadata number of item)", 0x02243F, 0xF36E21, 7)
	StockRequirement_Label = gui.newLabel(addGui, 1, 5, "    Keep In Stock: ", 0x02243F, 0xF36E21, 7)
	StockRequirement = gui.newText(addGui, 15, 5, 8, "", StockRequirement_Callback, 8, false)
	StockRequirement_Help = gui.newLabel(addGui, 24, 5, "(How many items to keep in stock)", 0x02243F, 0xF36E21, 7)	
	CraftPerOperation_Label = gui.newLabel(addGui, 1, 7, "Craft Per Operation: ", 0x02243F, 0xF36E21, 7)
	CraftPerOperation = gui.newText(addGui, 15, 7, 8, "", CraftPerOperation_Callback, 8, false)
	CraftPerOperation_Help = gui.newLabel(addGui, 24, 7, "(How many items to craft max at once)", 0x02243F, 0xF36E21, 7)
	addButton = gui.newButton(addGui, 41, 9, "Add Item", addButtonCallback)
	exitButton = gui.newButton(addGui, 52, 9, "Cancel", cancelButtonCallback)

	addGui_Open = true
	addItem = {}

	gui.displayGui(addGui)
	while addGui_Open do
		gui.runGui(addGui)
	end
	gui.closeGui(addGui)
end

local function RemoveItem_Callback(guiID, buttonID)
   local radioIndex = gui.getRadio(guiID)
   local removeIndex

   for index = 1, #lines do
		if lines[index]["Radio"] == radioIndex then
			removeIndex = index
		end
   end
   
   table.remove(items, removeIndex)
   SaveItems()
   EmptyLines()
end

local function ChangeItem_Callback(guiID, buttonID)
	local radioIndex = gui.getRadio(guiID)
	if radioIndex > 0 then
		for index = 1, #lines do
			if lines[index]["Radio"] == radioIndex then
				changeItemIndex = index
			end
		end

		local changeGui = gui.newGui("center", "center", 62, 10, true, "Change Item")
		Item_Name_Label = gui.newLabel(changeGui, 1, 1, "   Item Name: ", 0x02243F, 0xF36E21, 7)
		Item_Name = gui.newText(changeGui, 15, 1, 30, items[changeItemIndex]["rawItemName"], ItemName_Callback, 30, false)
		Item_NBT_Label = gui.newLabel(changeGui, 1, 3, " Item NBT: ", 0x02243F, 0xF36E21, 7)
		Item_NBT = gui.newText(changeGui, 15, 3, 8, items[changeItemIndex]["rawItemNBT"], ItemNBT_Callback, 8, false)
		Item_NBT_Help = gui.newLabel(changeGui, 24, 3, "(Metadata number of item)", 0x02243F, 0xF36E21, 7)
		StockRequirement_Label = gui.newLabel(changeGui, 1, 5, "    StockRequirement: ", 0x02243F, 0xF36E21, 7)
		StockRequirement = gui.newText(changeGui, 15, 5, 8, items[changeItemIndex]["StockRequirement"], StockRequirement_Callback, 8, false)
		StockRequirement_Help = gui.newLabel(changeGui, 24, 5, "(How many items to keep in stock)", 0x02243F, 0xF36E21, 7)	
		CraftPerOperation_Label = gui.newLabel(changeGui, 1, 7, "Craft Per Operation: ", 0x02243F, 0xF36E21, 7)
		CraftPerOperation = gui.newText(changeGui, 15, 7, 8, items[changeItemIndex]["CraftPerOperation"], CraftPerOperation_Callback, 8, false)
		CraftPerOperation_Help = gui.newLabel(changeGui, 24, 7, "(How many items to craft max at once)", 0x02243F, 0xF36E21, 7)
		changeButton = gui.newButton(changeGui, 38, 9, "Change Item", changeButtonCallback)
		exitButton = gui.newButton(changeGui, 52, 9, "Cancel", cancelButtonCallback)

		changeGui_Open = true
		addItem = {}
		addItem["Name"] = items[changeItemIndex]["rawItemName"]
		addItem["NBT"] = items[changeItemIndex]["rawItemNBT"]
		addItem["StockRequirement"] = items[changeItemIndex]["StockRequirement"]
		addItem["CraftPerOperation"] = items[changeItemIndex]["CraftPerOperation"]

		gui.displayGui(changeGui)
		while changeGui_Open do
			gui.runGui(changeGui)
		end
		gui.closeGui(changeGui)
	end
end

local function CpuMaxUsage_Callback(guiID, textID, text)
	maxCpuUsage = tonumber(text)
	SaveConfig()
end

local function DrawButtons()
	AddButton = gui.newButton(mainGui, 1, 1, "Add Item", AddItem_Callback)
	RemoveButton = gui.newButton(mainGui, 12, 1, "Remove Item", RemoveItem_Callback)
	ChangeButton = gui.newButton(mainGui, 26, 1, "Change Item", ChangeItem_Callback)
	AddFromChestButton = gui.newButton(mainGui, 40, 1, "Add Item/s From Chest", addFromChestButton_Callback)
	ScanForChestButton = gui.newButton(mainGui, 64, 1, "Scan for Chest", scanForChestButton_Callback)
	ExitButton = gui.newButton(mainGui, 82, 1, "Exit", exitButtonCallback)
	CpuUsageLabel = gui.newLabel(mainGui, 118, 1, "CPU usage: ", 0x02243F, 0xF36E21, 13)
	CpuMaxUsageLabel = gui.newLabel(mainGui, 134, 1, "Max CPU usage: ", 0x02243F, 0xF36E21, 15)
	CpuMaxUsage = gui.newText(mainGui, 149, 1, 4, maxCpuUsage .. "", CpuMaxUsage_Callback, 4, false)
end

function CheckItemsAndCraft()
	for index = 1, #items do
		items[index]["Message"] = ""
		items[index]["CurrentValue"] = 0
		items[index]["Name"] = ""
		
		local meItem = meInterface.getItemsInNetwork({ name = items[index]["rawItemName"], damage = items[index]["rawItemNBT"]})
		if meItem.n >= 1 then
			if not meItem[1].isCraftable then
				items[index]["Message"] = "Not Craftable"
			end

			items[index]["CurrentValue"] = meItem[1].size
			items[index]["Name"] = meItem[1].label

			indexCraftTask = 1
			for indexCraftTasks = 1, #craftTasks do
				if craftTasks[indexCraftTasks].Id == index then indexCraftTask = indexCraftTasks end
			end

			if craftTasks[indexCraftTask].task ~= nil and indexCraftTask > 1 then
				if craftTasks[indexCraftTask].task.isDone() or craftTasks[indexCraftTask].task.isCanceled() then
					currentCpuUsage = currentCpuUsage - 1
					items[index]["CurrentCraftPerOperation"] = 0
					table.remove(craftTasks, indexCraftTask)
				end
			else
				if items[index]["CurrentCraftPerOperation"] == 0 and items[index]["CurrentValue"] < items[index]["StockRequirement"] then
					if currentCpuUsage < maxCpuUsage then
						local meCpus = meInterface.getCpus()
						local occupiedCpus = 0
						for cpuIndex = 1, #meCpus do
							if meCpus[cpuIndex].busy then occupiedCpus = occupiedCpus + 1 end
						end
					
						if occupiedCpus < #meCpus then
							local currentCraftPerOperation = items[index]["StockRequirement"] - items[index]["CurrentValue"]
							if currentCraftPerOperation > items[index]["CraftPerOperation"] then
								currentCraftPerOperation = items[index]["CraftPerOperation"]
							end

							local craftables = meInterface.getCraftables({ name = items[index]["rawItemName"], damage = items[index]["rawItemNBT"]})
							if craftables.n >= 1 then
								craftTask = craftables[1].request(currentCraftPerOperation)

								if craftTask.isCanceled() then
									items[index]["Message"] = "No ingredients"
								else
									items[index]["CurrentCraftPerOperation"] = currentCraftPerOperation
									craftTaskWithId = { Id = index, task = craftTask }
									newIndex = #craftTasks + 1
									craftTasks[newIndex] = craftTaskWithId
									currentCpuUsage = currentCpuUsage + 1
								end
							end
						else
							items[index]["Message"] = "All CPUs busy"
						end
					else
						items[index]["Message"] = "All CPUs busy"
					end
				end
			end
		end
	end

	gui.setText(mainGui, CpuUsageLabel, "CPU Usage: " .. currentCpuUsage)
end

DrawHeaders()
DrawLines()
DrawButtons()
LoadSize()
LoadSide()
LoadConfig()
LoadItems()

gui.clearScreen()
gui.setTop("Applied Energistics 2 Auto Stock")
gui.setBottom("")

-- Create Empty craftTask
craftTasks[1] = { Id = 0, task = "" }

-- Main loop
local tickCount = 0

while true do
	gui.runGui(mainGui)
		if tickCount <= 0 then
			CheckItemsAndCraft()
			tickCount = 50
		else
			tickCount = tickCount - 1
			if redrawCall == 1 then
				shell.execute("clear")
				shell.setWorkingDirectory("/home/")
				shell.execute("switcher.lua")
				redrawCall = 0
			end
		end
	FillLines()
end