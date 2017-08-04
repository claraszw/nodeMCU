nodeId = 1
mqttClient = nil
ip = nil
mqttPORT = 1883

delay = 10000000 --ms

send = true

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
	mqttClient:connect("iot.eclipse.org",mqttPORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('control1')
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

end

function mqttRegister(channel)
	mqttClient:subscribe(channel,0,function(conn)
        print("Successfully subscribed to "..channel)
        run()
    end)
end

function mqttPublish(channel,data)
    print('attempt to send data')
	return mqttClient:publish(channel,data,0,0, function(client)
	 print("sent: " .. data .. ' to: ' .. channel)
	  end)

end

function init()

	dht11Pin = 1
	gpio.mode(dht11Pin, gpio.INPUT, gpio.PULLUP)

	configWifi()

	if(ip ~= nil) then
		mqttStart()
	else
		print("Nil IP")
	end

	-- Subscribe to control channel
	
	
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

function getTemperature(pin)

	
	status, temp, humi, temp_dec, humi_dec = dht.read(pin)

	if status == 0 then
		print("DHT Temperature:" .. temp .. " ; Humidity:" .. humi .. "\r\n")
    	return temp
	elseif status == dht.ERROR_CHECKSUM then
    	print( "DHT Checksum error." )
	elseif status == dht.ERROR_TIMEOUT then
    	print( "DHT timed out." )
    end


end

function marshall(t)
    local s = '{'
    for i,v in pairs(t) do
        if     (type(v) == "string") then s = s..i.."='"..v.."'"
        elseif (type(v) == "number") then s = s..i..'='..v
        end

        if i ~= #t then s = s..',' end
    end
    return s..'}'
end


function run()

	if send then

		luminosityValue = adc.read(0)
		temperature = getTemperature(dht11Pin)
		print('Luminosity: '.. luminosityValue)

		messageLight = {}
		messageLight['source'] = nodeId
		messageLight['data'] = luminosityValue

		messageLight = marshall(messageLight)

		messageTemp = {}
		messageTemp['source'] = nodeId
		messageTemp['data'] = 10-- temperature
		messageTemp = marshall(messageTemp)

		-- messageLight = "{source = ".. tostring(nodeId)..",data="..tostring(luminosityValue).."}"
		-- messageTemp = "{source = ".. tostring(nodeId)..",data="..tostring(temperature).."}"

		tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 mqttPublish('luminosity',messageLight)
		 mqttPublish('temperature',messageTemp)
		 run()
		  end)

	end

	print('DONE')

end

init()


