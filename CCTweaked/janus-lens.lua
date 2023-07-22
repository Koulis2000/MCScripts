print("Initialising program...")
print("\tLoading dependencies.")
local inspect = require("inspect")
local janus = require("libjanus")
local waltz = require("waltz")

-- Read commands definition file
require('janus/commands') 	-- Note that this is not commands = require('janus/commands')
									-- The reason is that janus/commands.lua defines the global
									-- variable commands when it is required. Since it is global,
									-- it is available from this file as well.
if not commands then -- Checking that janus/commands.lua managed to define itself
	-- If not, the program still runs, but commands won't work
	print("Commands not defined!")
end

theme = {
	titleForegroundColour = 0x8000,
	titleBackgroundColour = 0x8,
	textForegroundColour = 0x8,
	textBackgroundColour = 0x8000,
	successForegroundColour = 0x20,
	successBackgroundColour = 0x8000,
	failureForegroundColour = 0x4000,
	failureBackgroundColour = 0x8000,
	buttonForegroundColour = 0x800,
	buttonBackgroundColour = 0x8000,
	textScale = 0.5
}

-- Window variables
local sizeX, sizeY
local w = nil

-- Initialise Waltz
print("Initialising Waltz...")
print("\tDetecting monitor...")
local monitor = peripheral.find("monitor")
print("\tSetting text scale")
monitor.setTextScale(theme['textScale'])
print("\tRedirecting terminal...")
term.redirect(monitor)
print("\t\tApplying CC/OC compatibility patch...")
-- Find the speaker peripheral
local speaker = peripheral.find("speaker")
if not speaker then
	print("No speaker found!")
	return
end
if (mode == "CC") then -- CC/OC compatibility patch
monitor = term
thread = parallel
	--From now on, we can program a bit like we were running on OC and it will still work on CC
end


print("\tCreating window...")
local x, y = 1, 1
if (mode == "CC") then
	print("\t\tDetermining size of window...")
	sizeX, sizeY = monitor.getSize()
	print("\t\tCreating...")
	w = window.create(monitor.current(), x, y, sizeX, sizeY)
else
	print("\t\tDetermining size of window...")
	sizeX, sizeY = monitor.gpu().getResolution()
	print("\t\tCreating...")
	w = Window.create(x, y, sizeX, sizeY)
end

if (w == nil) then
	error("Could not initialise window!")
end

--print("Created window: @ " .. x .. "&" .. y .. "/" .. sizeX .. "x" .. sizeY)
sleep(1)
print("\tCreating Waltz GUI object...")
local g = Waltz.create(w, theme, "Janus Lens")
print("Initialising status label...")
local lblStatus = nil

-- Sets the text of the status label
local function setStatus(status)
	local x, y = w.getSize() -- Get size of the monitor
	local statusText = textutils.formatTime(os.time(), true) .. ": " .. status -- Construct a string for the status label
	if not lblStatus and lblStatus == nil then -- If the status label does not exist, ...
			lblStatus = Label.create(g, statusText, theme['textForegroundColour'], theme['textBackgroundColour'], 1, y, x - 1, 1) -- ... create it.
			g:addComponent(lblStatus) -- Then add it to the GUI object
	 end
	 lblStatus:setText(statusText) -- If it did exist, just update the text on it
end

-- Calls setStatus with status as a parameter and prints status
local function printStatus(status)
	setStatus(status)
	print(status)
end

-- Initialise arrays for holding components
-- This should be done like the panels, below, instead, probably...
printStatus("Initialising component holding arrays...")

local lblsIndex = {}
local lblsDisplayName = {}
local lblsStoredQuantity = {}
local lblsRequestedQuantity = {}
local lblsStatus = {}
local btnsSelect = {}
local btnsPlus = {}
local btnsMinus = {}
local btnPauseAll = nil
local btnPause = nil
local btnModify = nil
local btnRemove = nil
local selectedItems = {}

local checkedCharacter = string.char(0x8)
local uncheckedCharacter = string.char(0x7)

-- Function to get the selected items as a space-separated string
local function getSelected()
	local selectedIndexes = {}
	for index, selected in pairs(selectedItems) do
		if selected then
			table.insert(selectedIndexes, index)
		end
	end
	return table.concat(selectedIndexes, " ")
end

-- Function to clear the selection of items
local function clearSelection()
	for index, _ in pairs(selectedItems) do
		selectedItems[index] = false
		btnsSelect[index]:setText(uncheckedCharacter)
	end
end

printStatus("Starting Janus Dossier (if not running)...")
local dossierProcessID = nil
if janus.isProcessRunning('Janus Dossier') then
	printStatus("\tJanus Dossier already running, fetching process ID...")
	dossierProcessID = janus.getProcessID('Janus Dossier')
else
	printStatus("\tJanus Dossier not running, starting...")
	dossierProcessID = shell.openTab('janus-dossier')
	printStatus("\tChanging tab title to Janus Dossier")
	multishell.setTitle(dossierProcessID, 'Janus Dossier')
end

if dossierProcessID == nil then
	error("Could not get process ID of Janus Dossier! Perhaps you are trying to run on a normal Computer? Janus requires an Advanced Computer.")
end

printStatus("Changing own tab title to Janus Lens")
local processID = multishell.getCurrent()
multishell.setTitle(processID, 'Janus Lens')

-- Advanced Panel setup
local borders = "br"
local corners = "blbrtr"
local borderChars = { t = string.char(0x8c), b = string.char(0x83), l = string.char(0x95), r = string.char(0x95) }
local cornerChars = { tl = string.char(0x88), tr = string.char(0x96), bl = string.char(0x82), br = string.char(0x81) }

printStatus("Initialising panels...")
local slices = 17
local column1 = math.floor(sizeX * 5 / slices)
local column2 = math.floor(sizeX * 3 / slices)
local column3 = math.floor(sizeX * 3 / slices)
local column4 = math.floor(sizeX * 5 / slices)
local column5 = math.floor(sizeX * 1 / slices)
local panels = {
	--pnlDisplayName = Panel.create(g, "Name", 1, 3, column1, sizeY - 4, true),
	--pnlStoredQuantity = Panel.create(g, "Stored", column1+1, 3, column2, sizeY - 4, true),
	--pnlRequestedQuantity = Panel.create(g, "Requested", column1+column2+1, 3, column3, sizeY - 4, true),
	--pnlStatus = Panel.create(g, "Status", column1+column2+column3+1, 3, column4-1, sizeY - 4, true),
	--pnlActions = Panel.create(g, "ACT", column1+column2+column3+column4+2, 3, column5, sizeY - 4, false),
	pnlDisplayName = AdvancedPanel.create(g, string.char(0x98).. " " .. "Name", "left", 1, 3, column1, sizeY - 4, borders, corners, borderChars, cornerChars),
	pnlStoredQuantity = AdvancedPanel.create(g, string.char(0x98).. " " .. "Stored", "left", column1+1, 3, column2, sizeY - 4, borders, corners, borderChars, cornerChars),
	pnlRequestedQuantity = AdvancedPanel.create(g, string.char(0x98).. " " .. "Requested", "left", column1+column2+1, 3, column3, sizeY - 4, borders, corners, borderChars, cornerChars),
	pnlStatus = AdvancedPanel.create(g, string.char(0x98).. " " .. "Status", "left", column1+column2+column3+1, 3, column4, sizeY - 4, borders, corners, borderChars, cornerChars),
	pnlActions = AdvancedPanel.create(g, string.char(0x98).. " " .. "ACT", "left", column1+column2+column3+column4+1, 3, column5, sizeY - 4),
}
for _, p in pairs(panels) do
	print("\tPanel " .. p:getTitle() .. " added.")
	g:addComponent(p)
end


-- Function to write commands to the command queue
local function enqueueCommand(command)
	local identifier = tostring(os.clock()):gsub("%.", "") -- Assign clock as the identifier
	local commandQueue = janus.load("commandQueue.tmp")
	local commandData = {
		id = identifier,
		cmd = command
	}
	table.insert(commandQueue, commandData)
	janus.save("commandQueue.tmp", commandQueue)
end


-- Function to check for updates from the processor program
local function checkForUpdates()
	local responseQueue = janus.load("commandResponses.tmp", {}) -- Table to hold response data
	for _, responseData in ipairs(responseQueue) do
		local commandId = responseData.id
		local processedResponse = responseData.response
			
		print("Response for commandId:", commandId)
		print("Processed response:", processedResponse)
	end

	-- Return the last commandId and its corresponding processedResponse
	if #responseQueue > 0 then
		local lastResponseData = responseQueue[#responseQueue]
		return lastResponseData.id, lastResponseData.response
	end
	return nil
end


-- Function to remove a processed command from the command queue and its response
local function removeProcessedCommand(commandId)
	local commandQueue = janus.load("commandQueue.tmp", {})
	local cmds = {}
	for _, commandData in ipairs(commandQueue) do
		if tostring(commandData.id) ~= tostring(commandId) then
			table.insert(cmds, commandData)
		end
	end
	janus.save("commandQueue.tmp", cmds)

	local responseQueue = janus.load("commandResponses.tmp", {})
	local responses = {}
	for _, responseData in ipairs(responseQueue) do
		if tostring(responseData.id) ~= tostring(commandId) then
			table.insert(responses, responseData)
		end
	end
	janus.save("commandResponses.tmp", responses)
end

setStatus("Starting.....")
write("Initialisation complete! Starting")
for i = 4, 0, -1 do -- Make it a slow start to allow janus-dossier time for its first update, in case it wasn't running
write(".")
sleep(1)
end

function main()
	-- Do things
	updateInfo()
	-- Who needs sleep anyway? Let the UI run free and be the strong independent responsive insomniac UI it always wanted to be, Bjørn!
	-- sleep(2) 
	-- Bjørn: *comments out the sleep()* Off you go, UI, you're free now!
	local commandId, processedResponse = checkForUpdates()
	if commandId and processedResponse then
		-- Remove the processed command from the command queue
		removeProcessedCommand(commandId)
		print(processedResponse)
	end
	sleep(0.1) 	-- I never sleep*, cause sleep is the cousin of death
					-- (*for more than 0.1 seconds)
end

local globalPause = false
local lastUpdateTime = os.clock()
function updateInfo()
	if (os.clock() - lastUpdateTime) < 3 then
		return 	-- less than 3 seconds since last info update, let's not do it again yet (to avoid excessive UI updates)
					-- excessive updates may eat debug/status messages, making us miss them
	end
	setStatus("Updating info...")
	local requestedItems = janus.load('requestedItems.tmp')
	local statusStore = janus.load('statusStore.tmp')
	for k, v in ipairs(requestedItems) do -- Iterate over requestedItems. The key (index) goes in k, the value (item) goes in v
		--ipairs() because we want to preserve the order of the list
		local displayName = v['name']
		local storedQuantity = v['storedQuantity']
		local requestedQuantity = v['requestedQuantity']
		local status = statusStore[k]['status']
		local checkBox = uncheckedCharacter

		local formattedIndex = k -- the formatted index adds white spaces in front of the index number in order to align the text better
		local decimalSpacer = 1 -- the decimalSpacer is used to space the display name correctly when the formattedIndex is long enough
		local textColor
		if k % 2 == 0 then
			textColor = colors.white
		else
			textColor = colors.lightGray
		end

		if #requestedItems <= 9 then
			formattedIndex = string.format("%d. ", k)
			decimalSpacer = 4
		elseif #requestedItems <= 90 then
			formattedIndex = string.format("%2d. ", k)
			decimalSpacer = 5
		elseif #requestedItems <= 900 then
			formattedIndex = string.format("%3d. ", k)
			decimalSpacer = 6
		end

		if selectedItems[k] == nil or not selectedItems[k] then
			checkBox = uncheckedCharacter
			selectedItems[k] = false
		elseif selectedItems[k] then
			checkBox = checkedCharacter
		end

		if not btnsSelect[k] then
			btnsSelect[k] = Button.create(g, checkBox, theme['failureForegroundColour'], theme['failureBackgroundColour'], 0, k+1, 1, 1)
			panels.pnlDisplayName:addComponent(btnsSelect[k])
		end
		if not lblsIndex[k] then
			lblsIndex[k] = Label.create(g, formattedIndex, textColor, theme['textBackgroundColour'], 2, k+1, decimalSpacer, 1)
			panels.pnlDisplayName:addComponent(lblsIndex[k])
		else
			lblsIndex[k]:setText("")
			lblsIndex[k]:setText(formattedIndex)
		end
		if not lblsDisplayName[k] then
			lblsDisplayName[k] = Label.create(g, displayName, textColor, theme['textBackgroundColour'], decimalSpacer, k+1, 25, 1)
			panels.pnlDisplayName:addComponent(lblsDisplayName[k])
		else
			lblsDisplayName[k]:setText("")
			lblsDisplayName[k]:setText(displayName)
		end
		if not lblsStoredQuantity[k] then
			lblsStoredQuantity[k] = Label.create(g, storedQuantity, textColor, theme['textBackgroundColour'], 2, k+1, 7, 1)
			panels.pnlStoredQuantity:addComponent(lblsStoredQuantity[k])
		else 
			lblsStoredQuantity[k]:setText("")
			lblsStoredQuantity[k]:setText(storedQuantity)
		end
		if not lblsRequestedQuantity[k] then
			lblsRequestedQuantity[k] = Label.create(g, requestedQuantity, textColor, theme['textBackgroundColour'], 2, k+1, 7, 1)
			panels.pnlRequestedQuantity:addComponent(lblsRequestedQuantity[k])
		else
			lblsRequestedQuantity[k]:setText("")
			lblsRequestedQuantity[k]:setText(requestedQuantity)
		end
		if not lblsStatus[k] then
			lblsStatus[k] = Label.create(g, status, textColor, theme['textBackgroundColour'], 2, k+1, 7, 1)
			panels.pnlStatus:addComponent(lblsStatus[k])
		else
			lblsStatus[k]:setText("")
			lblsStatus[k]:setText(status)
		end
		if not btnsMinus[k] then
			btnsMinus[k] = Button.create(g, "-", theme['failureForegroundColour'], theme['failureBackgroundColour'], 0, k+1, 1, 1)
			panels.pnlRequestedQuantity:addComponent(btnsMinus[k])
		end
		if not btnsPlus[k] then
			btnsPlus[k] = Button.create(g, "+", theme['successForegroundColour'], theme['successBackgroundColour'], column3-3, k+1, 1, 1)
			panels.pnlRequestedQuantity:addComponent(btnsPlus[k])
		end

		-- Click on it to select the item, click again to unselect it.
		btnsSelect[k]:setAction(function(comp)
			if selectedItems[k] then
				selectedItems[k] = false
				comp:setText(uncheckedCharacter)
				printStatus("Unselected " .. k)
				speaker.playSound("minecraft:entity.item_frame.break", 2)
			else
				selectedItems[k] = true
				comp:setText(checkedCharacter)
				printStatus("Selected " .. k)
				speaker.playSound("minecraft:entity.item_frame.add_item", 2)
			end
		end)

		-- Click to increase requested quantity by 1
		btnsPlus[k]:setAction(function(comp)
			enqueueCommand("modify " .. tostring(k) .. " " .. tostring(requestedQuantity+1))
			printStatus("Increased requested quantity for ".. displayName .. " by 1")
			speaker.playSound("minecraft:entity.item_frame.add_item", 2)
		end)

		-- Click to decrease requested quantity by 1
		btnsMinus[k]:setAction(function(comp)
			enqueueCommand("modify " .. tostring(k) .. " " .. tostring(requestedQuantity-1))
			printStatus("Decreased requested quantity for ".. displayName .. " by 1")
			speaker.playSound("minecraft:entity.item_frame.break", 2)
		end)
	end

	-- Add the pauseAll button
	if not btnPauseAll then
		btnPauseAll = Button.create(g, "STOP", colors.white, colors.red, 1, 2, 7, 3)
		panels.pnlActions:addComponent(btnPauseAll)
	end

	-- Add the pause
	if not btnPause then
		btnPause = Button.create(g, "PAUS", colors.white, colors.gray, 1, 6, 7, 3)
		panels.pnlActions:addComponent(btnPause)
	end

	-- Add the modify button
	if not btnModify then
		btnModify = Button.create(g, "MOD", colors.white, colors.gray, 1, 10, 7, 3)
		panels.pnlActions:addComponent(btnModify)
	end

	-- Add the remove button
	if not btnRemove then
		btnRemove = Button.create(g, "REM", colors.white, colors.gray, 1, 14, 7, 3)
		panels.pnlActions:addComponent(btnRemove)
	end

	-- Assign the functions to the corresponding button callbacks
	btnPauseAll:setAction(function(comp)
		if not globalPause then
			enqueueCommand("pause all")
			globalPause = true
			comp:setText("CONT")
		elseif globalPause then
			enqueueCommand("unpause all")
			globalPause = false
			comp:setText("STOP")
		end
	end)

	-- The pause button will take into consideration the selected items and pause them
	btnPause:setAction(function()
		if #selectedItems > 0 then
			enqueueCommand("pause "..getSelected())
			printStatus("Paused items " ..getSelected())
			clearSelection()
		else
			printStatus("No items selected to pause")
		end
	end)
	
	-- The modify button will take into consideration the selected items and modify them, code not yet implemented
	btnModify:setAction(function()
		printStatus("Modify command not yet implemented.")
		clearSelection()
	end)

	-- The remove button will take into consideration the selected items and remove them
	btnRemove:setAction(function()
		if #selectedItems > 0 then
			enqueueCommand("remove "..getSelected())
			printStatus("Removed items " ..getSelected())
			clearSelection()
		else
			printStatus("No items selected to remove")
		end
	end)
	lastUpdateTime = os.clock()
	setStatus("Updated info.")
end

print(".")
btnClose = Button.create(g, " X", colours.gray, colours.red, sizeX-1, 1, 3, 1)
btnClose:setAction(function() g.exit = true end)
g:addComponent(btnClose)
g:run(main)