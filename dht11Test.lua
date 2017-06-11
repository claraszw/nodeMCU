nodeId = node.chipid()
m = nil
ip = 0
-- mqttPORT = 1883

-- led1 = 3
-- gpio.mode(led1, gpio.OUTPUT)

dht11Pin = 3
gpio.mode(dht11Pin, gpio.INPUT, gpio.PULLUP)

buttonPin = 4
gpio.mode(buttonPin, gpio.INPUT, gpio.PULLUP)
gpio.trig(buttonPin, "both", function(level)
print("Button level!",level)
end)

-- gpio.write(led1, gpio.LOW)

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("piocorreia","wfpcapto41")
	wifi.sta.connect()

	print("Connecting to piocorreia")
	--print("IP is ".. wifi.sta.getip())
    --ip = wifi.sta.getip()

end

function printTemperature(pin)

	
	status, temp, humi, temp_dec, humi_dec = dht.read(pin)

	if status == "dht.OK" then
		print("DHT Temperature:" .. temp .. " ; Humidity:" .. humi .. "\r\n")
	elseif status == dht.ERROR_CHECKSUM then
    	print( "DHT Checksum error." )
	elseif status == dht.ERROR_TIMEOUT then
    	print( "DHT timed out." )
    end

end


configWifi()

count = 0

while count < 10 do
	printTemperature(dht11Pin)
	count=count+1
end
