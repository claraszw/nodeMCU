
count=0
ERROR_LED = 1
ip = nil

MQTT_PORT = 1883
MQTT_HOST = "192.168.43.217"

-- Configure Wi-Fi
wifi.setmode(wifi.STATION)
wifi.sta.config("G4_5931","12345678")

while ip == nil do
	if(count>5) then
		print("ERROR_LED ON")
		break
	end
	wifi.sta.connect()
	print("Connecting to G4")
	ip = wifi.sta.getip()
	tmr.delay(5000000)
	count = count+1
end

return ip

