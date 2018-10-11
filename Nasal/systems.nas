var altAlertModeSwitch = func {
	var warning_b = getprop("/b737/warnings/altitude-alert-b-conditions");
	var diff_0 = getprop("/b737/helpers/alt-diff-ft[0]");
	var diff_1 = getprop("/b737/helpers/alt-diff-ft[1]");

	if (warning_b) {
		var diff = diff_1;
	} else {
		var diff = diff_0;
	}

	if (diff < 600) {
		setprop("/b737/warnings/altitude-alert-mode", 1);
	} else {
		setprop("/b737/warnings/altitude-alert-mode", 0);
	}
}
setlistener( "/b737/warnings/altitude-alert", altAlertModeSwitch, 0, 0);

var gearlvr = getprop("/b737/controls/gear/lever");
var airgnd = getprop("/b737/sensors/air-ground");

setlistener("/b737/controls/gear/lever", func {
	gearlvr = getprop("/b737/controls/gear/lever");
	wow = getprop("/gear/gear[1]/wow");
	if (gearlvr == 0 and !wow) {  # in air, put gear down
		setprop("/controls/gear/gear-down", 1);
	} else if (gearlvr == 1 and !wow) { # in air put gear up
		setprop("/controls/gear/gear-down", 0);
	} else if (gearlvr == 1 or gearlvr == 2 and wow) { # on ground inhibit lever movement. 
		setprop("/controls/gear/gear-down", 1);
		setprop("/b737/controls/gear/lever", 0);
	} 
});