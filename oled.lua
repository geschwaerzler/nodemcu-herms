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
--            print('draw loop finished after:', math.floor( (tmr.now()-startTime)/1000 ))
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

function drawPanel(x, y, w, h, title)
    disp:setFont(u8g.font_6x10)
    disp:setDefaultForegroundColor()
    disp:drawFrame(x, y+3, w, h-4)
    drawCenteredStr(x, y+7, w, title)
end

function drawTemp(x, y, title, temp)
    drawPanel(x, y, 31, 28, title)
    local tempStr = string.format('%.1f', temp)
    disp:drawStr(centerStr(x, 31, tempStr), y+20, tempStr)
end

function drawMT(x, y, r, t, dt)
    -- circular scale
    disp:drawCircle(x+r, y, r-2, u8g.DRAW_UPPER_LEFT)
    disp:drawDisc(x+r, y, r-1, u8g.DRAW_UPPER_RIGHT)
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
    local sin = angle - angleBy3 / 6 + angleBy3*angleSqr / 120
    local cos = 1 - angleSqr/2 + angleSqr*angleSqr/24 - angleBy3*angleBy3/720

    local dx, dy = math.floor(sin*r + 0.5), math.floor(cos*r + 0.5)
--    print('needle: ', x+r, y, x+r+dx, y-dy)
    disp:drawLine(x+r, y, x+r+dx, y-dy)

    -- draw temp value
    drawCenteredStr(x, y, 2*r, string.format('%.1f', t))
end

function drawHermsState(hltSet, hltActual, coil)
    return function ()
        drawTemp(0, 0, 'HLT', hltActual)
        drawTemp(0, 28, 'Coil', coil)
        drawTemp(32, 0, 'set', hltSet)
        drawMT(64, 32, 32, 45.32, hltSet/10)
        
        disp:setFont(u8g.font_6x10)
        disp:setDefaultForegroundColor()
        local offset = disp:drawStr(0, 64, 'Mem')
        local totalMem = 50000
        local barHeight = 8
        local barWidth = 128 - offset
        -- draw a box for memory used
        local w = math.floor(collectgarbage('count')*1024*barWidth / totalMem)
        disp:drawBox(offset, 64-barHeight, w, barHeight)
        offset = offset + w
        -- draw a frame for available memory
        w = math.floor(node.heap()*barWidth / totalMem)
        disp:drawFrame(offset, 64-barHeight, w, barHeight)
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
