from flask import Flask, render_template, request, redirect
from flask_socketio import SocketIO, emit
import paho.mqtt.client as mqtt
import copy
app = Flask(__name__)


app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app)

# The callback for when the client receives a CONNACK response from the server.
def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))

    # Subscribing in on_connect() means that if we lose the connection and
    # reconnect then subscriptions will be renewed.
    client.subscribe("luminosity")

# The callback for when a PUBLISH message is received from the ESP8266.
def on_message(client, userdata, message):
    #socketio.emit('my variable')
    print("Received message '" + str(message.payload) + "' on topic '"
        + message.topic + "' with QoS " + str(message.qos))

    if message.topic == "luminosity":
        print("luminosity update")
        socketio.emit('luminosity', {'data': message.payload})

mqttc=mqtt.Client()
mqttc.on_connect = on_connect
mqttc.on_message = on_message
mqttc.connect("localhost",1883,60)
mqttc.loop_start()



ruleTypes = [{'label': "Acender Luzes", 'value': "lightsOn"}, {'label': "Apaga Luzes", 'value': "lightsOff" } ]

conditionTypes = [{'label': "Luminosidade Minima", 'value': "lowerBound"},{'label': "Luminosidade Maxima", 'value': "upperBound"}]
conditionsMessages = {}
conditionsMessages["Luminosidade Minima"] = "Luminosidade Acima De: "
conditionsMessages["Luminosidade Maxima"] = "Luminosidade Abaixo De: "
condition = {}
conditions = []

rules = []

newRule = {}

newFlags = {}
newFlags["rule"]=False
newFlags["condition"]=False
newFlags["conditionType"]=False


@app.route('/')
def hello_world():
    return render_template('index.html', async_mode=socketio.async_mode, newFlags=newFlags,ruleTypes=ruleTypes,conditionTypes=conditionTypes,conditionsMessages=conditionsMessages,condition=condition,conditions=conditions,rules=rules)

@app.route('/new/',methods=['GET', 'POST'])
def new():

	btn = request.form['btn']

	if(btn=="condition" or btn=="conditionType" or btn=="rule"):
		newFlags[btn]  = True

		if(btn == 'conditionType'):
			condition["type"] = request.form.get('conditionType')

	if(btn == "createCondition"):
		condition["value"] = request.form.get('conditionValue')
		conditions.append(copy.copy(condition))
		newFlags["condition"]=False
		newFlags["conditionType"]=False

	if(btn == "createRule"):
		newRule["type"] = request.form.get('ruleType')
		newRule["parameters"] = copy.copy(conditions)
		rules.append(copy.copy(newRule))

		ruleString = str(newRule["type"]) + " = {"

		for parameter in newRule["parameters"]:
			ruleString = ruleString + str(parameter["type"]) + "=" + str(parameter["value"]) + ","

		ruleString = ruleString + "}"
		mqttc.publish('newRule',ruleString)

	return render_template('index.html',async_mode=socketio.async_mode,newFlags=newFlags,ruleTypes=ruleTypes,conditionTypes=conditionTypes,conditionsMessages=conditionsMessages,condition=condition,conditions=conditions,rules=rules)

@socketio.on('my event')
def handle_my_custom_event(json):
    print('received json data here: ' + str(json))


if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=8181, debug=True)