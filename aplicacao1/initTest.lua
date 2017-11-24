
delay = 15000000 --ms

tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 run()
		  end)

ERROR_PIN = 3

gpio.mode(ERROR_PIN,gpio.OUTPUT)
gpio.write(ERROR_PIN,gpio.LOW)

function run()
	ip = dofile('config.lua')
	if(ip ~= nil) then
		dofile('fatherNode.lua')
	else
		gpio.write(ERROR_PIN,gpio.LOW)
	end
end