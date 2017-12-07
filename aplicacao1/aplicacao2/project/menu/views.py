# project/menu/views.py
 
#################
#### imports ####
#################
 
from flask import render_template, Blueprint
#import project.room514
 
################
#### config ####
################
 
menu_blueprint = Blueprint('menu', __name__, template_folder='templates')
 
 
################
#### routes ####
################
 
@menu_blueprint.route('/')
def index():
	print("in menu render")
	return render_template('menu.html')
