local herms = require 'herms'

local responseHeader_HTTP_SERVER =
	"HTTP/1.1 200 OK\r\n"..
	"Server: NodeMCU\r\n"..
	"Access-Control-Allow-Origin: *\r\n"

local putGetResponseHeader = 
	responseHeader_HTTP_SERVER..
	"Content-Type: application/json\r\n"..
	"Content-Length: %d\r\n\r\n"

local putGetRepsonseBody = [[
{
	"set": %.1f,
	"hlt": %.1f,
	"coil": %.1f,
	"mt": %.1f,
	"heap": %d,
	"memUsed": %d
}]].."\r\n"

local optionsResponse =
	responseHeader_HTTP_SERVER..
	"Access-Control-Allow-Methods: GET, PUT, OPTIONS\r\n"..
	"Access-Control-Allow-Headers: Content-Type\r\n"..
	"Content-Length: 0\r\n\r\n"

local response404 =
	"HTTP/1.0 404 Not Found\r\n"..
	"Content-Length: 0\r\n\r\n"

local function closeSocket(socket)
    socket:close()
end

local function sendHermsResponse(socket)
	local t = herms.readAllTemps()
	local body = string.format(
		putGetRepsonseBody,
		t.set, t.hlt, t.coil, t.mt, node.heap(), collectgarbage('count')*1024)
	local header = string.format(putGetResponseHeader, #body)
--	socket:send(header, function (s) s:send(body, closeSocket) end)
	socket:send(header..body, closeSocket)
end

local function handleRequest(socket, request)
	print("httpserver", string.match(request, '(.-)\r\n'))
	-- print(request)

	if string.find(request, 'PUT /herms', 1, true) then
		local setValue = string.match(request, '\r\n\r\n%s*{.-set"?%s*:%s*([%d%.]+)')
		if setValue then
			herms.setHltTemp(setValue)
		else
			print("PUT didn't get any set value.")
		end
		sendHermsResponse(socket)
	elseif string.find(request, 'GET /herms', 1, true) then
		sendHermsResponse(socket)
	elseif string.find(request, 'OPTIONS /herms', 1, true) then
		socket:send(optionsResponse, closeSocket)
	else
		print('unsupported request:')
		print(string.match(request, '(.-)\r\n'))
		socket:send(response404, closeSocket)
	end
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

local requestBuffer = nil
local contentLength = 0
local requestLength = 0

httpserver:listen(80, function(socket)
	socket:on("receive", function(s0, payload)
		-- print("httpserver received:")
		-- print(payload)
		if not requestBuffer then
			requestBuffer = payload
		else
			requestBuffer = requestBuffer .. payload
		end

		if contentLength == 0 then
			local length = string.match(requestBuffer, '\r\nContent%-Length:%s*(%d+)')
			if length then
				contentLength = length
				-- print("contentLength:", contentLength)
			end
		end

		if requestLength == 0 then
			local bodyStart = string.find(requestBuffer, '\r\n\r\n', 1, true)
			if bodyStart then
				requestLength = contentLength + bodyStart + 3
				-- print("requestLength:", requestLength)
			end
		end

		if #requestBuffer == requestLength then
			local request = requestBuffer
			requestBuffer = nil
			contentLength = 0
			requestLength = 0

			handleRequest(s0, request)
		end
	end)
end)
print("Http server registered")
