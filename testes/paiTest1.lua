nodeId = node.chipid()
mqttClient = nil
ip = nil
mqttPORT = 1883

ledPort = 1
gpio.mode(ledPort, gpio.OUTPUT)
gpio.write(ledPort, gpio.LOW)

flag = true

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
	mqttClient:connect("iot.eclipse.org",mqttPORT,0,0, function(con)
            mqttRegister('luminosity')
            mqttRegister('temperature')
    		print('Connected to broker')
            mqttPublish('control1','test')
    		end, function(con,reason) 
    		print("Couldn't connect to broker: ".. reason)
    		handleMqttError() end)
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
    print('BACK')
end

function mqttRegister(channel)
	mqttClient:subscribe(channel,0,function(conn)
        print("Successfully subscribed to "..channel)
    end)
end

function mqttPublish(channel,data)

	mqttClient:publish(channel,data,0,0, function(client) print("sent: " .. data .. ' to: ' .. channel) end)
	print('END PUBLISH')

end

function messageReceived(topic,data)
	print('MESSAGE RECEIVED!'..topic ..'  ' .. data)
	if(topic == 'luminosity') then
        message = loadstring('return'..data)()
		print('Received luminosity value: '.. message['data'] .. 'from: '..message['source'])
		-- if(data > 500 ) then
		-- 	print("acender")
		-- 	gpio.write(ledPort,gpio.HIGH)
		-- elseif (data < 200) then
		-- 	print('STOP')
		-- 	mqttPublish('control1','stop')
		-- else
		-- 	print("apagar")
		-- 	gpio.write(ledPort,gpio.LOW)
		-- end
	elseif (topic == 'temperature') then
		if flag then
			flag = false
			return;
		end
        message = loadstring('return'..data)()
		print('Received temperature value: '.. message['data'] .. 'from: '..message['source'])
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
	--


end

init()
