

NODE_ID = 1
MQTT_PORT = 1883
MQTT_HOST = "192.168.1.11"
delay = 10000000 --ms

send = true
retry = true 

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("sadock","esquilovoador")

	while ip == nil do
		wifi.sta.connect()
		print("Connecting to sadock")
    	ip = wifi.sta.getip()
    	tmr.delay(3000000)
    end
	print("IP is ".. ip)
end

function mqttConnect()
	print('Attempt to connect')
	mqttClient:connect(MQTT_HOST,MQTT_PORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('control1')
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
        collectData()
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

	configWifi()

	if(ip ~= nil) then
		mqttStart()
	else
		print("Nil IP")
	end

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
        end

        if i ~= #t then s = s..',' end
    end
    return s..'}'
end

function collectData()
	
	if send then

		luminosityValue = adc.read(0)
		print('Luminosity: '.. luminosityValue)

		messageLight = {}
		messageLight['source'] = NODE_ID
		messageLight['data'] = luminosityValue

		messageLight = marshall(messageLight)

		tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 mqttPublish('luminosity',messageLight)
		 collectData()
		  end)

	end

	print('DONE')
end

function messageReceived(topic,data)

	print('MESSAGE RECEIVED!'..topic ..'  ' .. data)
	if(topic == 'control1') then
		if data == "quit" then
			send = false
		end
	end
end

init()