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
* disconnect: ctrl-a, ctrl-/, and "y" for "yes"
