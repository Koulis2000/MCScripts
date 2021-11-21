sleep(1)
local tArgs = { ... }
local chest = peripheral.find("minecraft:chest")

local expect = (require "cc.expect").expect
local settings = require "ae2.autostocksettings"
local raw = false

if not ae2 then
    printError("Error: unable to find ME peripheral.")
    return
end

local function getName(entry, handlers)
    expect(1, entry, "table")
    expect(2, handlers, "table")

    local stack = handlers.getStack(entry)
    if raw then
        if stack.nbt then return string.format("%s[%s]", stack.name, stack.nbt) end
        return stack.name
    else
        local item,err = handlers.find(stack)
        if not item then
            printError(err)
            return nil
        end
        return item.displayName
    end
end

local function getByName(name, handlers)
    expect(1, name, "string")
    expect(2, handlers, "table")

    -- first, try as a raw name.  this may fail.
    local ok, stack, err = pcall(handlers.find, {name=name})
    if ok and stack then return stack end
    if ok and err then printError(err) return nil end

    -- try matching against all the stacks in storage, unless in raw mode
    if not raw then
        local needle = name:lower()
        local haystack = {}
        for _,v in ipairs(handlers.all()) do
            if v.displayName:lower() == needle then
                table.insert(haystack, v)
            end
        end
        if #haystack == 0 then
            printError(string.format("Don't know what \"%s\" is.  Use raw name or put one in storage first.", name))
            return nil
        elseif #haystack == 1 then
            return haystack[1]
        end

        print("Multiple types found in storage.  Did you mean:")
        for i,v in ipairs(haystack) do
            print(string.format("%d: %dx %s (%s[%s])", i, handlers.formatQuantity(handlers.getQuantity(v)), v.displayName, v.name, v.nbt))
        end
        print("0: none of those")
        local i
        repeat
            i = tonumber(read())
        until i ~= nil and i >= 0 and i <= #haystack
        if i > 0 then return haystack[i] end
    end
end

local function list(filter)
    expect(1, filter, "nil", "table")

    local stock = settings.getStock()
    local display = {}
    for i,v in ipairs(stock) do
        local handlers, stack = settings.getHandlers(v)
        if handlers and (not filter or filter == handlers) then
            table.insert(display, string.format("%d: %s at %s", i, getName(v, handlers),
                handlers.formatQuantity(handlers.getQuantity(stack))))
        end
    end

    local _, height = term.getSize()
    textutils.pagedPrint(table.concat(display, "\n"), height - 3)
end

local function clean()
    local stock = settings.getStock()
    for i = #stock,1,-1 do
        local handlers, stack = settings.getHandlers(stock[i])
        if not handlers or not pcall(getName, stock[i], handlers) then
            table.remove(stock, i)
        end
    end
    settings.setStock(stock)
    print("Done")
end

local function setQuantity(name, quantity, handlers)
    expect(1, name, "string")
    expect(2, quantity, "number")
    expect(3, handlers, "table")

    local newStack = getByName(name, handlers)
    if not newStack then return end
    newStack = {name=newStack.name,nbt=newStack.nbt,tag=newStack.tag,json=newStack.json} -- simplify
    handlers.setQuantity(newStack, quantity)

    local stock = settings.getStock()
    local found = false
    for _,v in ipairs(stock) do
        local stack = handlers.getStack(v)
        if stack and stack.name == newStack.name and stack.nbt == newStack.nbt then
            handlers.setQuantity(stack, quantity)
            found = true
            break
        end
    end
    if not found then
        local entry = handlers.makeEntry(newStack)
        table.insert(stock, entry)
    end

    settings.setStock(stock)
    print("Done")
end

local function remove(i)
    expect(1, i, "number", "nil")

    local stock = settings.getStock()

    if i and i > 0 and i <= #stock then
        table.remove(stock, i)

        settings.setStock(stock)
        print("Done")
        return
    end

    printError("Expecting number between 1 and", #stock)
end

local function move(from, to)
    expect(1, from, "number", "nil")
    expect(2, to, "number", "nil")

    local stock = settings.getStock()
    if not from or from < 1 or from > #stock then
        printError("From value must be between 1 and", #stock)
        return
    elseif not to or to < 1 or to > #stock then
        printError("To value must be between 1 and", #stock)
        return
    elseif from == to then
        print("No change")
        return
    end

    table.insert(stock, to, table.remove(stock, from))

    settings.setStock(stock)

    print("New stock order:")
    list()
end

local function startService()
    if multishell and shell.openTab then
        for i = 1, multishell.getCount() do
            if multishell.getTitle(i) == "autostock" then
                printError("autostock is already running in the background")
                return
            end
        end
        shell.openTab("autostock")
        print("AutoStock is now running in the background; you can continue to adjust settings.")
    else
        shell.run("autostock")
    end
end

if #tArgs > 0 and tArgs[1] == "raw" then
    raw = true
    table.remove(tArgs, 1)
end

if #tArgs == 0 then
    -- "stock"
    tArgs = { "list" }
end

if tArgs[1] == "list" and #tArgs == 1 then
    -- "stock list"
    print("Stock list:")
    list()
elseif tArgs[1] == "clean" and #tArgs == 1 then
    -- "stock clean"
    clean()
elseif tArgs[1] == "refresh" and #tArgs == 1 then
    -- "stock refresh"
    print("AutoStock refresh rate is", settings.getRefresh(), "seconds")
elseif tArgs[1] == "refresh" and #tArgs == 2 then
    -- "stock refresh N"
    local value = tonumber(tArgs[2])
    if value then
        settings.setRefresh(value)
        print("AutoStock refresh rate is now", value, "seconds")
    else
        printError("Can't set refresh rate to something that's not a number")
    end
elseif tArgs[1] == "item" then
    if #tArgs == 1 then
        -- "stock item S N"
        print("Stocked items:")
        list(settings.handlers.item)
    elseif #tArgs == 3 then
        setQuantity(tArgs[2], tonumber(tArgs[3]), settings.handlers.item)
    elseif #tArgs > 3 then
        -- "stock item S S S... N"
        for i = 2, #tArgs-2, 1 do
            setQuantity(tArgs[i], tonumber(tArgs[#tArgs]), settings.handlers.item)
        end
    else
        printError("Command not understood.  See 'help stock'.")
    end
elseif tArgs[1] == "inventory" and tArgs[2] == "varies" then
    -- "stock inventory varies"
    if #chest.list() ~= 0 then
        for i = 1, #chest.list(), 1 do
            setQuantity(chest.getItemDetail(i).name, chest.getItemDetail(i).count, settings.handlers.item)
        end
    else
        printError("Inventory is empty, thus I have nothing to add.")
    end
elseif tArgs[1] == "inventory" then
    -- "stock inventory N"
    if #chest.list() ~= 0 then
        for i = 1, #chest.list(), 1 do
            setQuantity(chest.getItemDetail(i).name, tonumber(tArgs[2]), settings.handlers.item)
        end
    else
        printError("Inventory is empty, thus I have nothing to add.")
    end
elseif tArgs[1] == "fluid" then
    if #tArgs == 1 then
        -- "stock fluid S N"
        print("Stocked fluids:")
        list(settings.handlers.fluid)
    elseif #tArgs == 3 then
        setQuantity(tArgs[2], tonumber(tArgs[3]), settings.handlers.fluid)
    elseif #tArgs > 3 then
        -- "stock fluid S S S... N"
        for i = 2, #tArgs-2, 1 do
            setQuantity(tArgs[i], tonumber(tArgs[#tArgs]), settings.handlers.item)
        end
    else
        printError("Command not understood.  See 'help stock'.")
    end
elseif (tArgs[1] == "remove" or tArgs[1] == "delete") and #tArgs == 2 then
        -- "stock remove N"
    remove(tonumber(tArgs[2]))
elseif (tArgs[1] == "remove" or tArgs[1] == "delete") and #tArgs > 2 then
    -- "stock remove N N N..."
    -- Isolating the numbers from the argument list
    local num = {}
    for i = 2, #tArgs, 1 do
        table.insert(num, tonumber(tArgs[i]))
    end
    --[[ Sorting the numbers in descending fashion.
    This is essential in order* to remove the correct items from a table that
    gets shorter after every loop, meaning the item that was in position 9
    is now in position 8 after removing a number in a lower position.]]--
    --*no pun intended
    table.sort(num, function(a, b) return a > b end)
    for i = 1, #num, 1 do
        remove(tonumber(num[i]))
    end
elseif tArgs[1] == "move" and #tArgs == 3 then
    -- "stock move N N"
    move(tonumber(tArgs[2]), tonumber(tArgs[3]))
elseif tArgs[1] == "start" and #tArgs == 1 then
    startService()
else
    printError("Command not understood.  See 'help stock'.")
end
