-- configure gpio
ledPin=4
gpio.mode(ledPin,gpio.OUTPUT)

-- register timers
blinker = tmr.create()
wifiStarter = tmr.create()

-- connect to wifi
wifi.setmode(wifi.STATION)
-- wifi.sta.config{
--     ssid="********",
--     pwd="********"
-- }


function led(state)
    gpio.write(ledPin, state)
end

local function nodeInfo()
    local majorVer, minorVer, devVer, _, _, flashSize = node.info()
    print("\nNodeMCU", majorVer.."."..minorVer.."."..devVer)
    print("Flashsize:", flashSize.." kBytes")
    print("Heapsize:", node.heap().." bytes")
end

local function fsInfo()
    local remaining, used, total = file.fsinfo()
    print("\nFile system info")
    print("Total:\t"..total.." bytes")
    print("Used:\t"..used.." bytes")
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
end

local function fireUpWLAN()
    local _retries = 0
    return function(timer)
        local ip, netmask, gateway = wifi.sta.getip()
        if (ip) then
            print("Network connection:")
            print("IP:\t"..ip)
            print("Netmask:\t"..netmask)
            print("Gateway:\t"..gateway)
            
            -- register http handler
            timer:unregister()

            --signal normal operation
            blinker:interval(2000)
        elseif wifi.getmode() == wifi.STATION then
            if (_retries == 0) then
                print("Connecting to WLAN '"..wifi.sta.getconfig().."' ...")
            elseif (_retries > 9) then
                print("giving up connectiong to WLAN '"..wifi.sta.getconfig().."'")
                wifi.setmode(wifi.SOFTAP)
                print("Setting up default WLAN '"..wifi.ap.getconfig().."'")                
            else
                print("... waiting for connection")
            end
            _retries = _retries+1
        else
            print("still no IP. Giving up finally.")
            timer:unregister()
        end
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

-- wifiStarter:alarm(1000, tmr.ALARM_AUTO, fireUpWLAN())
