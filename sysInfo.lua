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

nodeInfo()
fsInfo()
netInfo()