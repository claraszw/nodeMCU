
pirPort = 1
gpio.mode(pirPort, gpio.INPUT)




count = 0

while count < 15 do

	print('PIR sensor: '.. gpio.read(pirPort))
	count = count +1
	tmr.delay(1000000)

end
