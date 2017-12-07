

NODE_ID = 2
delay = 5000000 --ms

send = true
retry = true 

DHT11_PIN = 1

-- PRESENCE_PIN = 2
-- DOOR_PIN = 3

gpio.mode(DHT11_PIN, gpio.INPUT,gpio.PULLUP)

-- gpio.mode(PRESENCE_PIN,gpio.INPUT)


function mqttConnect()
	print('Attempt to connect')
	mqttClient:connect(MQTT_HOST,MQTT_PORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('control1')
            mqttRegister('request')
            collectData()
    		end, function(con,reason) 
    		-- gpio.mode(ledErrorPin, gpio.OUTPUT)
    		print("Couldn't connect to broker: ".. reason)
    		handleMqttError() end)

	if(retry) then 
		tmr.create():alarm(10*1000, tmr.ALARM_SINGLE, mqttConnect)
		retry = false
	end

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
	
	mqttClient = mqtt.Client(NODE_ID,120)


	mqttClient:on("connect", function(client) print ("connected") end)
	mqttClient:on("offline", function(client) print ("offline") end)

	mqttClient:on("message", function(client, topic, data)
	messageReceived(topic,data)
	end)

    mqttConnect()
end

function init()

	mqttStart()

	if adc.force_init_mode(adc.INIT_ADC) then
  		node.restart()
  		return -- don't bother continuing, the restart is scheduled
	end

end

function marshall(t)
    local s = '{'
    for i,v in pairs(t) do
        if     (type(v) == "string") then s = s..i.."='"..v.."'"
        elseif (type(v) == "number") then s = s..i..'='..v
        elseif (type(v) == "boolean") then s = s .. i ..'='.. tostring(v)
        elseif(type(v) == "table") then s = s..i..'='..marshall(v)
        end

        if i ~= #t then s = s..',' end
    end
    return s..'}'
end

function getTemperature(pin)

	
	status, temp, humi, temp_dec, humi_dec = dht.read(pin)

	if status == 0 then
		print("DHT Temperature:" .. temp .. " ; Humidity:" .. humi .. "\r\n")
    	return temp
	elseif status == dht.ERROR_CHECKSUM then
		-- gpio.write(ledErrorPin,gpio.HIGH)
    	print( "DHT Checksum error." )
    	return "error"
	elseif status == dht.ERROR_TIMEOUT then
		-- gpio.write(ledErrorPin,gpio.HIGH)
    	print( "DHT timed out." )
    	return "error"
    end


end

function collectData()
	
	if send then

		luminosityValue = adc.read(0)
		temperatureValue = getTemperature(DHT11_PIN)
		-- doorValue = gpio.read(DOOR_PIN)

		-- print('Door: ' .. doorValue)

		-- if(doorValue == gpio.HIGH) then
		-- 	doorValue = "closed"
		-- else
		-- 	doorValue = "open"
		-- end

		print('Luminosity: '.. luminosityValue)

		message = { source = NODE_ID, info = {luminosity = luminosityValue, temperature = temperatureValue} } --door = doorValue
		message = marshall(message)

		tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE,sendData)

	end

end

function sendData( ... )
	mqttPublish('sensorInfo',message)
	collectData()
end

function messageReceived(topic,data)

	print('MESSAGE RECEIVED!'..topic ..'  ' .. data)
	if(topic == 'control1') then
		if data == "quit" then
			send = false
		end
	end

	if(topic == 'request') then
		mqttPublish('sensorInfo',message)
	end
end

init()
