-- NodeMCUs pins, that are connected to LEDs
-- local ledPin = {0, 4}
local ledPin = {0}
gpio.mode(ledPin[1], gpio.OUTPUT)
-- gpio.mode(ledPin[2], gpio.OUTPUT)

-- register timers
local timer = {
--    tmr.create(),
    tmr.create()
}

local function ledBlink(pin)
    return function()
        gpio.write(pin,(gpio.read(pin) == gpio.HIGH and gpio.LOW) or gpio.HIGH)
    end
end

local function blink(nr, millis)
    timer[nr]:alarm(millis, tmr.ALARM_AUTO, ledBlink(ledPin[nr]))
end

local function stop(nr)
    timer[nr]:stop()
    gpio.write(ledPin[nr], gpio.HIGH)    
end

local function set(nr, value)
    gpio.write(ledPin[nr], value and gpio.LOW or gpio.HIGH)
end

return {
    set = set;
    blink = blink;
    stop = stop
}