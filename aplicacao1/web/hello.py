from flask import Flask, render_template, request, redirect, url_for
from flask_socketio import SocketIO, emit
import paho.mqtt.client as mqtt
import copy, ast
app = Flask(__name__)


app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app)

# The callback for when the client receives a CONNACK response from the server.
def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))

    # Subscribing in on_connect() means that if we lose the connection and
    # reconnect then subscriptions will be renewed.
    client.subscribe("luminosityUpdt")
    client.subscribe("lightsUpdt")

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


mqttc=mqtt.Client()
mqttc.on_connect = on_connect
mqttc.on_message = on_message
mqttc.connect("localhost",1883,60)
mqttc.loop_start()


ruleTypes = {"lightsOn":"Acender Luzes", "lightsOff":"Apagar Luzes"}
conditionTypes = {"lowerBoundLight": "Luminosidade Abaixo De","upperBoundLight": "Luminosidade Acima De"}

condition = {}
conditions = {"lowerBoundLight": 'None',"upperBoundLight":'None'}

rules = []

newRule = {}

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
		mqttc.publish('delete','all')
	
	else:
		removedRule = ast.literal_eval(request.form['btn']) 
		rules.remove(removedRule)
		mqttc.publish('delete',"{type = '"+str(removedRule['type']) + "',timeBegin="+str(removedRule['timeBegin'])+", timeEnd ="+str(removedRule['timeEnd'])+" }")


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
		# templateData['luminosity']=luminosityUpdt["value"]
		
		# return redirect('/')

	elif(btn == "createCondition"):

		conditionType = request.form.get('conditionType')
		conditions[str(conditionType)] = ast.literal_eval(request.form.get('conditionValue'))

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

		templateData['state']='conditions'
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

		conditionsEmpty = True

		for key,value in conditions.items():
			if(value != 'None'):
				conditionsEmpty = False

		if(conditionsEmpty):
				
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


		rules.append(copy.copy(newRule))

		ruleString = " { type = \"" + str(newRule["type"]) + "\", timeBegin = " + str(newRule["timeBegin"]) + ",timeEnd = "+ str(newRule["timeEnd"]) + ", parameters = {"

		for key,value in newRule["parameters"].items():
			if(value != 'None'):
				# ruleString = ruleString + str(key) + "=\"" + str(value) + "\","
			# else:
				ruleString = ruleString + str(key) + "=" + str(value) + ","

		ruleString = ruleString + "} }"
		mqttc.publish('newRule',ruleString)
		
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

@socketio.on('my event')
def handle_my_custom_event(json):
    print('received json data here: ' + str(json))

def hour_to_number(hour,minutes):
	print(str(hour) + str(minutes))
	return hour + minutes/60


if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=8181, debug=True)