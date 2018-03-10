print("Welcome to GeBräu HERMS-I")

local led = require 'led-module'
led.blink(2, 100)

-- connect to wifi
-- configure WIFIs (up to 5) and save to flash as follows:
-- wifi.sta.config{ssid='your Wifi SSID', pwd='your password', save=true}
wifi.setmode(wifi.STATION)
wifi.sta.setip{
  ip = "192.168.0.6",
  netmask = "255.255.255.0",
  gateway = "192.168.0.1"
}
wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(args)
    print("wifi.eventmon: connected to WiFi: " .. args.SSID, "channel: " .. args.channel)
    led.blink(2, 200)
end)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(args)
    print("wifi.eventmon: got IP: " .. args.IP, "netmask: " .. args.netmask,  "gateway: " .. args.gateway)
    led.blink(2, 3000)
    require 'herms'
    dofile('startHttp.lua')
end)
wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, function()
    print("wifi.eventmon: DHCP has timed out")
    led.stop(2)
end)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(args)
    print("wifi.eventmon: STA - DISCONNECTED SSID: " .. args.SSID, "reason: " .. args.reason)
    led.blink(2, 100)
end)

