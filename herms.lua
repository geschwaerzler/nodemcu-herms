-- configure gpio
local ledPin=4
gpio.mode(ledPin,gpio.OUTPUT)

-- configure 1-wire
local owPin=3
ow.setup(owPin)

local addrSwitch_hlt = encoder.fromHex("3af80721000000e2")
local addrT_mt = encoder.fromHex("28ee6db6161601c2")
local addrT_coil = encoder.fromHex("28f4f06908000030")
local addrT_hlt = encoder.fromHex("28eea2b916160115")

local hltTimer = tmr.create()

local setValue_hlt = 0.0
local hlt_power = 0

local calibration = {
    [addrT_coil] = {t0 = 1.57; t98_6 = 97.3};
    [addrT_hlt] = {t0 = -0.1; t98_6 = 98.6};
    [addrT_mt] = {t0 = -0.1; t98_6 = 98.6}
}

-- LED control
local function led(state)
    gpio.write(ledPin, state)
end

local function scanOWDevices()
    print("Scanning for 1-wire devices:")
    ow.reset_search(owPin)

    local addr = ow.search(owPin)
    local count = 1

    -- and loop through all devices
    while addr do
        -- search next device
        local crc = ow.crc8(string.sub(addr,1,7))
        if crc == string.byte(addr, 8) then
            print("device "..count..":", encoder.toHex(addr))
        else
            print("invalid CRC in address:", addr, "CRC should be:", crc)
        end
        count = count+1

        addr = ow.search(owPin)
        tmr.wdclr()
    end
end

-- 1-wire dual channel switch ds2413
-- DS2413 datasheet: https://datasheets.maximintegrated.com/en/ds/DS2413.pdf
-- 1-Wire command codes: https://owfs.sourceforge.net/family.html
-- Example C-code: https://codeload.github.com/adafruit/Adafruit_DS2413/zip/master
local function ssr(ssrA, ssrB)
    local value = 2*(ssrB and 0 or 1) + (ssrA and 0 or 1)
    ow.reset(owPin)
    ow.select(owPin, addrSwitch_hlt)  -- select the sensor
    ow.write(owPin, 0x5A)         -- write
    ow.write(owPin, value)        -- bit0 = owPina, bit1 = owPinb
    ow.write(owPin, 255 - value)  -- Invert data and resend
    local ack = ow.read(owPin);   -- 0xAA=success, 0xFF=failure
    if (ack == 0xAA) then
        ow.read(owPin)            -- Read the status byte
    else
        print('ds2413 write failed')
    end
    ow.reset(owPin);
end

local function heater(power)
    if (power < 0 or power > 3) then
        print('power value out of bounds 0 .. 3')
        return
    end
    ow.reset(owPin)
    ow.select(owPin, addrSwitch_hlt)  -- select the ds2413 switch for HLT heater
    ow.write(owPin, 0x5A)         -- write switch states
    ow.write(owPin, 255 - power)  -- bit0 = owPin_a, bit1 = owPin_b, 0=on, 1=off
    ow.write(owPin, power)        -- Invert data and resend
    local ack = ow.read(owPin);   -- 0xAA=success, 0xFF=failure
    if (ack == 0xAA) then
        ow.read(owPin)            -- Read the status byte
        hlt_power = power
    else
        print('ds2413 write failed')
    end
    ow.reset(owPin);
end

local function startTempConversion(addr)
    ow.reset(owPin)
    if addr then                    -- read a specific sensor
        ow.select(owPin, addr)      -- select the sensor
    else                            -- read all sensors
        ow.skip(owPin)              -- 1-Wore skip ROM command, ie read all
    end
    ow.write(owPin, 0x44)           -- issue A/D conversion command
end

local function readTemp(addr)
    -- read out ds18b20
    ow.reset(owPin)
    ow.select(owPin, addr)          -- select the  sensor
    ow.write(owPin, 0xBE)           -- 1-Wire READ_SCRATCHPAD command
    data = ow.read_bytes(owPin, 9)

    local t = data:byte(2)*256 + data:byte(1)
    if (t > 0x7fff) then t = t - 0x10000 end
    t = t / 16                                      -- DS18B20, 4 fractional bits
    local cal = calibration[addr]
    return (t-cal.t0) * 98.6 / (cal.t98_6-cal.t0)   -- calibrated value
 --   return t                                      -- raw temperature value
end

local function hltControll()
    local count=0.0                       -- closure local variable

    return function()
        startTempConversion()    
        led(0)                          -- LED on
        -- after 750ms read out the temperatures
        tmr.create():alarm(750, tmr.ALARM_SINGLE, function()
            local actual_hlt = readTemp(addrT_hlt)
            local actual_coil =  readTemp(addrT_coil)

            -- controll the heating element
            local delta = setValue_hlt - actual_hlt
            if delta > 2.0 then
                heater(3)
            elseif delta > 1.0 then
                heater(2)
            elseif delta > 0.5 then
                heater(1)
            elseif delta > 0.0 then
                if (hlt_power >= 1) then   -- hysterese: we reduce heating, when "commming up"
                    heater(1)
                end
            else
                heater(0)
            end

            print(string.format(
                '%.1f\tset: %.1f°C\tHLT: %.1f°C\tCoil: %.1f°C (%.1f)\tpower: %d\tMT: %.1f°C', 
                count, setValue_hlt, actual_hlt, actual_coil, actual_coil-actual_hlt, hlt_power, readTemp(addrT_mt)
            ))
            count = count + 0.1

            led(1)                      -- LED off
        end)
    end
end

local function setHltTemp(setValue)
    setValue_hlt = setValue
end

local function readAllTemps()
    return {
        hlt = readTemp(addrT_hlt),
        set = setValue_hlt,
        coil = readTemp(addrT_coil),
        mt = readTemp(addrT_mt)
    }
end

led(1)          -- switch off LED
scanOWDevices()
heater(0)       -- switch off HLT heating element
hltTimer:alarm(6000, tmr.ALARM_AUTO, hltControll())

return {
    setHltTemp = setHltTemp,
    readAllTemps = readAllTemps
}
