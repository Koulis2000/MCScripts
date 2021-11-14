local shell = require("shell")

local baseUrl = "https://github.com/Koulis2000/OCScripts/blob/master/"
local files = {}
local raw = "?raw=true"

shell.execute("resolution 80 25")

files[1] = {"ac.lua", "/"}
files[2] = {"stocklist.lua", "/lib/"}

for i,f in ipairs(files) do
  file = f[1]
  dir = f[2]
  url = f[3] or baseUrl
  fileNameOnServer = f[4] or file
  shell.execute("mkdir " .. dir)
  print(tostring(fileNameOnServer) .. " @ " .. tostring(url) .. " -> " .. tostring(dir))
  shell.setWorkingDirectory(tostring(dir))
  shell.execute("wget -f " .. url .. tostring(fileNameOnServer) .. raw)
  if (file ~= fileNameOnServer) then
    print("Renaming " .. fileNameOnServer .. " to " .. file)
    shell.execute("mv " .. fileNameOnServer .. " " .. file)
  end
end

--os.sleep(4)
shell.execute("clear")
shell.setWorkingDirectory("/")
shell.execute("ac.lua")

shell.setWorkingDirectory("/")