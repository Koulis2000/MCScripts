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
		if pName == processName then -- Compare the names with the processName we are checking for
			return i -- On a match, return i, which will be the process ID
		end
	end
	return false -- If no match is found, return false.
end

-- Saves (serialised) data to file.
-- Similar to settings.save().
-- !NOTE! File must be in directory /janus.
function janus.save(file, data)
	local fileName = "janus/" .. file -- Define our file name
	local serialisedData = textutils.serialise(data) -- Serialise the data
	local file = fs.open(fileName, "w") -- Open a file handle for the file name
	file.write(serialisedData)	-- Write serialised data to file
	file.close() -- Close the file handle
end
-- Loads (serialised) data from file and returns the data.
-- Similar to settings.load().
-- !NOTE! File must be in directory /janus.
function janus.load(file)
	local fileName = "janus/" .. file -- Define our file name
	if not fs.exists(fileName) then -- Check if it exists, and...
		error("File " .. fileName .. " does not exist!") -- ... die if it doesn't
	end
	local file = fs.open(fileName, "r") -- Open a file handle for the file name
	local serialisedData = file.readAll() -- Read the serialised data from it
	file.close() -- Close the file handle
	local data = textutils.unserialize(serialisedData) -- Deserialise the data
	return data -- Return it
end

return janus