
count=0
ERROR_LED = 1
ip = nil

MQTT_PORT = 1883
MQTT_HOST = "192.168.1.6"

-- Configure Wi-Fi
wifi.setmode(wifi.STATION)
wifi.sta.config("sadock","esquilovoador")

while ip == nil do
	if(count>5) then
		print("ERROR_LED ON")
		break
	end
	wifi.sta.connect()
	print("Connecting to sadock")
	ip = wifi.sta.getip()
	tmr.delay(5000000)
	count = count+1
end

return ip

