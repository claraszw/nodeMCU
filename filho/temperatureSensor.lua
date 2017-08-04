nodeId = node.chipid()
ip = nil

MQTT_PORT = 1050
delay = 10000000 --ms

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("piocorreia","wfpcapto41")

	while ip == nil do
		wifi.sta.connect()
		print("Connecting to piocorreia")
    	ip = wifi.sta.getip()
    	tmr.delay(3000000)
    end
	print("IP is ".. ip)
end

function mqttConnect()
	print('Attempt to connect')
	mqttClient:connect("localhost",MQTT_PORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('temperature')
            readSensor()
    		end, function(con,reason) 
    		gpio.mode(ledErrorPin, gpio.OUTPUT)
    		print("Couldn't connect to broker: ".. reason)
    		handleMqttError() end)
end

function mqttRegister(channel)
	mqttClient:subscribe(channel,0,function(conn)
        print("Successfully subscribed to "..channel)
    end)
end

function mqttPublish(channel,data)

	mqttClient:publish(channel,data,0,0, function(client) print("sent: " .. data .. ' to: ' .. channel) end)

end

function handleMqttError()
	tmr.create():alarm(10*1000, tmr.ALARM_SINGLE, mqttConnect)
end

function mqttStart()
	
	mqttClient = mqtt.Client(nodeId,120)


	mqttClient:on("connect", function(client) print ("connected") end)
	mqttClient:on("offline", function(client) print ("offline") end)

	mqttClient:on("message", function(client, topic, data)
	messageReceived(topic,data)
	end)

    mqttConnect()
end

function init()

	dht11Pin = 1
	gpio.mode(dht11Pin, gpio.INPUT,gpio.PULLUP)

	ledErrorPin = 2
	gpio.mode(ledErrorPin, gpio.OUTPUT)

	count = 0

	configWifi()

	if(ip ~= nil) then
		mqttStart()
	else
		gpio.write(ledErrorPin,gpio.HIGH)
	end

end

function getTemperature(pin)

	
	status, temp, humi, temp_dec, humi_dec = dht.read(pin)

	print(status)

	if status == 0 then
		print("DHT Temperature:" .. temp .. " ; Humidity:" .. humi .. "\r\n")
    	return temp
	elseif status == dht.ERROR_CHECKSUM then
		gpio.write(ledErrorPin,gpio.HIGH)
    	print( "DHT Checksum error." )
	elseif status == dht.ERROR_TIMEOUT then
		gpio.write(ledErrorPin,gpio.HIGH)
    	print( "DHT timed out." )
    end


end

function readSensor()

	count = count +1
	temp = getTemperature(dht11Pin)


	-- tmr.delay(3000000)
	if(count < 10) then
		tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 mqttPublish('temperature',temp)
		 readSensor()
		  end)
	end
end

function messageReceived(topic,data)
	print('MESSAGE RECEIVED!'..topic ..'  ' .. data)
	if(topic == 'temperature') then
		print('Received temperature value: '.. data)
	else
		print('Received unknown message: '..topic)
	end
end

init()