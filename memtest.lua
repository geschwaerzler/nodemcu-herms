function logMem(msg)
    print(msg, 'heap:lua', string.format('%5d:%5d bytes', node.heap(), collectgarbage('count')*1024))
end

function floodMem()
    collectgarbage('stop')
    logMem('stopped')
    
    local i=0
    local memStart = node.heap()
    repeat
        local x = {}
        i = i+1
        if (i % 100 == 0) then logMem(i) end
    until node.heap() < 2000
    logMem(i)
    print('avg mem for x = {}', (memStart-node.heap()) / i, 'bytes')
    collectgarbage('restart')
end

function readSomeFile()
   local fileName = 'cars-porsche.jpg'
   if (file.open(fileName, 'r')) then
      repeat
         local chunk = file.read()
      until chunk == nil
      file.close()
   else
      printf("file '"..fileName.."' does not exist.")
   end
end
