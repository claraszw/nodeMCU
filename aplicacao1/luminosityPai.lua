
MQTT_PORT = 1883
MQTT_HOST = "192.168.1.10"
delay = 10000000 --ms

retry=true

luminosityValue=0
lights = false

activeRules = {}
rules = {}

nextTime = 1000

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
            mqttRegister('luminosity')
            mqttRegister('newRule')
            mqttRegister('delete')
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

	-- time = rtctime.epoch2cal(rtctime.get())
	hour = 10--time.hour
	min = 20 --time.min
	timeConverted = hour + min/60

	print("Current Time: " .. timeConverted)

	if(topic == 'luminosity') then
        message = loadstring('return'..data)()
        luminosityValue = message.data
		-- print('Received luminosity value: '.. message['data'] .. 'from: '..message['source'])

		mqttPublish('luminosityUpdt',luminosityValue)


	elseif (topic == 'newRule') then
		message = loadstring('return'..data)()

		timeBegin = message['timeBegin']
		timeEnd = message.timeEnd

        print(message)
        print(message.type)
		print(timeBegin)
		print(timeEnd)

		if(timeConverted >= timeBegin and timeConverted<=timeEnd) then
			print('New Active Rule!')
			activeRules[message["type"]] = message["parameters"]
		else
			print('New Rule!')
			if(timeBegin<nextTime) then
				nextTime = timeBegin
			end
		end

		table.insert(rules,message)

	elseif (topic == 'delete') then
		if(data == 'all') then

			for key,value in pairs(rules) do
				rules[key]=nil
			end

			for key,value in pairs(activeRules) do
				activeRules[key]=nil
			end
		else

			message = loadstring('return'..data)()

			for key,value in pairs(rules) do
				if(value['type'] == message['type'] and value['timeBegin'] == message['timeBegin']) then
					print("Found Rule!")
					rules[key]=nil
					break
				end
			end

			if(timeConverted >= message['timeBegin'] and timeConverted <= message['timeEnd']) then
				print('Found active Rule!')
				activeRules[message["type"]] = nil
			end

		end

	elseif (topic == 'control') then
		if(data == "quit") then
			mqttPublish('control1','quit')
		end
	end

	count = 0

	for rule,parameters in pairs(activeRules) do
		act = true
		count = count + 1

		for parameter,value in pairs(parameters) do
		  if(not checkParameter(parameter,value)) then
		  	act = false
		  	break
		  end
		end

		if(act or (count==0)) then
			applyRule(rule)
		end
	end

end

function checkParameter(parameterType,value)

	if(parameterType == "upperBoundLight") then
		if (luminosityValue > value) then
			return true
		else
			return false
		end

	elseif(parameterType == "lowerBoundLight") then
		if (luminosityValue < value) then
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

init()
