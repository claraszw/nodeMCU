
delay = 10000000 --ms

tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 run()
		  end)

ERROR_PIN = 3

gpio.mode(ERROR_PIN,gpio.OUTPUT)
gpio.write(ERROR_PIN,gpio.LOW)

function run()
	ip = dofile('config.lua')
	if(ip ~= nil) then
		dofile('childNode2.lua')
	else 
		gpio.write(ERROR_PIN,gpio.HIGH)
	end
end
