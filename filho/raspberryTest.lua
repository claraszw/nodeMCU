MQTT_PORT = 1883
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
	mqttClient:connect("192.168.0.8",MQTT_PORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('led')
            mqttPublish('luminosity',500)
    		end, function(con,reason) 
    		-- gpio.mode(ledErrorPin, gpio.OUTPUT)
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

	configWifi()

	if(ip ~= nil) then
		mqttStart()
	end

end

function messageReceived(topic,data)
	print('MESSAGE RECEIVED!'..topic ..'  ' .. data)
end

init()
