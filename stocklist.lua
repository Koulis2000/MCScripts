local component = require("component")

-- Each element of the array is "item", "damage", "number wanted", "max craft size"
-- Damage value should be zero for base items

items = {
    { "tconstruct:ingots",                   0, 64, 16 }, -- Cobalt Ingot
    { "tconstruct:ingots",                   1, 64, 16 }, -- Ardite Ingot
    { "thermalfoundation:material",        128, 64, 16 }, -- Copper Ingot
    { "thermalfoundation:material",        130, 64, 16 }, -- Silver Ingot
}

item = ""
minDelay = 10    -- Seconds between runs if something was crafted
maxDelay = 30   -- Seconds between runs if nothing was crafted