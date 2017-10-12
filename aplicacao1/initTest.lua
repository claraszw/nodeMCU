
delay = 15000000 --ms

tmr.create():alarm(delay/1000,tmr.ALARM_SINGLE, function()
		 run()
		  end)


function run()
	ip = dofile('config.lua')
	if(ip ~= nil) then
		dofile('fatherNode.lua')
	end
end