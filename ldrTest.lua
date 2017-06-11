

ledPort = 1
gpio.mode(ledPort, gpio.OUTPUT)

buttonPort = 3
gpio.mode(buttonPort,gpio.INPUT)


function init()
	
	if adc.force_init_mode(adc.INIT_ADC) then
  		node.restart()
  		return -- don't bother continuing, the restart is scheduled
	end

end

function configWifi()
	-- Configure Wi-Fi
	wifi.setmode(wifi.STATION)
	wifi.sta.config("sadock","esquilo")
	wifi.sta.connect()

	print("Connecting to piocorreia")
	--print("IP is ".. wifi.sta.getip())
    --ip = wifi.sta.getip()

end

function checkLuminosity(port)
	
	val = adc.read(port)

	print("Luminosity: "..val)

	if(val>500) then
		print("acender")
		gpio.write(ledPort,gpio.HIGH)
	else
		print("apagar")
		gpio.write(ledPort,gpio.LOW)
	end

end

init()
configWifi()

count = 0

while count<15 do

	tmr.delay(1000000)
	checkLuminosity(0)
	count=count+1

end
