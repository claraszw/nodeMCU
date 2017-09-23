from __future__ import division
from flask import Flask, render_template, request, redirect, url_for
from flask_socketio import SocketIO, emit
import paho.mqtt.client as mqtt
import copy, ast
from threading import Timer
from datetime import datetime

app = Flask(__name__)


app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app)

# The callback for when the client receives a CONNACK response from the server.
def on_connect(client,userdata,flags,rc):
    print("Connected with result code " + str(rc))

    client.subscribe("luminosityUpdt")
    client.subscribe("lightsUpdt")
    client.subscribe("configInit")

    #initialize

# The callback for when a PUBLISH message is received from the ESP8266.
def on_message(client, userdata, message):
    #socketio.emit('my variable')
    print("Received message '" + str(message.payload) + "' on topic '"
        + message.topic + "' with QoS " + str(message.qos))

    if message.topic == "luminosityUpdt":
        print("luminosity update")
        luminosityUpdt["value"] = message.payload;
        socketio.emit('luminosity', {'data': message.payload})

    if message.topic == "lightsUpdt" :
    	print("lights update")
        lightsUpdt["value"] = message.payload;
        socketio.emit('lights', {'data': lightsLabel[message.payload]})

    if message.topic == "configInit":
    	for rule in rules:
    		checkRuleTime(rule,"send")


ruleTypes = {"lightsOn":"Acender Luzes"}
conditionTypes = {"lowerBoundLight": "Luminosidade Abaixo De","upperBoundLight": "Luminosidade Acima De"}

condition = {}
conditions = {"lowerBoundLight": 'None',"upperBoundLight":'None'}

fileRules = open('rules.txt','r')

rules = []

mqttc=mqtt.Client()
mqttc.on_connect = on_connect
mqttc.on_message = on_message
mqttc.connect("localhost",1883,60)
mqttc.loop_start()

actions = {}

actionTimer = {"nextTimer" : None, 'firstTime' : True}

nextTime = { "value" : 100 }

newRule = {
	'type': 'None'
}

luminosityUpdt = {}
luminosityUpdt["value"] = 0

lightsUpdt = {"value": "off"}
lightsLabel = {"off" : "Apagadas", "on": "Acesas"}

templateData = {
		'async_mode':socketio.async_mode,
		'ruleTypes':ruleTypes,
		'conditionTypes':conditionTypes,
		'condition':condition,
		'conditions':conditions,
		'rules':rules,
		# 'luminosity':luminosityUpdt["value"],
		'lights':lightsUpdt["value"],
		'lightsLabel': lightsLabel,
		'state':'init'
};

# Rule Template = {
# 	'endString': 'Ate: 11:00',
#  	'beginString': 'De: 09:00',
#  	'parameters': {'lowerBoundLight': 300, 'upperBoundLight': 'None'},
#  	'type': 'lightsOn',
#   	'timeEnd': 11,
#  	'timeBegin': 9
# }


def addRule(rule):

	if(rule["timeBegin"] not in actions):
		actions[rule["timeBegin"]] = {}
		actions[rule["timeBegin"]]["ruleBegin"] = []
		actions[rule["timeBegin"]]["ruleBegin"].append(rule)

	else:
		if("ruleBegin" not in actions[rule["timeBegin"]]):
			actions[rule["timeBegin"]]["ruleBegin"] = []

		actions[rule["timeBegin"]]["ruleBegin"].append(rule)

	#add delete rule timer

	if(rule["timeEnd"] not in actions):
		actions[rule["timeEnd"]] = {}
		actions[rule["timeEnd"]]["ruleDelete"] = []
		actions[rule["timeEnd"]]["ruleDelete"].append(rule)

	else:
		if("ruleDelete" not in actions):
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
		try:
			nextTime["value"] = min(time for time in actions if time > currentTime)
			print("In try: " + str(nextTime["value"]))
		except ValueError:
			#get first time next day
			nextTime["value"] = min(actions)
			print("In exceptions: " + str(nextTime["value"]))

		print("Created dictionary of actions: " + str(actions))
		print("Next Time = " + str(nextTime["value"]))

		createTimer()	

def checkRuleTime(rule,ruleType):	

	now = datetime.now()

	currentTime = hour_to_number(now.hour,now.minute)

	if(rule["timeBegin"] < rule["timeEnd"]):
		if(currentTime >= rule["timeBegin"] and currentTime<= rule["timeEnd"]):
			if(ruleType == "send"):
				sendRule(rule)
			else if(ruleType == "delete"):
				mqttc.publish('delete',"{type = '"+str(rule['type']) + "',timeBegin="+str(rule['timeBegin'])+", timeEnd ="+str(rule['timeEnd'])+" }")
			return True
	else:
		if(currentTime >= rule["timeBegin"] or currentTime<= rule["timeEnd"]):
			if(ruleType == "send"):
				sendRule(rule)
			else if(ruleType == "delete"):
				
				mqttc.publish('delete',"{type = '"+str(rule['type']) + "',timeBegin="+str(rule['timeBegin'])+", timeEnd ="+str(rule['timeEnd'])+" }")
			return True

	return False

def createTimer():

	if(actionTimer["nextTimer"] != None):
		actionTimer["nextTimer"].cancel()

	now = datetime.now()

	print("Current time: "+ str(now.hour)+ "  " + str(now.minute))

	currentTime = hour_to_number(now.hour,now.minute)

	# print("Evaluating: " + str(currentTime) + "," + str(nextTime))

	if(nextTime["value"] > currentTime):
		totaltime = (nextTime["value"]-currentTime)*3600
		print("The subtraction is equal to: " + str(nextTime["value"]-currentTime))
		# actionTimer["nextTimer"].cancel()
		actionTimer["nextTimer"] = Timer(totaltime,executeTimer,[nextTime["value"]])
		actionTimer["nextTimer"].start()
		print("Created timer for: " + str(totaltime))
	else:
		totalTime = ((24-currentTime) + nextTime["value"])*3600
		actionTimer["nextTimer"] = Timer(totalTime,executeTimer,[nextTime["value"]])
		actionTimer["nextTimer"].start()
		print("Created timer for: " + str(totalTime))


def executeTimer(time):

	print("Executing timer all actions: " + str(actions))
	print("Executing timer for " + str(time) + " " +  str(actions[time]))

	if("ruleBegin" in actions[time]):
		for rule in actions[time]["ruleBegin"]:
			sendRule(rule)

	if("ruleDelete" in actions[time] ):
		for rule in actions[time]["ruleDelete"]:
			mqttc.publish('delete',"{type = '"+str(rule['type']) + "',timeBegin="+str(rule['timeBegin'])+", timeEnd ="+str(rule['timeEnd'])+" }")

	now = datetime.now()
	currentTime = hour_to_number(now.hour,now.minute)

	#try to get next time on the same day
	try:
		nextTime["value"] = min(time for time in actions if time > currentTime)
		createTimer()
	except ValueError:
		#get first time next day
		nextTime["value"] = min(actions)
		createTimer()



def hour_to_number(hour,minutes):
	print(str(hour) + str(minutes))
	return round(hour + minutes/60, 2)


@app.route('/<state>/<luminosity>/<rule>/<begin>/<end>', methods=['GET', 'POST'])
@app.route('/', methods=['GET', 'POST'])
def hello_world(state="init",luminosity=0,data={}):

	# luminosityUpdt = luminosity
	# stateUpdt = state
	# dataUpdt = data

	return render_template('index.html',**templateData);

@app.route('/deleteRule',methods=['GET', 'POST'])
def deleteRule():

	btn = request.form['btn']

	if(btn == 'all'):
		del rules[:]
		actionTimer["nextTimer"].cancel()
		nextTime["value"] = 100
		mqttc.publish('delete','all')
	
	else:
		removedRule = ast.literal_eval(request.form['btn']) 
		checkRuleTime(removedRule,"delete")
		rules.remove(removedRule)

	#delete rule from timer
	actions[removedRule["timeBegin"]]["ruleBegin"].remove(removedRule)
	actions[removedRule["timeEnd"]]["ruleDelete"].remove(removedRule)

	sameTimeBegin = False
	sameTimeEnd = False

	if(nextTime["value"]==removedRule["timeBegin"]):
		sameTimeBegin = True
		actionTimer["nextTimer"].cancel()

	if(nextTime["value"]==removedRule["timeEnd"] ):
		sameTimeEnd = True
		actionTimer["nextTimer"].cancel()

	# check if there are other rules for that specific time, if not, remove the entry
	if("ruleDelete" not in actions[removedRule["timeBegin"]]):
		if(len(actions[removedRule["timeBegin"]]["ruleBegin"]) == 0):
			del actions[removedRule["timeBegin"]]
			if(sameTimeBegin):
				now = datetime.now()
				currentTime = hour_to_number(now.hour,now.minute)
				try:
					nextTime["value"] = min(time for time in actions if time > currentTime)
					print("In try: " + str(nextTime["value"]))
				except ValueError:
					#get first time next day
					nextTime["value"] = min(actions)
					print("In exceptions: " + str(nextTime["value"]))

				createTimer()

	if("ruleBegin" not in actions[removedRule["timeEnd"]]):
		if(len(actions[removedRule["timeEnd"]]["ruleDelete"]) == 0):
			del actions[removedRule["timeEnd"]]
			if(sameTimeEnd):
				now = datetime.now()
				currentTime = hour_to_number(now.hour,now.minute)
				try:
					nextTime["value"] = min(time for time in actions if time > currentTime)
					print("In try: " + str(nextTime["value"]))
				except ValueError:
					#get first time next day
					nextTime["value"] = min(actions)
					print("In exceptions: " + str(nextTime["value"]))

				createTimer()


	fileNewRules = open('rules.txt','w')

	for rule in rules:
		fileNewRules.write(str(rule)+'\n')

	fileNewRules.close()

	templateData['luminosity']=luminosityUpdt["value"]
	
	return redirect('/')


@app.route('/new/',methods=['GET', 'POST'])
def new():

	btn = request.form['btn']

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
		conditions[str(conditionType)] = ast.literal_eval(request.form.get('conditionValue'))

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

		# return redirect(url_for('hello_world'))
			# return redirect(url_for('hello_world',state=str(state),luminosity=luminosityUpdt["value"]))
		# if(luminosityUpdt["value"] != 0):
		# 	return redirect(url_for('hello_world',luminosity=luminosityUpdt["value"],state=str(state)))
		# else:
		# 	return redirect(url_for('hello_world',state=str(state)))

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


		print("New Rule type: " + newRule["type"])

		newRuleCopy = copy.copy(newRule)

		rules.append(copy.copy(newRule))

		fileNewRules = open('rules.txt','w')

		for rule in rules:
			fileNewRules.write(str(rule)+'\n')

		fileNewRules.close()

		now = datetime.now()

		currentTime = hour_to_number(now.hour,now.minute)

		addRule(newRuleCopy)

		ruleSended = checkRuleTime(newRuleCopy,"send")

		if(nextTime["value"] < 100):

			if(ruleSended):
				if(nextTime["value"] > currentTime):
					if(timeEnd < nextTime["value"] and newRuleCopy["timeEnd"] > currentTime):
						nextTime["value"] = newRuleCopy["timeEnd"]
						createTimer()
				else:
					if(newRuleCopy["timeEnd"] < nextTime["value"]):
						nextTime["value"] = newRuleCopy["timeEnd"]
						createTimer()
			else:
				if(nextTime["value"] > currentTime):
					if(newRuleCopy["timeBegin"] < nextTime["value"] and newRuleCopy["timeBegin"] > currentTime):
						nextTime["value"] = newRuleCopy["timeBegin"]
						createTimer()
				else:
					if(newRuleCopy["timeBegin"] < nextTime["value"]):
						nextTime["value"] = newRuleCopy["timeBegin"]
						createTimer()
		else:
			if(ruleSended):
				nextTime["value"] = newRuleCopy["timeEnd"]
			else:
				nextTime["value"] = newRuleCopy["timeBegin"]

			print("Creating Timer for first Rule")

			createTimer()


		newRule["type"] = 'None'

		
		for key,value in conditions.items():
			conditions[key] = 'None'

		templateData['state']='init'

	elif(conditionTypes[btn]):
		conditions[btn] = 'None'
		templateData['state']='conditions'
		# templateData['rule']= ruleTypes[str(request.form.get('ruleType'))]
		# templateData['hourI']= hourBegin
		# templateData['hourE']= hourEnd
		# templateData['minI']= minuteBegin
		# templateData['minE']= minuteEnd

	templateData['luminosity']=luminosityUpdt["value"]
	templateData['lights']=lightsUpdt["value"]
	return redirect('/')

def sendRule(rule):
	ruleString = " { type = \"" + str(rule["type"]) + "\", timeBegin = " + str(rule["timeBegin"]) + ",timeEnd = "+ str(rule["timeEnd"]) + ", parameters = {"

	for key,value in rule["parameters"].items():
		if(value != 'None'):
			ruleString = ruleString + str(key) + "=" + str(value) + ","

	ruleString = ruleString + "} }"

	mqttc.publish('newRule',ruleString)


@socketio.on('my event')
def handle_my_custom_event(json):
    print('received json data here: ' + str(json))

@socketio.on('connect')
def test_connect():
	print('Im connecting')

	if(actionTimer["firstTime"]):
		print("this is the first time im connecting, will get rules")
		actionTimer["firstTime"] = False
		getRules()
	else:
		print("This is not the first time im connecting, wont get rules")


if __name__ == '__main__':
	socketio.run(app, host='0.0.0.0', port=8181, debug=True)