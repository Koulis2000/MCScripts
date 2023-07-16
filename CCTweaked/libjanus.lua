local janus ={
  _VERSION = 'libjanus 0.0.1',
  _URL     = 'N/A',
  _DESCRIPTION = 'library for Janus',
  _LICENSE = [[
  
  ]]
}

-- Checks if a process with processName as its name is running
function janus.isProcessRunning(processName)
	local numProcesses = multishell.getCount() -- Find out how many processes are running
	for i = numProcesses, 1, -1 do -- Loop through them all
		local pName = multishell.getTitle(i) -- Get their names
		if pName == processName then -- Compare the names with the processName we are checking for
			return true -- Yes, it's running
		end
	end
	return false -- If the entire loop ran without returning, it's not running
end

-- Gets the process ID of the process with processName as its name
function janus.getProcessID(processName)
	local numProcesses = multishell.getCount() -- Find out how many processes are running
	for i = numProcesses, 1, -1 do -- Loop through them all
		local pName = multishell.getTitle(i) -- Get their names
		if pName == processName then
			return i
		end
	end
	return false
end

-- Loads (serialised) data from file and returns the data
-- Similar to settings.load()
-- !NOTE! File must be in folder /janus
function janus.load(file)
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

return janus