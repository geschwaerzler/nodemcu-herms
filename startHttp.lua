local function response(socket, title, body)
    socket:send("HTTP/1.1 200 OK\n\n")
    socket:send("<!DOCTYPE HTML>\n")
    socket:send("<html>\n")
    socket:send("<head>\n")
    socket:send('\t<meta content="text/html; charset=utf-8"/>\n')
    socket:send('\t<title>')
    socket:send(title)
    socket:send('</title>\n')
    socket:send("<body>\n")
    socket:send(body)
    socket:send("</body>\n")
    socket:send("</html>")
end

local function welcome()
    return [[
        <h1>Welcome to GeBr&auml;u HERMS-I</h1>
        <form action="/" method="post">
            HLT temperature:<br/>
            <input type="number" name="hlt-temp" >&deg;C <br/>
            <input type="submit" value="Set" >
        </form>
]]
end

-- if a server is running, reset it
if (not httpserver) then
    httpserver = net.createServer(net.TCP)
    print("Http server created")
end
if (httpserver:getaddr()) then
    httpserver:close()
    print("Http server closed")
end

httpserver:listen(80, function(socket)
    socket:on("receive", function(s, data)
        print("httpserver got request:")
        print(data)
        response(s, "GeBr&auml;u HERMS-I", welcome())
    end)
    socket:on("sent", function(s) s:close() end)
end)
print("Http server registered")
