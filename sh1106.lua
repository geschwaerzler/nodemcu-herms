-- I2C interface to display
local sda = 7 -- SDA Pin
local scl = 6 -- SCL Pin
local sla = 0x3C

-- display functions
local nextDrawFunc = nil            -- next screen to be drawn
local drawQueueEmpty = true

local disp
local function initDisplay(sda, scl, sla) -- Set up the u8glib lib
    i2c.setup(0, sda, scl, i2c.SLOW)
    disp = u8g.sh1106_128x64_i2c(sla)
    disp:setRot180()
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
        if func then
            func(disp)
        else
            print('nothing to display')
        end
        if disp:nextPage() then
            node.task.post(node.task.MEDIUM_PRIORITY, drawPage)
        else
            -- print('draw loop finished after:', math.floor( (tmr.now()-startTime)/1000 ))
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

initDisplay(sda, scl, sla)

return {
    display = display,
    mono = u8g.font_6x10,
    mini = u8g.font_chikita,
    plain = u8g.font_9x18,
    bold = u8g.font_9x18B
}