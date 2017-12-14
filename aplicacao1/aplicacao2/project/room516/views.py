# project/room516/views.py
# !/usr/bin/python3
 
#################
#### imports ####
#################
 
from __future__ import division
from flask import render_template, Blueprint
from flask import Flask, render_template, request, redirect, url_for
from flask_socketio import SocketIO, emit
import paho.mqtt.client as mqtt
import copy, ast
from threading import Timer
from datetime import datetime
from project import socketio
 
 
################
#### config ####
################
 
room516_blueprint = Blueprint('room516', __name__, template_folder='templates')
 
 
################
#### routes ####
################
 
# The callback for when the client receives a CONNACK response from the server.
def on_connect(client,userdata,flags,rc):
    print("Connected with result code " + str(rc))

    client.subscribe("luminosityUpdt/#")
    client.subscribe("temperatureUpdt/#")
    client.subscribe("presenceUpdt/#")
    client.subscribe("errorNode/#")
    client.subscribe("lightsUpdt")
    client.subscribe("configInit")
    client.subscribe("airUpdt")

    #initialize

# The callback for when a PUBLISH message is received from the ESP8266.
def on_message(client, userdata, message):
    #socketio.emit('my variable')

    global temperatureUpdt
    global luminosityUpdt

    payload = str(message.payload,'utf-8')
    
    print("Received message '" + payload + "' on topic '"
        + message.topic + "' with QoS " + str(message.qos))


    if message.topic == "luminosityUpdt":
        luminosityUpdt = payload
        socketio.emit('luminosity', {'data': payload})

    if message.topic == "presenceUpdt":
        presenceUpdt = payload
        socketio.emit('presence', {'data': payload})
    
    if message.topic == "luminosityUpdt/error":
        errors[int(payload) - 1]["luminosity"] = True
        socketio.emit('error',{'data': errors})
    
    if message.topic == "luminosityUpdt/fixed":
        errors[int(payload) - 1]["luminosity"] = False 
        socketio.emit('error',{'data': errors})

    if message.topic == "temperatureUpdt":
        temperatureUpdt = payload;
        socketio.emit('temperature', {'data': payload})
    
    if message.topic == "temperatureUpdt/error":
        errors[int(payload) - 1]["temperature"] = True
        socketio.emit('error',{'data': errors})
    
    if message.topic == "temperatureUpdt/fixed":
        errors[int(payload) - 1]["temperature"] = False 
        socketio.emit('error',{'data': errors})

    if message.topic == "errorNode":
        errors[int(payload) - 1]["total"] = True
        socketio.emit('error',{'data': errors})
    
    if message.topic == "errorNode/fixed":
        errors[int(payload) - 1]["total"] = False
        socketio.emit('error',{'data': errors})

    if message.topic == "airUpdt" :
        airUpdt = payload;
        socketio.emit('air', {'data': airLabel[payload]})

    if message.topic == "lightsUpdt" :
    	print("lights update")
    	lightsUpdt = payload
    	socketio.emit('lights', {'data': lightsLabel[payload]})

    if message.topic == "configInit":
    	mqttc.publish('disabled',disabled)
    	for rule in rules:
    		checkRuleTime(rule,"send")


# Rule Template = {
# 	'endString': 'Ate: 11:00',
#  	'beginString': 'De: 09:00',
#  	'parameters': {'lowerBoundLight': 300, 'upperBoundLight': 'None'},
#  	'type': 'lightsOn',
#   'timeEnd': 11,
#  	'timeBegin': 9,
# }

mqttc=mqtt.Client()
mqttc.on_connect = on_connect
mqttc.on_message = on_message
mqttc.connect("localhost",1883,60)
mqttc.loop_start()


actions = {}
actionTimer = {"nextTimer" : None, 'firstTime' : True}

ruleTypes = {"lightsOn":"Acender Luzes", "controlTemperature": "Manter Temperatura"}
conditionTypes = {"lowerBoundLight": "Luminosidade Abaixo De:","upperBoundLight": "Luminosidade Acima De:", "presence": "Existe Presenca:"}
condition = {}
conditions = {"lowerBoundLight": 'None',"upperBoundLight":'None', "presence":"None"}
conditionsLabels = {"Sim": "true", "Nao": "false", "Aberta":"open", "Fechada":"closed"}
lightsUpdt = "off"
lightsLabel = {"off" : "Apagadas", "on": "Acesas"}
airUpdt = "off"
airLabel = {"off" : "Desligado", "on": "Ligado"}

errors = [{"luminosity":False, "temperature":False, "total":False},{"luminosity":False, "temperature":False, "total":False}]

luminosityUpdt = 0
temperatureUpdt = 0
presenceUpdt = "False"
temperatureParam = 22
disabled = "false"

fileRules = open('rules.txt','r')

rules = []


nextTime = 100

newRule = {
	'type': 'None'
}

templateData = {
		'async_mode':socketio.async_mode,
		'ruleTypes':ruleTypes,
		'conditionTypes':conditionTypes,
		'condition':condition,
		'conditions':conditions,
		'rules':rules,
		'luminosity':luminosityUpdt,
		'presence':presenceUpdt,
		'air':airUpdt,
		'lightsLabel': lightsLabel,
		'airLabel': airLabel,
		'temperature': temperatureUpdt,
		'state':'init',
		'temperatureParam':temperatureParam,
		'errors': errors,
};


def addRule(rule):

	# If the time doesn't exist in the timer dictionary creates an empty array to that entry 
	if(rule["timeBegin"] not in actions):
		actions[rule["timeBegin"]] = {}
		actions[rule["timeBegin"]]["ruleBegin"] = []

	# Add rule to array of time
	else:
		if("ruleBegin" not in actions[rule["timeBegin"]]):
			actions[rule["timeBegin"]]["ruleBegin"] = []

	actions[rule["timeBegin"]]["ruleBegin"].append(rule)

	#add delete rule timer

	if(rule["timeEnd"] not in actions):
		actions[rule["timeEnd"]] = {}
		actions[rule["timeEnd"]]["ruleDelete"] = []

	else:
		if("ruleDelete" not in actions[rule["timeEnd"]]):
			actions[rule["timeEnd"]]["ruleDelete"] = []

	actions[rule["timeEnd"]]["ruleDelete"].append(rule)

def getRules():

	print("entering get rules: " + str(actions))

	now = datetime.now()

	currentTime = hour_to_number(now.hour,now.minute)

	#read rules from file

	for line in fileRules:
		rules.append(ast.literal_eval(line))	

	#assemble timer array

	for rule in rules:
		addRule(rule)
		#see if rule should already be sent
		checkRuleTime(rule,"send")

	if(len(actions) > 0):
		getNextRuleTime()

#	Check if the rule is active, and takes action (send new rule or delete rule)
def checkRuleTime(rule,ruleType):	

	now = datetime.now()
	currentTime = hour_to_number(now.hour,now.minute)
	isTime = False

	if(rule["timeBegin"] < rule["timeEnd"]):
		if(currentTime >= rule["timeBegin"] and currentTime<= rule["timeEnd"]):
			isTime = True
	else:
		if(currentTime >= rule["timeBegin"] or currentTime<= rule["timeEnd"]):
			isTime = True

	if(isTime):
		if(ruleType == "send"):
			sendRule(rule)
		elif(ruleType == "delete"):
			sendDelete(rule)
		return True

	return False

def getNextRuleTime():

	global nextTime

	now = datetime.now()
	currentTime = hour_to_number(now.hour,now.minute)

	print("GETTING NEXT TIME")
	print(str(actions))

	#try to get next time on the same day
	try:
		newTime = min(time for time in actions if time > currentTime)
		print("GOT TIME TODAY"+str(newTime))
	except ValueError:
		#get first time next day
		newTime = min(actions)
		
	if(newTime != nextTime):
		nextTime = newTime
		createTimer()


def createTimer():

	global nextTime
	totalTime = 0

	print("ABOUT TO CREAT TIMER FOR NEXT TIME: "+ str(nextTime))

	if(actionTimer["nextTimer"] != None):
		actionTimer["nextTimer"].cancel()

	now = datetime.now()
	currentTime = hour_to_number(now.hour,now.minute)
	print("Current time: "+ str(currentTime))
	print("Current time minus next time" + str(nextTime-currentTime))

	if(nextTime > currentTime):
		print("CALCULATING TOTAL TIME")
		totalTime = (nextTime-currentTime)*3600.0

	else:
		print(str(((24-currentTime) + nextTime)*3600))
		totalTime = ((24-currentTime) + nextTime)*3600

	actionTimer["nextTimer"] = Timer(totalTime,executeTimer,[nextTime])
	actionTimer["nextTimer"].start()
	print("Created timer for: " + str(totalTime))

def executeTimer(time):

	global nextTime

	if("ruleBegin" in actions[time]):
		for rule in actions[time]["ruleBegin"]:
			sendRule(rule)

	if("ruleDelete" in actions[time] ):
		for rule in actions[time]["ruleDelete"]:
			sendDelete(rule)

	nextTime = 100
	getNextRuleTime()


def deleteRuleFromTimer(removedRule):

	global actions
	global nextTime

	if(removedRule == 'all'):
		actions = {}
		del rules[:]
	else:
		actions[removedRule["timeBegin"]]["ruleBegin"].remove(removedRule)
		actions[removedRule["timeEnd"]]["ruleDelete"].remove(removedRule)

		# check if there are other rules for that specific time, if not, remove the entry
		if("ruleDelete" not in actions[removedRule["timeBegin"]]):
			if(len(actions[removedRule["timeBegin"]]["ruleBegin"]) == 0):
				del actions[removedRule["timeBegin"]]

		if("ruleBegin" not in actions[removedRule["timeEnd"]]):
			if(len(actions[removedRule["timeEnd"]]["ruleDelete"]) == 0):
				del actions[removedRule["timeEnd"]]


	if(actions):
		getNextRuleTime()
	else:
		if(actionTimer["nextTimer"] != None):
			actionTimer["nextTimer"].cancel()
		nextTime = 100

	print("Rule Deleted ")
	print(str(actions))

def sendRule(rule):
	ruleString = " { type = \"" + str(rule["type"]) + "\", parameters = {"

	if(rule["type"] == "controlTemperature"):
					ruleString = ruleString + "temperature = " + str(rule["temperature"]) + ","

	for key,value in rule["parameters"].items():
		if(value != 'None'):
			if(key == "door" or  key=="window" or key=="presence"):
				ruleString = ruleString + str(key) + "=" + conditionsLabels[str(value)] + ","
			else:
				ruleString = ruleString + str(key) + "=" + str(value) + ","

	ruleString = ruleString + '} }'

	mqttc.publish('newRule',ruleString)

def sendDelete(rule):

	ruleString = "{ type = \"" + str(rule["type"]) + "\", parameters = {"

	if(rule["type"] == "controlTemperature"):
		ruleString = ruleString + "temperature = " + str(rule["temperature"]) + ","

	for key,value in rule["parameters"].items():
		if(value != 'None'):
			ruleString = ruleString + str(key) + "=" + str(value) + ","

	ruleString = ruleString + "} }"
	mqttc.publish('delete',ruleString)


def hour_to_number(hour,minutes):
	print(str(hour) + str(minutes))
	return round(hour + minutes/60, 2)


@room516_blueprint.route('/516', methods=['GET', 'POST'])
def index():

	print(templateData['state'])

	return render_template('room516.html',**templateData);


@room516_blueprint.route('/516/new/',methods=['GET', 'POST'])
def new():

	global nextTime
	global luminosityUpdt
	global temperatureUpdt
	global templateData

	btn = request.form['btn']

	print("RECEIVED!!"+str(btn))

	if(btn == 'conditionType'):
		condition["label"] = ast.literal_eval(request.form.get('conditionType'))["label"]
		condition["type"] = ast.literal_eval(request.form.get('conditionType'))["value"]

	elif(btn=="cancelCreateRule"):
		for key,value in conditions.items():
			conditions[key] = 'None'
		
		templateData['state']='init'
		newRule["type"] = 'None'
		# templateData['luminosity']=luminosityUpdt["value"]
		
		# return redirect('/')

	elif(btn == "createCondition"):

		conditionType = request.form.get('conditionType')

		if(str(conditionType) == "presence"):
			value = request.form.get("presence")
		elif(str(conditionType) == "window" or str(conditionType) == "door"):
			value = request.form.get("magnet")
		else:
			value = ast.literal_eval(request.form.get('conditionValue'))

		conditions[str(conditionType)] = value

		templateData['state']='conditions'

		if(newRule["type"] == 'None'):

			newRule["type"] = str(request.form.get('ruleType'))

			hourBegin = request.form.get('hourI')
			hourEnd = request.form.get('hourE') 
			minuteBegin = request.form.get('minI') 
			minuteEnd = request.form.get('minE') 

			timeBegin = hour_to_number(int(hourBegin),int(minuteBegin))
			timeEnd = hour_to_number(int(hourEnd),int(minuteEnd))

			newRule["timeBegin"] = timeBegin
			newRule["timeEnd"] = timeEnd

			beginString = str('De: ' + hourBegin + ':' + minuteBegin)

			newRule["beginString"] = beginString 

			endString = str('Ate: ' + hourEnd + ':' + minuteEnd)

			newRule["endString"] = endString 

			
			templateData['rule']= str(request.form.get('ruleType'))
			templateData['hourI']= hourBegin
			templateData['hourE']= hourEnd
			templateData['minI']= minuteBegin
			templateData['minE']= minuteEnd
			templateData['temperatureParam']= ast.literal_eval(request.form.get('temperature'))

			if(newRule["type"] == "controlTemperature"):
				newRule["temperature"] = ast.literal_eval(request.form.get('temperature'))
			else:
				newRule["temperature"] = 0

	elif(btn == "createRule"):
		# print(request.form.get('ruleType'))
		newRule["parameters"] = copy.copy(conditions)

		if(newRule["type"] == 'None'):

			newRule["type"] = str(request.form.get('ruleType'))

			hourBegin = request.form.get('hourI')
			hourEnd = request.form.get('hourE') 
			minuteBegin = request.form.get('minI') 
			minuteEnd = request.form.get('minE') 

			timeBegin = hour_to_number(int(hourBegin),int(minuteBegin))
			timeEnd = hour_to_number(int(hourEnd),int(minuteEnd))

			newRule["timeBegin"] = timeBegin
			newRule["timeEnd"] = timeEnd

			beginString = str('De: ' + hourBegin + ':' + minuteBegin)

			newRule["beginString"] = beginString 

			endString = str('Ate: ' + hourEnd + ':' + minuteEnd)

			newRule["endString"] = endString 

			
			templateData['rule']= str(request.form.get('ruleType'))
			templateData['hourI']= hourBegin
			templateData['hourE']= hourEnd
			templateData['minI']= minuteBegin
			templateData['minE']= minuteEnd
			templateData['temperatureParam']= ast.literal_eval(request.form.get('temperature'))


			if(newRule["type"] == "controlTemperature"):
				newRule["temperature"] = ast.literal_eval(request.form.get('temperature'))
			else:
				newRule["temperature"] = 0

		print("New Rule type: " + newRule["type"])

		newRuleCopy = copy.copy(newRule)

		rules.append(copy.copy(newRule))

		fileNewRules = open('rules.txt','w')

		for rule in rules:
			fileNewRules.write(str(rule)+'\n')

		fileNewRules.close()

		addRule(newRuleCopy)
		checkRuleTime(newRuleCopy,"send")
		getNextRuleTime()


		newRule["type"] = 'None'

		
		for key,value in conditions.items():
			conditions[key] = 'None'

		templateData['state']='init'

	elif(conditionTypes[btn]):
		conditions[btn] = 'None'
		templateData['state']='conditions'
		# templateData['temperatureParam']='conditions'
		# templateData['rule']= ruleTypes[str(request.form.get('ruleType'))]
		# templateData['hourI']= hourBegin
		# templateData['hourE']= hourEnd
		# templateData['minI']= minuteBegin
		# templateData['minE']= minuteEnd

	templateData['luminosity'] = luminosityUpdt
	templateData['temperature'] = temperatureUpdt
	templateData['lights']=lightsUpdt
	templateData['air']=airUpdt

	return redirect('/516')

@room516_blueprint.route('/516/deleteRule',methods=['GET', 'POST'])
def deleteRule():

	global luminosityUpdt
	global temperatureUpdt

	btn = request.form['btn']

	if(btn == 'all'):
		deleteRuleFromTimer('all')
		mqttc.publish('delete','all')
	
	else:
		removedRule = ast.literal_eval(request.form['btn']) 
		checkRuleTime(removedRule,"delete")
		rules.remove(removedRule)
		#delete rule from timer
		deleteRuleFromTimer(removedRule)

	fileNewRules = open('rules.txt','w')

	for rule in rules:
		fileNewRules.write(str(rule)+'\n')

	fileNewRules.close()

	templateData['lights']=lightsUpdt
	templateData['luminosity']=luminosityUpdt
	templateData['air']=airUpdt
	
	return redirect('/516')

@socketio.on('my event')
def handle_my_custom_event(json):
    print('received json data here: ' + str(json))

@socketio.on('disabled')
def toggleDisabled(message):
	disabled = message
	mqttc.publish('disabled',disabled)
	


@socketio.on('connect')
def test_connect():
	print('Im connecting')

	if(actionTimer["firstTime"]):
		print("this is the first time im connecting, will get rules")
		actionTimer["firstTime"] = False
		getRules()
	else:
		print("This is not the first time im connecting, wont get rules")


# if __name__ == '__main__':
	
