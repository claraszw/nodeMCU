from flask import Flask
import room514
from flask import Flask, render_template, request, redirect, url_for
from flask_socketio import SocketIO, emit

app = Flask(__name__)
app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app)


if __name__ == '__main__':
	socketio.run(app, host='0.0.0.0', port=8181, debug=True)

# app.register_blueprint(room514.room514)

print(room514.potato)

@app.route('/')
def hello():
	return render_template('begin.html') 

@app.route('/pressed',methods=['GET', 'POST'])
def pressed():
	return redirect('/514')