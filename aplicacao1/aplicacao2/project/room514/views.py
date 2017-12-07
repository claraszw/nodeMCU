# project/room514/views.py
 
#################
#### imports ####
#################
 
from flask import render_template, Blueprint
 
 
################
#### config ####
################
 
room514_blueprint = Blueprint('room514', __name__, template_folder='templates')
 
 
################
#### routes ####
################
 
@room514_blueprint.route('/514',methods=['GET', 'POST'])
def index():
    return render_template('room514.html')
