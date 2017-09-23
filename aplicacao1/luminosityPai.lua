
MQTT_PORT = 1883
MQTT_HOST = "192.168.0.7"
delay = 15000000 --ms

CONNECTED_LED = 1
ERROR_LED = 2

gpio.mode(CONNECTED_LED,gpio.OUTPUT)
gpio.mode(ERROR_LED,gpio.OUTPUT)

retry=true

luminosityValues = {'undefined','undefined'}
luminosityValue = 0
lights = false

rules = {}
gpio.write(ERROR_LED,gpio.HIGH)

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("piocorreia","wfpcapto41")

	while ip == nil do
		wifi.sta.connect()
		print("Connecting to piocorreia")
    	ip = wifi.sta.getip()
    	tmr.delay(5000000)
    end
	print("IP is ".. ip)
end

function mqttConnect()
	print('Attempt to connect')
	mqttClient:connect(MQTT_HOST,MQTT_PORT,0,0, function(con)
    		print('Connected to broker')
            mqttRegister('luminosity')
            mqttRegister('newRule')
            mqttRegister('delete')
            mqttPublish('configInit','sala516')
            mqttPublish('request','luminosity')
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

	-- time = rtctime.epoch2cal(rtctime.get())
	hour = 10--time.hour
	min = 20 --time.min
	timeConverted = hour + min/60

	print("Current Time: " .. timeConverted)

	if(topic == 'luminosity') then
        message = loadstring('return'..data)()
        luminosityValues[message.source] = message.data

        luminosityValue = message.data
        
		-- print('Received luminosity value: '.. message['data'] .. 'from: '..message['source'])

		mqttPublish('luminosityUpdt',luminosityValues[message.source])


	elseif (topic == 'newRule') then
		message = loadstring('return'..data)()

        print(message)
        print(message.type)

		rules[message["type"]] = message["parameters"]


	elseif (topic == 'delete') then
		if(data == 'all') then

			for key,value in pairs(rules) do
				rules[key]=nil
			end
		else

			message = loadstring('return'..data)()

			for key,value in pairs(rules) do
				if(value['type'] == message['type'] and value['timeBegin'] == message['timeBegin']) then
					rules[key]=nil
					break
				end
			end

		end

	end

	-- count = 0

	-- for rule,parameters in pairs(rules) do
	-- 	act = true
	-- 	count = count + 1

	-- 	for parameter,value in pairs(parameters) do
	-- 	  if(not checkParameter(parameter,value)) then
	-- 	  	act = false
	-- 	  	break
	-- 	  end
	-- 	end

	-- 	if(act or (count==0)) then
	-- 		applyRule(rule)
	-- 	end
	-- end

	checkLights()

end

function checkLights()
	if(rules["lightsOn"] ~= nil) then
        count = 0
		act = true
		count = count + 1

		for parameter,value in pairs(rules["lightsOn"]) do
		  if(not checkParameter(parameter,value)) then
		  	act = false
		  	break
		  end
		end

		if(act or (count==0)) then
			applyRule("lightsOn")
		else
			applyRule("lightsOff")
		end

	else 
		applyRule("lightsOff")
	end
end

function checkTemperature( ... )
	-- body
end

function checkAlarm( ... )
	-- body
end

function checkParameter(parameterType,value)

	if(parameterType == "upperBoundLight") then
		if (luminosityValue ~= nil and luminosityValue > value) then
			return true
		else
			return false
		end

	elseif(parameterType == "lowerBoundLight") then
		if (luminosityValue ~= nil and luminosityValue < value) then
        -- print("value is smaller")
			return true
		else
			return false
		end
	end

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

	for i,luminosity in ipairs(luminosityValues) do
		if(luminosity ~= 'undefined') then
			sumLuminosity = sumLuminosity + luminosity
			count = count + 1
			luminosityValues[i] = 'undefined'
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
