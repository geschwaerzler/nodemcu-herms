-- I2C interface to display
local sda = 7 -- SDA Pin
local scl = 6 -- SCL Pin
local sla = 0x3C

-- rotary push button interface
local rotA = 5
local rotB = 6
local rotPress = 7
local rotChannel = 0

-- HERMS state
local hltSet = 0
local hltActual = 22.3
local coil = 24.5

-- compiled fonts
local helvetica8 = u8g.font_helvR08r
local helvetica10 = u8g.font_helvR10r
local helvetica10b = u8g.font_helvB10r
local helvetica12b = u8g.font_helvB12r
local helvetica14b = u8g.font_helvB14r
local newcentury8 = u8g.font_ncenR08r
local newcentury10 = u8g.font_ncenR10r
local newcentury10b = u8g.font_ncenB10r
local newcentury12b = u8g.font_ncenB12r
local newcentury14b = u8g.font_ncenB14r

-- display functions
local nextDrawFunc = nil            -- next screen to be drawn
local drawQueueEmpty = true

local function initDisplay(sda, scl, sla) -- Set up the u8glib lib
    i2c.setup(0, sda, scl, i2c.SLOW)
    disp = u8g.sh1106_128x64_i2c(sla)
end

local function display(func)
    local startTime
    local drawPage

    local function startDrawLoop()
        startTime = tmr.now()
        disp:firstPage()
        node.task.post(node.task.MEDIUM_PRIORITY, drawPage)
    end

    -- Draws one page and schedules the next page, if there is one
    drawPage = function ()
        func()
        if disp:nextPage() then
            node.task.post(node.task.MEDIUM_PRIORITY, drawPage)
        else
            print('draw loop finished after:', math.floor( (tmr.now()-startTime)/1000 ))
            if nextDrawFunc then
                func = nextDrawFunc
                nextDrawFunc = nil
                node.task.post(node.task.LOW_PRIORITY, startDrawLoop)
            else
                drawQueueEmpty = true
            end
        end
    end

    -- Start the draw loop and start drawing pages
    if (drawQueueEmpty) then -- draw screen immediately
        drawQueueEmpty = false
        node.task.post(node.task.LOW_PRIORITY, startDrawLoop)
    else
        nextDrawFunc = func
    end
end

local function centerStr(x, w, str)
    local strW = disp:getStrWidth(str)
    return math.floor(x + (w-strW)/2), strW
end

local function drawCenteredStr(x, y, w, str)
    x, w = centerStr(x, w, str)
    disp:drawStr(x, y, str)
end

local function drawCenteredIStr(x, y, w, str)
    local h = disp:getFontAscent()-1
    disp:drawBox(x, y-h-2, w, h+2)
    x = centerStr(x, w, str)
    disp:setDefaultBackgroundColor()
    disp:drawStr(x, y-1, str)
    disp:setDefaultForegroundColor()
end

local function drawMTScale(dt)
    for y = -18,36,2 do
        if y == 0 then
            disp:drawHLine(92, 44, 5)
        elseif math.floor(y/20) == y/20 then
            disp:drawHLine(92, 44 - y, 4)
        elseif math.floor(y/10) == y/10 then
            disp:drawHLine(93, 44 - y, 2)
        else
            disp:drawPixel(93, 44 - y)
        end
    end
    dt = math.floor(dt / 0.05 + 0.5)
    if dt > 0 then
        disp:drawBox(90, 44-dt, 2, dt+1)
    elseif dt < 0 then
        disp:drawBox(90, 44, 2, 1-dt)
    else
        disp:drawHLine(88,44,4)
    end
end

local function drawSmallScale(x, y, dt)
    disp:drawHLine(x, y, 2)
    for dy = 2, 24, 2 do
        if math.floor(dy/10) == dy/10 then
            disp:drawHLine(x, y - dy, 2)
        else
            disp:drawPixel(x+1, y - dy)
        end
    end
    dt = math.floor(dt / 0.10 + 0.5)
    if dt > 0 then
        disp:drawVLine(x+2, y-dt+1, dt)
    elseif dt == 0 then
        disp:drawHLine(x+2,y,2)
    end
end

local function drawCenteredTemp(x, y, w, temp, fontInt, fontFract)
    local intStr = string.format('%d', temp)
    local fract = math.abs(temp)
    fract = fract - math.floor(fract)
    local fractStr = string.format('.%d', fract*10)
    disp:setFont(fontInt)
    local strW = disp:getStrWidth(intStr)
    disp:setFont(fontFract)
    strW = strW + disp:getStrWidth(fractStr)
    x = math.floor(x + (w-strW)/2)
    disp:setFont(fontInt)
    x = x + disp:drawStr(x, y, intStr)    
    disp:setFont(fontFract)
    disp:drawStr(x, y, fractStr)
end

local function drawMem(x, y, used, free)
    local blockW = 16
    local blockCount = 128 / blockW

    disp:setFont(u8g.font_chikita)
    local total = math.ceil((used+free) / 1024 / blockCount) * blockCount * 1024
    local h = disp:getFontAscent()
    disp:drawFrame(x, y-h, 128, h)
    for tick = blockW,128-blockW,blockW do
        disp:drawVLine(tick, y-h, h)
    end
    local usedW = math.floor( (total-free)/total*128 + 0.5 )
    disp:drawBox(x, y-h, usedW, h)
    disp:setDefaultBackgroundColor()
    for tick = blockW,usedW,blockW do
        disp:drawVLine(tick, y-h+1, h-2)
    end
    local blockStr = string.format('%01dK', total/1024/blockCount)
    disp:drawStr(centerStr(x,blockW,blockStr), y, blockStr)
    disp:setDefaultForegroundColor()
end

local function drawHerms(state)
    local memUsed = collectgarbage('count')*1024
    local memFree = node.heap()
    return function ()
        -- dividers
        disp:drawHLine(0,35,31)
        disp:drawHLine(97,26,31)
        disp:drawHLine(97,45,31)
        
        -- labels
        disp:setFont(u8g.font_chikita)
        drawCenteredStr(0, 34, 30, 'HLT')
        drawCenteredStr(0, 42, 30, 'HX')
        drawCenteredStr(98, 25, 30, 'heater')
        drawCenteredStr(98, 52, 30, 'display')
        drawCenteredStr(32, 14, 64, 'MT')

        -- values
        drawCenteredTemp(0, 27, 28, state.hlt, newcentury10b, newcentury8)
        drawCenteredTemp(0, 56, 28, state.coil, newcentury10b, newcentury8)
        drawCenteredTemp(32, 42, 64, state.mt, newcentury14b, newcentury10b)

        -- values inverse
        disp:setFont(u8g.font_chikita)        
        drawCenteredIStr(0, 14, 28, string.format('%.1f', state.hltSet))
        drawCenteredIStr(0, 64, 28, '20 l/m')

        -- scales
        drawMTScale(hltSet / 10)
        drawSmallScale(28, 33, 1.1)
        drawSmallScale(28, 63, 0)
    end
end

initDisplay(sda, scl, sla)

rotary.setup(rotChannel, rotA, rotB, rotPress)
-- rotary.on(rotChannel, rotary.ALL, onAll)
rotary.on(rotChannel, rotary.TURN, function (type, pos, time)
    hltSet = pos / 8
    display(drawHerms({hltSet = hltSet, hlt = hltActual, coil = coil, mt = 62.4}))
end)
rotary.on(rotChannel, rotary.PRESS, function (type, pos, time)
    hltSet = pos / 8
    hltActual = hltSet
    display(drawHerms({hltSet = hltSet, hlt = hltActual, coil = coil, mt = 62.4}))
end)

display(drawHerms({hltSet = hltSet, hlt = hltActual, coil = coil, mt = 62.4}))

local oledTimer = tmr.create()
oledTimer:alarm(2000, tmr.ALARM_AUTO, function ()
    display(drawHermsState)
end)
