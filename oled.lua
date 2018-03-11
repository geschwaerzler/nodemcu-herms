-- I2C interface to display
local sda = 1 -- SDA Pin
local scl = 2 -- SCL Pin
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

function initDisplay(sda, scl, sla) -- Set up the u8glib lib
    i2c.setup(0, sda, scl, i2c.SLOW)
    disp = u8g.sh1106_128x64_i2c(sla)
end

function display(func)
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

function centerStr(x, w, str)
    local strW = disp:getStrWidth(str)
    return math.floor(x + (w-strW)/2), strW
end

function drawCenteredStr(x, y, w, str)
    x, w = centerStr(x, w, str)
    local h = disp:getFontAscent()
    disp:setDefaultBackgroundColor()
    disp:drawBox(x-1, y-h-1, w+2, h+2)
    disp:setDefaultForegroundColor()
    disp:drawStr(x, y, str)
end

function drawCenteredTemp(x, y, w, temp, fontInt, fontFract)
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

function drawPanel(x, y, w, h, title, font)
    disp:setFont(u8g.font_chikita)
    local ascent = disp:getFontAscent()
    local mid = math.floor(ascent/2)
    disp:drawFrame(x, y+mid, w, h-mid)
    drawCenteredStr(x, y+ascent, w, title)
    return (ascent + h) / 2 -- returns dy of the middle
end

function drawTemp(x, y, title, temp)
    local dy = drawPanel(x, y, 31, 31, title, u8g.font_chikita)
    dy = math.ceil(dy + disp:getFontAscent()/2)
    drawCenteredTemp(x, y+dy, 31, temp, newcentury10b, newcentury8)
end

function drawMT(x, y, r, t, dt)
    -- circular scale
    disp:drawCircle(x+r, y, r-2, u8g.DRAW_UPPER_LEFT)
    disp:drawDisc(x+r, y, r-2, u8g.DRAW_UPPER_RIGHT)
    disp:setDefaultBackgroundColor()
    disp:drawDisc(x+r, y, r-4, u8g.DRAW_UPPER_RIGHT)
    disp:setDefaultForegroundColor()

    -- scale ticks
    dx45 = math.floor(r / 1.4142 + 0.5)   -- x an y of a 45 degree triangle
    disp:drawHLine(x, y, 5)
    disp:drawHLine(x+2*r-4, y, 5)
    disp:drawVLine(x+r, y-r, 5)
    disp:drawLine(x+r-dx45+4, y-dx45+4, x+r-dx45, y-dx45)
    disp:drawLine(x+r+dx45-4, y-dx45+4, x+r+dx45, y-dx45)

    -- draw dt needle
    if dt < -2.0 then
        dt = - 2.0
    elseif dt > 2.0 then
        dt = 2.0
    end
    local angle = math.pi * dt / 4
    local angleSqr = angle * angle
    local angleBy3 = angleSqr*angle
    local angleBy4 = angleSqr*angleSqr
    local sin = angle - angleBy3/6 + angleBy3*angleSqr/120 - angleBy4*angleBy3/5040
    local cos = 1 - angleSqr/2 + angleBy4/24 - angleBy3*angleBy3/720
    
    local dx, dy = math.floor(sin*r + 0.5), math.floor(cos*r + 0.5)
    disp:drawLine(x+r, y, x+r+dx, y-dy)
    disp:setDefaultBackgroundColor()
    disp:drawDisc(x+r, y, r-12, u8g.DRAW_UPPER_LEFT)
    disp:drawDisc(x+r, y, r-12, u8g.DRAW_UPPER_RIGHT)
    disp:setDefaultForegroundColor()

    -- draw temp value
    drawCenteredTemp(x, y, 2*r, t, newcentury14b, newcentury10)
end

function drawMem(x, y, used, free)
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

function drawHermsState(hltSet, hltActual, coil)
    local memUsed = collectgarbage('count')*1024
    local memFree = node.heap()
    return function ()
        drawTemp(0, 0, 'HLT', hltActual)
        drawTemp(96, 0, 'Coil', coil)
--        drawTemp(32, 0, 'set', hltSet)
        drawMT(24, 54, 40, 45.32, hltSet/10)
        drawMem(0, 64, memUsed, memFree)
    end
end

initDisplay(sda, scl, sla)

rotary.setup(rotChannel, rotA, rotB, rotPress)
-- rotary.on(rotChannel, rotary.ALL, onAll)
rotary.on(rotChannel, rotary.TURN, function (type, pos, time)
    hltSet = pos / 8
    display(drawHermsState(hltSet, hltActual, coil))
end)
rotary.on(rotChannel, rotary.PRESS, function (type, pos, time)
    hltSet = pos / 8
    hltActual = hltSet
    display(drawHermsState(hltSet, hltActual, coil))
end)

display(drawHermsState(hltSet, hltActual, coil))

-- local oledTimer = tmr.create()
-- oledTimer:alarm(2000, tmr.ALARM_AUTO, function ()
--     display(drawHermsState)
-- end)
