local socket = require("socket")

wifi.setmode(wifi.STATION)
wifi.sta.config("piocorreia","wfpcapto41")

while ip == nil do
	wifi.sta.connect()
	print("Connecting to piocorreia")
	ip = wifi.sta.getip()
	tmr.delay(3000000)
end
print("IP is ".. ip)


for i=1, 10 do
	local server = assert(socket.connect("192.168.0.13",35006))
	print "sending hello\n"
	server:send("Hi!\n")
	local message = server:receive()
	print("received: " .. message)
	server:close()
end

local server_connection = assert(socket.connect("192.168.0.13",35006))
server_connection:send("quit\n")
server_connection:close()
