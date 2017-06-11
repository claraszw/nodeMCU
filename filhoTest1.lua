nodeId = node.chipid()
mqttClient = nil
ip = 0
mqttPORT = 1883

delay = 1000000 --ms

send = true

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

function init()

	configWifi()

	if(ip ~= nil) then
		mqttStart()
	else
		print("Nil IP")
	end

	-- Subscribe to control channel
	mqttRegister('control1')
	
	if adc.force_init_mode(adc.INIT_ADC) then
  		node.restart()
  		return -- don't bother continuing, the restart is scheduled
	end

end

function messageReceived(topic,data)
	if(topic == 'control1') then
		print('Received control message')
		if(data == 'stop') then
			print('EXIT LOOP')
			send = false
		end
	else
		print('Received unknown message: '..topic)
	end
end


function run()

	init()

	while send do

		luminosityValue = adc.read(0)

		print('Luminosity: '.. luminosityValue)

		tmr.delay(delay)

		mqttPublish('luminosity',luminosityValue)
	end

	print('DONE')

end

run()


