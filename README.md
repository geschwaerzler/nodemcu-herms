# nodemcu-herms
HERMS brewing controller running on NodeMCU

Installation notes for Mac OS Sierra

* Serial USB driver: https://www.silabs.com/products/development-tools/software/usb-to-uart-bridge-vcp-drivers
* pyserial: sudo easy_install pyserial
* nodemcu_uploader: sudo easy_install nodemcu-uploader

Upload files to NodeMCU
* nodemcu-uploader upload herms.lua

Connect to NodeMCU
* connect with simple VT100 emulaton: screen /dev/cu.SLAB_USBtoUART 115200
* disconnect: ctrl-a, ctrl-\, and "y" for "yes"

When connected to the LUA interpreter:
* restart the system
> node.restart()
* setup a WIFI connection:
> wifi.sta.config{ssid='your Wifi SSID', pwd='your password', save=true}
* list all files
> for k,v in pairs(file.list()) do print(k.."\tsize:"..v) end
* rename a file, e.g. init.lua, which will be executed on startup
> file.rename("init.lua","init_disabled.lua")
> file.rename("init_disabled.lua","init.lua")