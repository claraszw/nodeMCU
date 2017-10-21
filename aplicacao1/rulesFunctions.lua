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
		if (parameterValue["luminosity"] ~= nil and parameterValue["luminosity"] > value) then
			return true
		end
	end,
	lowerBoundLight = function(value)
		if (parameterValue["luminosity"] ~= nil and parameterValue["luminosity"] < value) then
			return true
		end
	end,
	temperature = function (value)
		return true
	end
}

rulesFunctions.checkValue = {
	
	average = function(parameter,info,i)
		if(info[parameter] ~= nil) then
			if(info[parameter] ~= "error") then
				if(countError[i][parameter] >= 5) then
					mqttPublish(parameter..'Updt/fixed',i)
				end
				countError[i][parameter] = 0
				sum[parameter] = sum[parameter] + info[parameter]
				count[parameter] = count[parameter] + 1
			else
				print('Error in ' .. i.. ' parameter')
				countError[i][parameter] = countError[i][parameter] + 1
				if(countError[i][parameter] >= 5) then
					mqttPublish(parameter..'Updt/error',i)
				end
			end
		end	
	end
}

rulesFunctions.calculateValue = {

	average = function (parameter)
		if count[parameter] > 0 then
			parameterValue[parameter] = math.floor(sum[parameter]/count[parameter])
			mqttPublish(parameter..'Updt',parameterValue[parameter])
		else
			parameterValue[parameter] = nil
		end
	end
}

return rulesFunctions