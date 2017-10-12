local MQTT = {}

function MQTT.mqttStart()

	mqttClient:on("connect", function(client) print ("connected") end)
	mqttClient:on("offline", function(client) print ("offline") end)

	mqttClient:on("message", function(client, topic, data)
	messageReceived(topic,data)
	end)

    mqttConnect()
end

function MQTT.mqttRegister(mqttClient,channel)
    print("attempt to register")
	mqttClient:subscribe(channel,0,function(conn)
        print("Successfully subscribed to "..channel)
    end)
end

function MQTT.mqttPublish(channel,data)
    print("attempt to publish")
	mqttClient:publish(channel,data,0,0, function(client) print("sent: " .. data .. ' to: ' .. channel) end)
end

function handleMqttError()
	gpio.write(ERROR_LED,gpio.HIGH)
	tmr.create():alarm(10*1000, tmr.ALARM_SINGLE, mqttConnect)
end

function MQTT.mqttConnect()
	print('Attempt to connect')
	mqttClient:connect(MQTT_HOST,MQTT_PORT,0,0, mqttConnected(con), function(con,reason) 
    		-- gpio.mode(ledErrorPin, gpio.OUTPUT)
    		print("Couldn't connect to broker: ".. reason)
    		handleMqttError() end)

end

return MQTT
