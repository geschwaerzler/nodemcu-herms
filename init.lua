print("Welcome to GeBräu HLT-I")

local led = require 'led-module'
led.blink(1, 100)

sh1106 = require 'sh1106'

-- connect to wifi
-- configure WIFIs (up to 5) and save to flash as follows:
-- wifi.sta.config{ssid='your Wifi SSID', pwd='your password', save=true}
wifi.setmode(wifi.STATION)
-- wifi.sta.setip{
--   ip = "192.168.0.6",
--   netmask = "255.255.255.0",
--   gateway = "192.168.0.1"
-- }
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(args)
    print("wifi.eventmon: connected to WiFi: " .. args.SSID, "channel: " .. args.channel)
    led.blink(1, 200)
end)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(args)
    print("wifi.eventmon: got IP: " .. args.IP, "netmask: " .. args.netmask,  "gateway: " .. args.gateway)
    led.blink(1, 3000)
    herms = require 'herms'
    dofile('startHttp.lua')
end)
wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, function()
    print("wifi.eventmon: DHCP has timed out")
    led.stop(1)
end)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(args)
    print("wifi.eventmon: STA - DISCONNECTED SSID: " .. args.SSID, "reason: " .. args.reason)
    led.blink(1, 100)
end)

sh1106.display(function(disp)
    disp:setFont(sh1106.plain)
    disp:drawStr(0, 12, "Welcome to")
    disp:drawStr(0, 24, "GeBraeu")
    disp:setFont(sh1106.bold)
    disp:drawStr(0, 36, "HLT-I")
end)