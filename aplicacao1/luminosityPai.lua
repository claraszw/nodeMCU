
MQTT_PORT = 1883
MQTT_HOST = "192.168.1.6"
delay = 15000000 --ms

CONNECTED_LED = 1
ERROR_LED = 2

gpio.mode(CONNECTED_LED,gpio.OUTPUT)
gpio.mode(ERROR_LED,gpio.OUTPUT)

retry=true

sensorValues = {{},{}}
luminosityValue = 0
temperatureValue = 0
lights = false
airConditioning = false

rules = {lightsOn = {}, controlTemperature = {}}
gpio.write(ERROR_LED,gpio.HIGH)

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("sadock","esquilovoador")

	while ip == nil do
		wifi.sta.connect()
		print("Connecting to sadock")
    	ip = wifi.sta.getip()
    	tmr.delay(5000000)
    end
	print("IP is ".. ip)
end

function mqttConnect()
	print('Attempt to connect')
	mqttClient:connect(MQTT_HOST,MQTT_PORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('sensorInfo')
            mqttRegister('newRule')
            mqttRegister('delete')
            mqttPublish('configInit','sala516')
            mqttPublish('request','sensorInfo')
            gpio.write(CONNECTED_LED,gpio.HIGH)
            gpio.write(ERROR_LED,gpio.LOW)
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
	gpio.write(ERROR_LED,gpio.HIGH)
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

	if(topic == 'sensorInfo') then
    	message = loadstring('return'..data)()

        sensorValues[message.source] = message.info -- change to message
        luminosityValue = sensorValues[message.source].luminosity
        temperatureValue = sensorValues[message.source].temperature
	-- print('Received luminosity value: '.. message['data'] .. 'from: '..message['source'])

		mqttPublish('luminosityUpdt',sensorValues[message.source]["luminosity"])
		mqttPublish('temperatureUpdt',sensorValues[message.source]["temperature"])


	elseif (topic == 'newRule') then
        print(message)
    	message = loadstring('return'..data)()
        table.insert(rules[message["type"]],message["parameters"])

	elseif (topic == 'delete') then
		if(data == 'all') then
			for key,value in pairs(rules) do
				rules[key]={}
			end
		else

			for index,rule in pairs(rules[message["type"]]) do
				if(next(rule) == nil and next(message["parameters"]) == nil) then
					table.remove(rules[message["type"]],index)
					break
				end
				if(rule[message["parameters"][1]] ~= nil) then
					table.remove(rules[message["type"]],index)	
					break
				end
			end

		end

	end

	checkLights()
	checkTemperature()

end

function checkLights()

	act = checkParameters("lightsOn")

	if(act) then
		applyRule("lightsOn")
	else
		applyRule("lightsOff")
	end

end

function checkTemperature()
	-- Right now assuming that only one rule to control temperature will be active, if there were more it would be necessary to considerate which one
	-- in order to get the correct temperature value to check

	act = checkParameters("controlTemperature")
	rule = rules["controlTemperature"][1]

	if(act) then
		if(temperatureValue < (rule["temperature"] - 2)) then
			applyRule("airOn")
		elseif(temperatureValue > (rule["temperature"]) + 2) then
			applyRule("airOn")
		else
			applyRule("airOff")
		end
	else
		applyRule("airOff")
	end

end

function checkAlarm( ... )
	-- body
end

function checkParameters(ruleType)

	act = false

	for index,rule in pairs(rules[ruleType]) do
		actRule = true
		for parameter,value in pairs(rule) do
		  if(not checkParameter(parameter,value)) then
		  	actRule = false
		  	break
		  end
		end
		if(actRule) then
			act = true
			break
		end
	end

	return act
end

function checkParameter(parameterType,value) -- change to table

	if(parameterType == "upperBoundLight") then
		if (luminosityValue ~= nil and luminosityValue > value) then
			return true
		end
	elseif(parameterType == "lowerBoundLight") then
		if (luminosityValue ~= nil and luminosityValue < value) then
        -- print("value is smaller")
			return true
		end
	elseif(parameterType == "temperature") then
		return true
	end

	return false

end

function applyRule(rule)

print("Applying rule: "..rule)

	if(rule == "lightsOn") then
		print("Acender Luzes!")
		if(not lights) then
			lights = true
			mqttPublish('lightsUpdt','on')
		end
	elseif (rule == "lightsOff") then
		print("Apagar Luzes!")
		if(lights) then
			lights = false
			mqttPublish('lightsUpdt','off')
		end
	elseif(rule == "airOn") then
		print("Ligar Ar Condicionado")
		if(not airConditioning) then
			airConditioning = true
			mqttPublish('airUpdt','on')
		end
	elseif(rule == "airOff") then
		print("Desligar Ar Condicionado")
		if(airConditioning) then
			airConditioning = false
			mqttPublish('airUpdt','off')
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

function checkValues()

	count = 0
	sumLuminosity = 0

	for i,info in ipairs(sensorValues) do
		if(next(info) ~= nil) then
			sumLuminosity = sumLuminosity + info.luminosity
			count = count + 1
			sensorValues[i] = {}
		else
			print("Didn't received luminosity value from " .. i)
		end
	end

	if count > 0 then
		luminosityValue = sumLuminosity/count
	end

	mqttPublish('luminosityUpdt',luminosityValue)

	tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 checkValues()
		  end)

end

-- tmr.create():alarm(delay*2/1000,tmr.ALARM_SINGLE, function()
-- 		 checkValues()
-- 		  end)


init()
