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

# The callback for when a PUBLISH message is received from the ESP8266.
def on_message(client, userdata, message):
    #socketio.emit('my variable')
    print("Received message '" + str(message.payload) + "' on topic '"
        + message.topic + "' with QoS " + str(message.qos))

    if message.topic == "luminosityUpdt":
        print("luminosity update")
        luminosityUpdt["value"] = message.payload;
        socketio.emit('luminosity', {'data': message.payload})


mqttc=mqtt.Client()
mqttc.on_connect = on_connect
mqttc.on_message = on_message
mqttc.connect("localhost",1883,60)
mqttc.loop_start()



ruleTypes = [{'label': "Acender Luzes", 'value': "lightsOn"}, {'label': "Apagar Luzes", 'value': "lightsOff" } ]

conditionTypes = [{'label': "Luminosidade Abaixo De", 'value': "lowerBoundLight"},{'label': "Luminosidade Acima De", 'value': "upperBoundLight"}]
conditionsMessages = {}
conditionsMessages["lowerBoundLight"] = "Luminosidade Abaixo De "
conditionsMessages["upperBoundLight"] = "Luminosidade Acima De: "
condition = {}
conditions = []

rules = []

newRule = {}

newFlags = {}
newFlags["rule"]=False
newFlags["condition"]=False
newFlags["conditionType"]=False

luminosityUpdt = {}
luminosityUpdt["value"] = 0

teste = {'data': 5}


@app.route('/<luminosity>')
@app.route('/')
def hello_world(luminosity=0):

	luminosityUpdt = luminosity

	return render_template('index.html', async_mode=socketio.async_mode, newFlags=newFlags,ruleTypes=ruleTypes,conditionTypes=conditionTypes,conditionsMessages=conditionsMessages,condition=condition,conditions=conditions,rules=rules,luminosity=luminosityUpdt,teste=teste)

@app.route('/deleteRule',methods=['GET', 'POST'])
def deleteRule():

	 rules.remove(ast.literal_eval(request.form['btn']))

	 if(luminosityUpdt["value"] != 0):
	 	return redirect(url_for('hello_world',luminosity=luminosityUpdt["value"]))
	 else:
		return redirect('/')


@app.route('/new/',methods=['GET', 'POST'])
def new():

	btn = request.form['btn']

	if(btn=="condition" or btn=="conditionType" or btn=="rule"):
		newFlags[btn]  = True

		if(btn == 'conditionType'):
			condition["label"] = ast.literal_eval(request.form.get('conditionType'))["label"]
			condition["type"] = ast.literal_eval(request.form.get('conditionType'))["value"]

	if(btn=="conditionTypeBack"):
		newFlags["condition"]=False
		newFlags["conditionType"]=False

	if(btn=="conditionValueBack"):
		newFlags["conditionType"]=False

	if(btn=="cancelCreateRule"):

		newFlags["condition"]=False
		newFlags["conditionType"]=False
		newFlags["rule"]=False
		del conditions[:]
		if(luminosityUpdt["value"] != 0):
			return redirect(url_for('hello_world',luminosity=luminosityUpdt["value"]))
		else:
			return redirect('/')

	if(btn == "createCondition"):
		condition["value"] = request.form.get('conditionValue')
		conditions.append(copy.copy(condition))
		newFlags["condition"]=False
		newFlags["conditionType"]=False

	if(btn == "createRule"):
		newRule["type"] = ast.literal_eval(request.form.get('ruleType'))
		newRule["parameters"] = copy.copy(conditions)
		rules.append(copy.copy(newRule))

		ruleString = " { type = { value ='" + str(newRule["type"]["value"]) + "', label='"+ str(newRule["type"]["label"])+"'}, parameters = {"

		for parameter in newRule["parameters"]:
			ruleString = ruleString + str(parameter["type"]) + "=" + str(parameter["value"]) + ","

		ruleString = ruleString + "} }"
		mqttc.publish('newRule',ruleString)
		
		del conditions[:]

		newFlags["condition"]=False
		newFlags["conditionType"]=False
		newFlags["rule"]=False

		if(luminosityUpdt["value"] != 0):
			return redirect(url_for('hello_world',luminosity=luminosityUpdt["value"]))
		else:
			return redirect('/')

	return render_template('index.html',async_mode=socketio.async_mode,newFlags=newFlags,ruleTypes=ruleTypes,conditionTypes=conditionTypes,conditionsMessages=conditionsMessages,condition=condition,conditions=conditions,rules=rules,luminosity=luminosityUpdt["value"])

@socketio.on('my event')
def handle_my_custom_event(json):
    print('received json data here: ' + str(json))

# @socketio.on('delete')
# def deleteRule (json):



if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=8181, debug=True)