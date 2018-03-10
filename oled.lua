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
    -- Draws one page and schedules the next page, if there is one
    local function drawPage()
        func()
        if disp:nextPage() then
            node.task.post(drawPage, node.task.MEDIUM_PRIORITY)
        else
            if nextDrawFunc then
                func = nextDrawFunc
                nextDrawFunc = nil
                disp:firstPage()
                node.task.post(drawPage, node.task.MEDIUM_PRIORITY)
            else
                drawQueueEmpty = true
            end
        end
    end

    -- Start the draw loop and start drawing pages
    if (drawQueueEmpty) then -- draw screen immediately
        drawQueueEmpty = false
        disp:firstPage()
        node.task.post(drawPage, node.task.MEDIUM_PRIORITY)
    else
        nextDrawFunc = func
    end
end

function drawPanel(x, y, w, h, title)
    disp:setFont(u8g.font_6x10)
    disp:setDefaultForegroundColor()
    disp:drawFrame(x, y+3, w, h-4)
    local titleW = disp:getStrWidth(title)
    local titleX = math.floor(x+ (w-titleW)/2)
    disp:setDefaultBackgroundColor()
    disp:drawBox(titleX-1, y, titleW+2, 8)
    disp:setDefaultForegroundColor()
    disp:drawStr(titleX, y+7, title)
end

function drawTemp(x, y, title, temp)
    drawPanel(x, y, 31, 28, title)
    local tempStr = string.format('%.1f', temp)
    local tempW = disp:getStrWidth(tempStr)    
    disp:drawStr(math.floor(x+(32-tempW)/2), y+20, tempStr)
end

function drawHermsState(hltSet, hltActual, coil)
    return function ()
        drawTemp(0, 0, 'HLT', hltActual)
        drawTemp(0, 28, 'Coil', coil)
        drawTemp(32, 0, 'set', hltSet)
        
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
