nodeId = node.chipid()
mqttClient = nil
ip = 0
mqttPORT = 1883

ledPort = 1
gpio.mode(ledPort, gpio.OUTPUT)
gpio.write(ledPort, gpio.LOW)

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("sadock","esquilovoador")
	wifi.sta.connect()

	print("Connecting to sadock")
	print("IP is ".. wifi.sta.getip())
    ip = wifi.sta.getip()

end

function mqttStart()
	
	mqttClient = mqtt.Client(nodeId,120)


	mqttClient:on("connect", function(client) print ("connected") end)
	mqttClient:on("offline", function(client) print ("offline") end)

	mqttClient:on("message", function(client, topic, data)
	messageReceived(topic,data)
	end)

	mqttClient:connect("iot.eclipse.org",mqttPORT,0,1, function(con) 
		run()
		end, function(con,reason) print("Couldn't connect to broker: ".. reason) end)

end

function mqttRegister(channel)
	mqttClient:subscribe(channel,0,function(conn)
        print("Successfully subscribed to "..channel)
    end)
end

function mqttPublish(channel,data)

	mqttClient:publish(channel,data,0,0, function(client) print("sent: " .. data .. 'to: ' .. channel) end)

end

function messageReceived(topic,data)
	if(topic == 'luminosity') then
		print('Received luminosity value: '..data)
		if(data > 500 ) then
			print("acender")
			gpio.write(ledPort,gpio.HIGH)
		else if (data < 200) then
			print('STOP')
			mqttPublish('control1','stop')
		else
			print("apagar")
			gpio.write(ledPort,gpio.LOW)
		end
	else
		print('Received unknown message: '..topic)
	end
end

function init()

	configWifi()

	if(ip ~= nil) then
		mqttStart()
	else
		print("Nil IP")
	end

	-- Subscribe to luminosity channel
	mqttRegister('luminosity')


end

init()
