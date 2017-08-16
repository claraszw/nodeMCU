

// var newRuleFlag = false
// var newConditionFlag = false
// var 

// id="newRuleDiv"
// id="conditionsDiv"
// id="newConditionValueDiv"
// id="newConditionTypeDiv"

// id="hourDiv"

// newRuleButton
// id="newConditionButton"

var socket
   	new_rule="new rule"
   	new_condition = "new condition"
   	new_condition_type = "new condition type"
   	conditions = "conditions"
   	original="original"
   	changed = "changed"
   	init = "init"

function changeit(item){
	alert("on change!");
	item = changed;
	// {{testText}} = 'changed';
}

// function updateConditions(conditions){

// }

function evaluateHour(rules,ruleTypes){

	var selectedRule = document.getElementById('selectedRule').value;
	console.log()
	timeBegin = parseFloat(document.getElementById('hourI').value) + parseFloat(document.getElementById('minI').value/60) 
	timeEnd = parseFloat(document.getElementById('hourE').value) + parseFloat(document.getElementById('minE').value/60)
	console.log(selectedRule)
	var flag = true
	for(i=0; i<rules.length; i++){
		rule = rules[i]
		console.log(rule.type)
		console.log(rule.begin,rule.end,timeBegin,timeEnd)

		if(rule.type == selectedRule){

			if((rule.begin < timeBegin && timeBegin < rule.end) || (rule.begin<timeEnd && timeEnd < rule.end) || (timeBegin < rule.begin && timeEnd>rule.end)) {
				alert("Já existe uma regra desse tipo no intervalo escolhido. Por favor escolha outra regra ou outro horário.");

				return;
			}
		}
	}

	document.getElementById('rule-text').innerHTML = ruleTypes[selectedRule]
	document.getElementById('hourI-text').innerHTML = document.getElementById('hourI').value 
	document.getElementById('hourE-text').innerHTML = document.getElementById('hourE').value
	document.getElementById('minI-text').innerHTML = document.getElementById('minI').value
	document.getElementById('minE-text').innerHTML = document.getElementById('minE').value

	controlState('conditions');

}


function evaluateConditions(conditions,conditionTypes){
	var value = document.getElementById('conditionTypeSelected').value

	if(conditions[value] != 'None'){
		console.log("should alert")
		alert("Essa condição já existe nessa regra. Por favor escolha outra.");
	}
	else{
		document.getElementById('condition').innerHTML = conditionTypes[value];
		controlState('new condition type');
	}
}

function controlState(state){

	console.log("Received state!: " + state)

	if(state == "init"){
		document.getElementById('newRuleDiv').style.display = 'none'
		document.getElementById('hourDiv').style.display = 'none'
		document.getElementById('newRuleButtonsDiv').style.display = 'none'
		document.getElementById('conditionsDiv').style.display = 'none'
		document.getElementById('newConditionButton').style.display = 'none'
		document.getElementById('newConditionValueDiv').style.display = 'none'
		document.getElementById('newConditionTypeDiv').style.display = 'none'
		document.getElementById('evaluatedHour').style.display = 'none'
		document.getElementById('newRuleButton').style.display = 'block'
	}
	else if(state =="new rule" || state=="newRule"){
		console.log("In newRule!")
		document.getElementById('newRuleDiv').style.display = 'block'
		document.getElementById('hourDiv').style.display = 'block'
		document.getElementById('newRuleButton').style.display = 'none'
		document.getElementById('evaluatedHour').style.display = 'none'
		document.getElementById('newConditionTypeDiv').style.display = 'none'
	}
	else if(state == "conditions"){
		document.getElementById('newRuleButton').style.display = 'none'
		document.getElementById('evaluatedHour').style.display = 'block'
		document.getElementById('newRuleButtonsDiv').style.display = 'block'
		document.getElementById('conditionsDiv').style.display = 'block'
		document.getElementById('newConditionButton').style.display = 'block'
		document.getElementById('newRuleDiv').style.display = 'none'
		document.getElementById('hourDiv').style.display = 'none'
		document.getElementById('newConditionTypeDiv').style.display = 'none'
		document.getElementById('newConditionValueDiv').style.display = 'none'
	}
	else if(state == "new condition"){
		document.getElementById('newConditionTypeDiv').style.display = 'block'
		document.getElementById('newConditionButton').style.display = 'none'
	}
	else if(state =="new condition type"){
		document.getElementById('newConditionButton').style.display = 'none'
		document.getElementById('newConditionTypeDiv').style.display = 'none'
		document.getElementById('newConditionValueDiv').style.display = 'block'
	}

}