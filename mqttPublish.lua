

nodeId = node.chipid()
m = nil
ip = 0
mqttPORT = 1883

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("piocorreia","wfpcapto41")
	wifi.sta.connect()

	print("Connecting to piocorreia")
	--print("IP is ".. wifi.sta.getip())
    --ip = wifi.sta.getip()

end

function mqttRegister()
	m:subscribe('nodeMCU/test',0,function(conn)
        print("Successfully subscribed to data endpoint")
    end)
end

function mqttPublish(data)

	m:publish("nodeMCU/test",data,0,0, function(client) print("sent") end)

end

function run()
	mqttPublish("hello")
	mqttPublish("on")
	tmr.delay(3000000)
	mqttPublish("off")
end

function mqttStart()
	
	m = mqtt.Client(nodeId,120)


	m:on("connect", function(client) print ("connected") end)
	m:on("offline", function(client) print ("offline") end)

	m:on("message", function(client, topic, data)
	print("Received Message!") 
  	print(topic .. ":" ) 
	  if data ~= nil then
	    print(data)
	  end
	end)

	m:connect("iot.eclipse.org",mqttPORT,0,1, function(con) 
		run()
		end, function(con,reason) print("Couldn't connect to broker: ".. reason) end)

end

configWifi()

if(ip ~= nil) then
	mqttStart()
else
	print("Nil IP")
end
