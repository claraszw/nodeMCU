#################
#### imports ####
#################
 
from flask import Flask
from flask_socketio import SocketIO
 
 
################
#### config ####
################
 
app = Flask(__name__, instance_relative_config=True)
socketio = SocketIO(app)
#app.config.from_pyfile('flask.cfg')
 
 
####################
#### blueprints ####
####################

from project.room514.views import index as room514_start
from project.room514.views import room514_blueprint
from project.room516.views import room516_blueprint
from project.menu.views import menu_blueprint
 
# register the blueprints
app.register_blueprint(room514_blueprint)
app.register_blueprint(room516_blueprint)
app.register_blueprint(menu_blueprint)

socketio.run(app, host='0.0.0.0', port=5000, debug=True)
