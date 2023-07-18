print("Initialising program...")
print("\tLoading dependencies.")
local inspect = require("inspect")
local janus = require("libjanus")
local waltz = require("waltz")

theme = {
   titleForegroundColour = 0x200,
   titleBackgroundColour = 0x80,
   textForegroundColour = 0x1,
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
local winButtons = {}

-- Define constants
local idConstant = 1
local fingerprintConstant = 2
local requestedQuantityConstant = 3
local nameConstant = 4
local craftableConstant = 5
local pausedConstant = 6
local statusConstant = 7
local countConstant = 8

-- Initialise Waltz
print("Initialising Waltz...")
print("\tDetecting monitor...")
local monitor = peripheral.find("monitor")
print("\tRedirecting terminal...")
term.redirect(monitor)
print("\t\tApplying CC/OC compatibility patch...")
if (mode == "CC") then -- CC/OC compatibility patch
   monitor = term
   thread = parallel
   -- From now on, we can program a bit like we were running on OC and it will still work on CC
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
local lblsDisplayName = {}
local lblsAvailableQuantity = {}
local lblsRequestedQuantity = {}
local lblsStatus = {}
local btnsPlus = {}
local btnsMinus = {}

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

printStatus("Initialising panels...")
local slices = 12
local column1 = math.floor(sizeX * 5 / slices)
local column2 = math.floor(sizeX * 2 / slices)+1
local column3 = math.floor(sizeX * 2 / slices)+1
local column4 = math.floor(sizeX * 3 / slices)
local panels = {
	pnlDisplayName = Panel.create(g, "Name", 1, 3, column1, sizeY - 4, true),
	pnlAvailableQuantity = Panel.create(g, "Available", column1+1, 3, column2, sizeY - 4, true),
	pnlRequestedQuantity = Panel.create(g, "Requested", column1+column2+1, 3, column3, sizeY - 4, true),
	pnlStatus = Panel.create(g, "Status", column1+column2+column3+1, 3, column4, sizeY - 4, true),
}
for _, p in pairs(panels) do
	print("\tPanel " .. p:getTitle() .. " added.")
	g:addComponent(p)
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
	-- Get some sleep
	sleep(5)
end

function updateInfo()
	setStatus("Updating info...")
	local requestedItems = janus.load('requestedItems.tmp')
	for k, v in ipairs(requestedItems) do -- Iterate over requestedItems. The key (index) goes in k, the value (item) goes in v
		--ipairs() because we want to preserve the order of the list
		local displayName = v['name']
		local availableQuantity = v['storedQuantity']
   	local requestedQuantity = v['requestedQuantity']
   	local status = v['status']
		if not lblsDisplayName[k] then
			lblsDisplayName[k] = Label.create(g, displayName, theme['textForegroundColour'], theme['textBackgroundColour'], 1, k, 25, 1)
			panels.pnlDisplayName:addComponent(lblsDisplayName[k])
		else
			lblsDisplayName[k]:setText(displayName)
		end
		if not lblsAvailableQuantity[k] then
			lblsAvailableQuantity[k] = Label.create(g, availableQuantity, theme['textForegroundColour'], theme['textBackgroundColour'], 1, k, 7, 1)
			panels.pnlAvailableQuantity:addComponent(lblsAvailableQuantity[k])
		else 
			lblsAvailableQuantity[k]:setText(availableQuantity)
		end
		if not lblsRequestedQuantity[k] then
			lblsRequestedQuantity[k] = Label.create(g, requestedQuantity, theme['textForegroundColour'], theme['textBackgroundColour'], 3, k, 7, 1)
			panels.pnlRequestedQuantity:addComponent(lblsRequestedQuantity[k])
		else
			lblsRequestedQuantity[k]:setText(requestedQuantity)
		end
		if not lblsStatus[k] then
			lblsStatus[k] = Label.create(g, status, theme['textForegroundColour'], theme['textBackgroundColour'], 3, k, 7, 1)
			panels.pnlStatus:addComponent(lblsStatus[k])
		else
			lblsStatus[k]:setText(status)
		end
		if not btnsMinus[k] then
			btnsMinus[k] = Button.create(g, "-", theme['failureForegroundColour'], theme['failureBackgroundColour'], 1, k, 1, 1)
			panels.pnlRequestedQuantity:addComponent(btnsMinus[k])
		end
		if not btnsPlus[k] then
			btnsPlus[k] = Button.create(g, "+", theme['successForegroundColour'], theme['successBackgroundColour'], 11, k, 1, 1)
			panels.pnlRequestedQuantity:addComponent(btnsPlus[k])
		end
	end
	setStatus("Updated info.")
end


print(".")
g:run(main)