

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

var currentSelectedRule
var currentSelectedCondition

function checkSameTime(rules,ruleTypes){

	var selectedRule = document.getElementById('selectedRule').value;
	timeBegin = parseFloat(document.getElementById('hourI').value) + parseFloat(document.getElementById('minI').value/60) 
	timeEnd = parseFloat(document.getElementById('hourE').value) + parseFloat(document.getElementById('minE').value/60)
	console.log(selectedRule)
	var flag = true
	for(i=0; i<rules.length; i++){
		rule = rules[i]
		console.log(rule.type)
		console.log(rule.timeBegin,rule.timeEnd,timeBegin,timeEnd)

		if(rule.type == selectedRule){
			if((rule.timeBegin <= timeBegin && timeBegin <= rule.timeEnd) || (rule.timeBegin <= timeEnd && timeEnd <= rule.timeEnd) || (timeBegin <= rule.timeBegin && timeEnd >= rule.timeEnd)) {
				if(selectedRule == "controlTemperature"){
					return true;
				}
				else{
					var value = document.getElementById('conditionTypeSelected').value
					if(rule.parameters[value] != 'None'){
						return true;
					}
				}
			}
		}
	}
}

function evaluateHour(rules,ruleTypes){

	var selectedRule = document.getElementById('selectedRule').value;
	var hourI = document.getElementById('hourI').value;
	var hourE = document.getElementById('hourE').value;
	var minI = document.getElementById('minI').value;
	var minE = document.getElementById('minE').value;

	if(hourI > 23 || hourE > 23 || minI > 59 || minE > 59){
		alert("Por Favor Escolha um Horário Válido");
		return
	}

	if(selectedRule == "controlTemperature"){
		if(checkSameTime(rules,ruleTypes)){
			alert("Já existe uma temperatura para esse horário. Por favor escolha outro horário ou outra regra");
			return;
		}
		else{

		}
	}

	currentSelectedRule = selectedRule
	document.getElementById('rule-text').innerHTML = ruleTypes[selectedRule]
	document.getElementById('hourI-text').innerHTML = document.getElementById('hourI').value 
	document.getElementById('minE-text').innerHTML = document.getElementById('hourE').value
	document.getElementById('minI-text').innerHTML = document.getElementById('minI').value
	document.getElementById('minE-text').innerHTML = document.getElementById('minE').value
	controlState('conditions');
}


function evaluateConditions(rules,ruleTypes,conditions,conditionTypes){
	var value = document.getElementById('conditionTypeSelected').value
	var selectedRule = document.getElementById('selectedRule').value;

	if(selectedRule == "lightsOn"){
		if(checkSameTime(rules,ruleTypes)){
			alert("Essa condição já existe para essa regra nesse horário. Por favor escolha outra.");
			return;
		}
	}

	if(conditions[value] != 'None'){
		alert("Essa condição já existe nessa regra. Por favor escolha outra.");
	}
	else{
		document.getElementById('condition').innerHTML = conditionTypes[value];
		currentSelectedCondition = value;
		console.log(value)
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
		if(document.getElementById('rule-text').innerHTML == "Manter Temperatura"){
			document.getElementById('temperature').style.display = 'block'
		}
		else if(document.getElementById('rule-text').innerHTML == "Acender Luzes"){
			document.getElementById('temperature').style.display = 'none'
		}
	}
	else if(state == "new condition"){
		document.getElementById('newConditionTypeDiv').style.display = 'block'
		document.getElementById('newConditionButton').style.display = 'none'
		document.getElementById('newConditionValueDiv').style.display = 'none'
	}
	else if(state =="new condition type"){
		console.log(currentSelectedCondition)
		if(currentSelectedCondition == 'window' || currentSelectedCondition == 'door'){
			document.getElementById('input-value').style.display = 'none'
			document.getElementById('boolean-value').style.display = 'none'
			document.getElementById('open-close').style.display = 'block'
		}
		else if(currentSelectedCondition == 'presence'){
			document.getElementById('input-value').style.display = 'none'
			document.getElementById('boolean-value').style.display = 'block'
			document.getElementById('open-close').style.display = 'none'
		}
		else{
			document.getElementById('input-value').style.display = 'block'
			document.getElementById('boolean-value').style.display = 'none'
			document.getElementById('open-close').style.display = 'none'
		}
		document.getElementById('newConditionButton').style.display = 'none'
		document.getElementById('newConditionTypeDiv').style.display = 'none'
		document.getElementById('newConditionValueDiv').style.display = 'block'
	}

}