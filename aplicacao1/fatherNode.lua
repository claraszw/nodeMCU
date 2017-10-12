tableFunctions = require('rulesFunctions')


MQTT_PORT = 1883
MQTT_HOST = "192.168.0.7"
delay = 15000000 --ms

AIR_LED = 3
LIGHT_LED = 6

gpio.mode(AIR_LED,gpio.OUTPUT)
gpio.mode(LIGHT_LED,gpio.OUTPUT)

retry=true

sensorValues = {{},{}}
countError = {0,0}
luminosityValue = 0
temperatureValue = 0
lights = false
airConditioning = false

rules = {lightsOn = {}, controlTemperature = {}}

function mqttStart()
	
	mqttClient = mqtt.Client(NODE_ID,120)

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
    end)
end

function mqttPublish(channel,data)
	mqttClient:publish(channel,data,0,0, function(client) print("sent: " .. data .. ' to: ' .. channel) end)
end

function handleMqttError()
	gpio.write(ERROR_LED,gpio.HIGH)
	tmr.create():alarm(10*1000, tmr.ALARM_SINGLE, mqttConnect)
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
            gpio.write(AIR_LED,gpio.LOW)
            gpio.write(LIGHT_LED,gpio.LOW)
            checkValues()
    		end, function(con,reason) 
    		-- gpio.mode(ledErrorPin, gpio.OUTPUT)
    		print("Couldn't connect to broker: ".. reason)
    		handleMqttError() end)

	if(retry) then 
		tmr.create():alarm(10*1000, tmr.ALARM_SINGLE, mqttConnect)
		retry = false
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

function messageReceived(topic,data)

	print('MESSAGE RECEIVED!'..topic ..'  ' .. data)

	if(topic == 'sensorInfo') then
    	message = loadstring('return'..data)()

        sensorValues[message.source] = message.info
	-- print('Received luminosity value: '.. message['data'] .. 'from: '..message['source'])

	elseif (topic == 'newRule') then
    	message = loadstring('return'..data)()
        print(message)
        table.insert(rules[message["type"]],message["parameters"])

	elseif (topic == 'delete') then
		if(data == 'all') then
			for key,value in pairs(rules) do
				rules[key]={}
			end
		else
    		message = loadstring('return'..data)()

			for index,rule in pairs(rules[message["type"]]) do
				if(next(rule) == nil and next(message["parameters"]) == nil) then
					table.remove(rules[message["type"]],index)
					break
				end
				for parameter,value in pairs(rule) do
					if( rule[parameter] ~= nil) then
						table.remove(rules[message["type"]],index)	
					end
					break
				end
			end

		end

	end

end

function checkLights()

	act = checkParameters("lightsOn")

	if(act) then
		tableFunctions.rulesActions["lightsOn"]()
	else
		tableFunctions.rulesActions["lightsOff"]()
	end

end

function checkTemperature()
	-- Right now assuming that only one rule to control temperature will be active, if there were more it would be necessary to considerate which one
	-- in order to get the correct temperature value to check

	act = checkParameters("controlTemperature")
	rule = rules["controlTemperature"][1]

	if(act) then
		if(temperatureValue < (rule["temperature"] - 2)) then
			tableFunctions.rulesActions["airOn"]()
		elseif(temperatureValue > (rule["temperature"]) + 2) then
			tableFunctions.rulesActions["airOn"]()
		else
			tableFunctions.rulesActions["airOff"]()
		end
	else
		tableFunctions.rulesActions["airOff"]()
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
		  if(not tableFunctions.checkParameter[parameter](value)) then
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

function checkValues()

	countLuminosity = 0
	sumLuminosity = 0

	countTemperature = 0
	sumTemperature = 0

	for i,info in ipairs(sensorValues) do
		if(next(info) ~= nil) then
			if(info.luminosity ~= nil) then
				if(info.luminosity ~= "error") then
					sumLuminosity = sumLuminosity + info.luminosity
					countLuminosity = countLuminosity + 1
					countError[i] = 0
				else
					print('Error in ' .. i.. ' luminosity')
					countError[i] = countError[i] + 1
					if(countError[i] >= 5) then
						mqttPublish('luminosityUpdt',"Error in ".. i)
					end
				end
			end
			if(info.temperature ~= nil) then
				if(info.temperature ~= "error") then
					sumTemperature = sumTemperature + info.temperature
					countTemperature = countTemperature + 1
				else
					print('Error in ' .. i.. ' temperature')
					if(countError[i] >= 5) then
						mqttPublish('luminosityUpdt',"Error in ".. i)
					end
				end
			end	
			sensorValues[i] = {}
		else
			print("Didn't received Info from " .. i)
		end
	end

	if countLuminosity > 0 then
		luminosityValue = sumLuminosity/countLuminosity
		mqttPublish('luminosityUpdt',luminosityValue)
	else
		luminosityValue = nil
	end
	if countTemperature > 0 then
		temperatureValue = sumTemperature/countTemperature
		mqttPublish('temperatureUpdt',temperatureValue)
	else
		temperatureValue = nil
	end

	checkLights()
	checkTemperature()


	tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 checkValues()
		  end)

end

mqttStart()
