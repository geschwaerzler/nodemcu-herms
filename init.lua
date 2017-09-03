-- configure gpio
local ledPin=4
gpio.mode(ledPin,gpio.OUTPUT)

-- register timers
local blinker = tmr.create()

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
end)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(args)
    print("wifi.eventmon: got IP: " .. args.IP, "netmask: " .. args.netmask,  "gateway: " .. args.gateway)
    blinker:interval(2000)
end)
wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, function()
    print("wifi.eventmon: DHCP has timed out")
end)
wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(args)
    print("wifi.eventmon: STA - DISCONNECTED SSID: " .. args.SSID, "reason: " .. args.reason)
end)

local function nodeInfo()
    local majorVer, minorVer, devVer, _, _, flashSize = node.info()
    print("\nNodeMCU", majorVer.."."..minorVer.."."..devVer)
    print("Flashsize:", flashSize.." kBytes")
    print("Heapsize:", node.heap().." bytes")
    print("Mem used:", collectgarbage('count')*1024)
end

local function fsInfo()
    local remaining, used, total = file.fsinfo()
    print("\nFile system info")
    print("Total:\t\t"..total.." bytes")
    print("Used:\t\t"..used.." bytes")
    print("Remaining:\t"..remaining.." bytes")

    print("\nFile list:")
    for name,size in pairs(file.list()) do
        print(name.."\t"..size.." bytes")
    end
end

local function netInfo()
    print("\nNetwork info")
    local m = wifi.getmode()
    print("Mode:\t"..
        (m == wifi.STATION and "STATION" or
        m == wifi.SOFTAP and "SOFTAP" or
        m == wifi.STATIONAP and "STATIONAP" or
        m == wifi.NULLMODE and "NULLMODE" or
        m)
    )
    print("MAC:\t"..wifi.sta.getmac())

    local x=wifi.sta.getapinfo()
    local y=wifi.sta.getapindex()
    print("\nAPs stored in flash:", x.qty)
    print(string.format("  %-2s %-16s %-32s %-18s", "", "SSID:", "Password:", "BSSID:")) 
    for i=1, (x.qty), 1 do
        print(string.format(" %s%-2d %-16s %-32s %-18s",(i==y and ">" or " "), i, x[i].ssid, x[i].pwd and x[i].pwd or type(nil), x[i].bssid and x[i].bssid or type(nil)))
    end

end

local function ledBlink()
    local _lighton=true
    return function()
        gpio.write(ledPin,(_lighton and gpio.LOW) or gpio.HIGH)
        _lighton= not _lighton
    end
end

blinker:alarm(500, tmr.ALARM_AUTO, ledBlink())

print("Welcome to GeBräu HERMS-I")
nodeInfo()
fsInfo()
netInfo()