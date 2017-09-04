local herms = require 'herms'

local restResponseHeader = [[
HTTP/1.1 200 OK
Server: NodeMCU
Content-Type: application/json
Content-Length: %d

]]

local restRepsonseBody = [[
{
	"set": %.1f,
	"hlt": %.1f,
	"coil": %.1f,
	"mt": %.1f,
	"heap": %d,
	"memUsed": %d
}
]]

local response404 = [[
HTTP/1.0 404 Not Found
Content-Length: 0

]]

local function closeSocket(socket)
    socket:close()
end

local function sendHermsResponse(socket)
	local t = herms.readAllTemps()
	local body = string.format(
		restRepsonseBody,
		t.set, t.hlt, t.coil, t.mt, node.heap(), collectgarbage('count')*1024)
	local header = string.format(restResponseHeader, #body)

	print("\nsending response:")
	print(header)
	print(body)
	socket:send(header, function (s) s:send(body, closeSocket) end)
end

-- if a server is running, reset it
if (not httpserver) then
    httpserver = net.createServer(net.TCP)
    print("Server created")
end
if (httpserver:getaddr()) then
    httpserver:close()
    print("Server closed")
end

httpserver:listen(80, function(socket)
	socket:on("receive", function(s0, request)
		print("httpserver got request:")
		print(request)

		if string.find(request, 'PUT /herms', 1, true) then
			local setValue = string.match(request, '\r\n\r\n%s*{.-set"?%s*:%s*([%d%.]+)')
			if setValue then
				herms.setHltTemp(setValue)
			else
				print("PUT didn't get any set value.")
			end
			sendHermsResponse(s0)
		elseif string.find(request, 'GET /herms', 1, true) then
			sendHermsResponse(s0)
		else
			s0:send(response404, closeSocket)
		end
	end)
end)
print("Http server registered")
