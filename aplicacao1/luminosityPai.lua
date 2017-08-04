

MQTT_PORT = 1883
MQTT_HOST = "192.168.0.8"
delay = 10000000 --ms

retry=true

activeRules = { lightsOn= { upperBound= 500 } }


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
	mqttClient:connect(MQTT_HOST,MQTT_PORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('luminosity')
            mqttRegister('control')
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

function messageReceived(topic,data)

	print('MESSAGE RECEIVED!'..topic ..'  ' .. data)
	if(topic == 'luminosity') then
        message = loadstring('return'..data)()
        luminosityValue = message.data
		print('Received luminosity value: '.. message['data'] .. 'from: '..message['source'])

		if(luminosityValue < activeRules['lightsOn'].upperBound) then
			print("Lights On!")
		else
			print("Nothing Happens")
		end

	elseif (topic == 'control') then
		if(data == "quit") then
			mqttPublish('control1','quit')
		end
	end

end

function init()

	configWifi()

	if(ip ~= nil) then
		mqttStart()
	else
		print("Nil IP")
	end

end

init()
