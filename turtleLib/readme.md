# Turtle lib!

This allows you to input and output items to and from storage using a turtle that has a wireless modem, a pickaxe and an enderchest

## Setup
Download the lib to your turtle using  
```
wget https://raw.githubusercontent.com/samuelWilliams99/cc_storage/main/turtleLib/cc_storage.lua
```

Include it in your script using
```lua
local cc_storage = require "cc_storage"
```

Set up the Storage ID and Ender Chest ID (in that order) with the following
```lua
cc_storage.setStorageId(10) -- Replace 10 with your ID
cc_storage.setEnderChestId(5) -- Replace 5 with your ID
```
_To get storage ID, run `id` on your storage computer, or look in the remote config menu on a pocket computer_  
_To get enderchest ID, connect the enderchest to the network and look at the number after `enderstorage:ender_chest_`_

## Usage
### Inputting (From turtle into the storage computer)

Input a turtles full inventory (except the enderchest) using
```lua
cc_storage.inputChest()
```

We have blacklist and whitelist variants of this
```lua
cc_storage.inputChestByWhitelist({"minecraft:cobblestone", ...})

cc_storage.inputChestByBlacklist({"minecraft:torch", ...})
```
_Note, you do not need to include the enderchest here_

You can lastly input by slot numbers using
```lua
cc_storage.inputChestBySlots({1, 10, 11})
```

### Outputting (From storage computer into turtle)

Get a single item with the following snippet, which will return the _actual_ amount grabbed in case the storage computer does not have enough.
```lua
cc_storage.getItem("minecraft:torch", 10)
```

You can get multiple items using
```lua
cc_storage.getItems{
  ["minecraft:coal"] = 8,
  ["minecraft:sticks"] = 8
}
```
_Note that all this functionality will handle placing the enderchest, removing it, and should input to your currently selected slot._

_IMPORTANT NOTE: Requesting items uses the cc_storage item key, which is defined as `itemName .. itemNBT`. For items that have NBT, like tools, fireworks, etc., raw item name will not work._
