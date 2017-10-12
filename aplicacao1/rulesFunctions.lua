local rulesFunctions = {}

rulesFunctions.rulesActions = {
	
	lightsOn = function()
		print("Acender Luzes!")
		gpio.write(LIGHT_LED,gpio.HIGH)
		if(not lights) then
			lights = true
			mqttPublish('lightsUpdt','on')
		end
	end,

	lightsOff = function ()
		print("Apagar Luzes!")
		gpio.write(LIGHT_LED,gpio.LOW)
		if(lights) then
			lights = false
			mqttPublish('lightsUpdt','off')
		end
	end,

	airOn = function ()
		print("Ligar Ar Condicionado")
		gpio.write(AIR_LED,gpio.HIGH)
		if(not airConditioning) then
			airConditioning = true
			mqttPublish('airUpdt','on')
		end
	end,

	airOff = function()
		print("Desligar Ar Condicionado")
		gpio.write(AIR_LED,gpio.LOW)
		if(airConditioning) then
			airConditioning = false
			mqttPublish('airUpdt','off')
		end
	end
}

rulesFunctions.checkParameter = {
	
	upperBoundLight = function (value)
		if (luminosityValue ~= nil and luminosityValue > value) then
			return true
		end
	end,
	lowerBoundLight = function(value)
		if (luminosityValue ~= nil and luminosityValue < value) then
			return true
		end
	end,
	temperature = function (value)
		return true
	end
}

return rulesFunctions