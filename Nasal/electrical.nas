# 737-800 Electrical System
# Joshua Davidson (it0uchpods)

#############
# Init Vars #
#############

var ac_volt_std = 115;
var ac_volt_min = 110;
var dc_volt_std = 28;
var dc_volt_min = 25;

setlistener("/sim/signals/fdm-initialized", func {
	elec_init();
	
	var battery_on = getprop("/controls/electrical/battery-switch");
	var extpwr_on = getprop("/services/ext-pwr/enable");
	var ext = getprop("/controls/electrical/ext/sw");
	var emerpwr_on = getprop("/controls/electrical/emerpwr");
	var acxtie = getprop("/controls/electrical/xtie/acxtie");
	var dcxtie = getprop("/controls/electrical/xtie/dcxtie");
	var xtieL = getprop("/controls/electrical/xtie/xtieL");
	var xtieR = getprop("/controls/electrical/xtie/xtieR");
	var rpmapu = getprop("/systems/apu/rpm");
	var bustransfersw = getprop("/controls/electrical/bus-transfer-sw");
	var apuL = getprop("/controls/electrical/apu/Lsw");
	var apuR = getprop("/controls/electrical/apu/Rsw");
	var engL = getprop("/controls/electrical/eng/Lsw");
	var engR = getprop("/controls/electrical/eng/Rsw");
	var rpmL = getprop("/engines/engine[0]/n2");
	var rpmR = getprop("/engines/engine[1]/n2");
	var sourceL = getprop("/systems/electrical/sourceL");
	var sourceR = getprop("/systems/electrical/sourceR");
	var galyABshed = getprop("/systems/electrical/shed/galyAB");
	var galyCDshed = getprop("/systems/electrical/shed/galyCD");
	var mainAC1shed = getprop("/systems/electrical/shed/mainAC1");
	var mainAC2shed = getprop("/systems/electrical/shed/mainAC2");
	var stbyPwSw = getprop("/controls/electrical/stby-pw-sw");
	var batOnly = 0;
	var crossbus = getprop("/controls/electrical/crossbus");
});

######################
# Classes and Hashes #
######################

var electricSource = {
	name: "",
	property: "",
	minValue: 0,
	volts: 0,
	type: "",
	updateVolts: func() {
		volts = 0;
		if (getprop(me.property) >= me.minValue and me.type == "AC") {
			volts = ac_volt_std;
		} elsif (getprop(me.property) >= me.minValue and me.type == "DC") {
			volts = dc_volt_std;
		}
		return volts;
	},
	new: func(name,property,minValue,volts,type) {
		var s = {parents:[electricSource]};
		s.name = name;
		s.property = property;
		s.minValue = minValue;
		s.volts = volts;
		s.type = type;
		return s;
	}
};

var electricBus = {
	name: "",
	type: "",
	volts: 0,
	new: func(name,type,volts) {
		var b = {parents:[electricBus]};
		b.name = name;
		b.type = type;
		b.volts = volts;
		return b;
	}
};

var electricRelay = {
	name: "",
	state: 0, # 0 = open, 1 = closed
	relayClose: func() {
		if (me.state == 1) {return;}
		settimer(func() {
			me.state = 1;
		}, 0.2);
	},
	relayOpen: func() {
		if (me.state == 0) {return;}
		settimer(func() {
			me.state = 0;
		}, 0.2);
	},
	new: func(name,state) {
		var r = {parents:[electricRelay]};
		r.name = name;
		r.state = state;
		return r;
	}
};

var ac_electricSources = [
	electricSource.new("engL", "/systems/electrical/gen1-avail", 1, 0, "AC"),
	electricSource.new("engR", "/systems/electrical/gen2-avail", 1, 0, "AC"),
	electricSource.new("apu", "/systems/apu/rpm", 94.9, 0, "AC"),
	electricSource.new("ext", "/controls/electrical/extpwr-avail", 1, 0, "AC"),
	
	# the below are not really sources, but you could call them sources which source power from another part of the electrical system
	electricSource.new("INV", "/systems/electrical/stat-inv-avail", 1, 0, "AC")
];

var dc_electricSources = [
	electricSource.new("battery", "/systems/electrical/battery-avail", 1, 0, "DC"),
	electricSource.new("aux-battery", "/systems/electrical/aux-battery-avail", 1, 0, "DC"),
	
	# the below are not really sources, but you could call them sources which source power from another part of the electrical system
	electricSource.new("TR1", "/systems/electrical/tr1-avail", 1, 0, "DC"),
	electricSource.new("TR2", "/systems/electrical/tr2-avail", 1, 0, "DC"),
	electricSource.new("TR3", "/systems/electrical/tr3-avail", 1, 0, "DC")
];

var ac_electricBuses = [
	electricBus.new("TRANS1", "AC", 0),
	electricBus.new("TRANS2", "AC", 0),
	electricBus.new("AC1", "AC", 0),
	electricBus.new("AC2", "AC", 0),
	electricBus.new("GALYAB", "AC", 0),
	electricBus.new("GALYCD", "AC", 0),
	electricBus.new("GNDSVC1", "AC", 0),
	electricBus.new("GNDSVC2", "AC", 0),
	electricBus.new("ACSTBY", "AC", 0)
];

var dc_electricBuses = [
	electricBus.new("DC1", "DC", 0),
	electricBus.new("DC2", "DC", 0),
	electricBus.new("DCSTBY", "DC", 0),
	electricBus.new("BAT", "DC", 0),
	electricBus.new("HOTBAT", "DC", 0),
	electricBus.new("HOTBATSW", "DC", 0)
];

var relays = [
	electricRelay.new("BTB1", 0),
	electricRelay.new("BTB2", 0),
	electricRelay.new("GCB1", 0),
	electricRelay.new("GCB2", 0),
	electricRelay.new("GCBAPU", 0),
	electricRelay.new("GCBEXT", 0),
	electricRelay.new("GNDSVC1", 1),
	electricRelay.new("GNDSVC2", 1),
	electricRelay.new("XBUSTIE", 0)
];

########################
# Switches / Listeners #
########################

var connectSource = func(type,side) {
	if ((type == "apuL" or type == "apuR" or type == "ext") and side == "B") {
		setprop("/systems/electrical/sourceL", ""); 
		setprop("/systems/electrical/sourceR", ""); 
		# Whichever source is selected last powers both busses. It is not possible to power one transfer bus with external power and one transfer bus with APU power.
		settimer(func() {
			setprop("/systems/electrical/sourceL", type); 
			setprop("/systems/electrical/sourceR", type); 
		}, 0.1);
	} else {
		setprop("/systems/electrical/source"~side, ""); 
		settimer(func() {
			setprop("/systems/electrical/source"~side, type); 
		}, 0.1);
	}
	# The source of AC power being connected to a generator bus takes priority and automatically disconnects the existing source.
}

var disconnectSource = func(side) {
	if (side == "B") {
		settimer(func() {
			setprop("/systems/electrical/sourceL", ""); 
			setprop("/systems/electrical/sourceR", ""); 
		}, 0.1);
	} else {
		settimer(func() {
			setprop("/systems/electrical/source"~side, "");
		}, 0.1);
	}
}

var switchListener = func(property,type,side) {
	setlistener(property, func {
		if (getprop(property) == 0) {return;}
		if (getprop(property) == 1) {
			connectSource(type,side);
		} elsif (getprop(property) == -1) {
			disconnectSource(side);
		}
	}, 0, 0);
}

switchListener("/controls/electrical/eng/Lsw", "engL", "L");
switchListener("/controls/electrical/eng/Rsw", "engR", "R");
switchListener("/controls/electrical/apu/Lsw", "apuL", "B");
switchListener("/controls/electrical/apu/Rsw", "apuR", "B");
switchListener("/controls/electrical/ext/sw",  "ext",  "B");

######################
# Helper Functions   #
######################

var writeBus = func (bus, volts) {
	setprop("/systems/electrical/bus/"~bus, volts);
}

var writeProperties = func() {
	foreach (var dc; dc_electricBuses) {
		writeBus(dc.name, dc.volts);
	}
	
	foreach (var ac; ac_electricBuses) {
		writeBus(ac.name, ac.volts);
	}
	
	foreach (var ACsources; ac_electricSources) {
		volts = ACsources.updateVolts();
		setprop("systems/electrical/sources/"~ACsources.name, volts);
		ACsources.volts = volts;
	}
	
	foreach (var DCsources; dc_electricSources) {
		volts = DCsources.updateVolts();
		setprop("systems/electrical/sources/"~DCsources.name, volts);
		DCsources.volts = volts;
	}
	
	foreach (var relay; relays) {
		setprop("systems/electrical/relays/"~relay.name, relay.state)
	}
}

######################
# Main Electric Loop #
######################

var master_elec_loop = func {
	######################
	# AC System          #
	######################
	
	sourceL = getprop("/systems/electrical/sourceL");
	sourceR = getprop("/systems/electrical/sourceR");
	apuL = getprop("/controls/electrical/apu/Lsw");
	apuR = getprop("/controls/electrical/apu/Rsw");
	engL = getprop("/controls/electrical/eng/Lsw");
	engR = getprop("/controls/electrical/eng/Rsw");
	rpmapu = getprop("/systems/apu/rpm");
	
	# TRANS 1 Bus
	if (sourceL == "ext" and relays[0].state == 1) {
		ac_electricBuses[0].volts = ac_electricSources[3].volts;
	} elsif ((sourceL == "apuL" or sourceL == "apuR") and relays[0].state == 1) {
		ac_electricBuses[0].volts = ac_electricSources[2].volts;
	} elsif (sourceL == "engL" and relays[2].state == 1) {
		ac_electricBuses[0].volts = ac_electricSources[0].volts;
	} elsif (relays[0].state == 1 and relays[1].state == 1 and ac_electricBuses[1].volts >= ac_volt_min) {
		ac_electricBuses[0].volts = ac_electricBuses[1].volts;
	} else {
		ac_electricBuses[0].volts = 0;
	}
	
	if (ac_electricBuses[0].volts >= ac_volt_min) {
		setprop("/systems/electrical/trans1-avail", 1);
	} else {
		setprop("/systems/electrical/trans1-avail", 0);
	}
	
	# TRANS 2 Bus
	if (sourceR == "ext" and relays[1].state == 1) {
		ac_electricBuses[1].volts = ac_electricSources[3].volts;
	} elsif ((sourceR == "apuL" or sourceR == "apuR") and relays[1].state == 1) {
		ac_electricBuses[1].volts = ac_electricSources[2].volts;
	} elsif (sourceR == "engR" and relays[3].state == 1) {
		ac_electricBuses[1].volts = ac_electricSources[1].volts;
	} elsif (relays[0].state == 1 and relays[1].state == 1 and ac_electricBuses[0].volts >= ac_volt_min) {
		ac_electricBuses[1].volts = ac_electricBuses[0].volts;
	} else {
		ac_electricBuses[1].volts = 0;
	}
	
	if (ac_electricBuses[1].volts >= ac_volt_min) {
		setprop("/systems/electrical/trans2-avail", 1);
	} else {
		setprop("/systems/electrical/trans2-avail", 0);
	}
	
	mainAC1shed = getprop("/systems/electrical/shed/mainAC1");
	mainAC2shed = getprop("/systems/electrical/shed/mainAC2");
	
	# MAIN AC Bus 1
	if (ac_electricBuses[0].volts >= ac_volt_min and mainAC1shed != 1) {
		ac_electricBuses[2].volts = ac_electricBuses[0].volts;
	} else {
		ac_electricBuses[2].volts = 0;
	}
	
	if (ac_electricBuses[2].volts >= ac_volt_min) {
		setprop("/systems/electrical/ac1-avail", 1);
	} else {
		setprop("/systems/electrical/ac1-avail", 0);
	}
	
	# MAIN AC Bus 2
	if (ac_electricBuses[1].volts >= ac_volt_min and mainAC2shed != 1) {
		ac_electricBuses[3].volts = ac_electricBuses[1].volts;
	} else {
		ac_electricBuses[3].volts = 0;
	}
	
	if (ac_electricBuses[3].volts >= ac_volt_min) {
		setprop("/systems/electrical/ac2-avail", 1);
	} else {
		setprop("/systems/electrical/ac2-avail", 0);
	}
	
	galyABshed = getprop("/systems/electrical/shed/galyAB");
	galyCDshed = getprop("/systems/electrical/shed/galyCD");
	galySw = getprop("/controls/electrical/galley");
	
	# GALY A/B Bus
	if (ac_electricBuses[1].volts >= ac_volt_min and galyABshed != 1 and galySw == 1) {
		ac_electricBuses[4].volts = ac_electricBuses[1].volts;
	} else {
		ac_electricBuses[4].volts = 0;
	}
	
	if (ac_electricBuses[4].volts >= ac_volt_min) {
		setprop("/systems/electrical/ac-galyab-avail", 1);
	} else {
		setprop("/systems/electrical/ac-galyab-avail", 0);
	}
	
	# GALY A/B Bus
	if (ac_electricBuses[0].volts >= ac_volt_min and galyCDshed != 1 and galySw == 1) {
		ac_electricBuses[5].volts = ac_electricBuses[0].volts;
	} else {
		ac_electricBuses[5].volts = 0;
	}
	
	if (ac_electricBuses[5].volts >= ac_volt_min) {
		setprop("/systems/electrical/ac-galycd-avail", 1);
	} else {
		setprop("/systems/electrical/ac-galycd-avail", 0);
	}
	
	# GALY Shedding
	if ((getprop("/systems/electrical/gen1-avail") == 1 and getprop("/systems/electrical/gen2-avail") == 0) or (getprop("/systems/electrical/gen1-avail") == 0 and getprop("/systems/electrical/gen2-avail") == 1)) {
		setprop("/systems/electrical/shed/galyAB", 1);
		setprop("/systems/electrical/shed/galyCD", 1);
	} else {
		setprop("/systems/electrical/shed/galyAB", 0);
		setprop("/systems/electrical/shed/galyCD", 0);
	}
	
	# GND SVC Switch: bypass GND PWR switch in cockpit
	# We don't have a cabin crew station so this will never happen, but I'll code it anyway...
	if (getprop("/controls/electrical/gnd-svc-switch") == 1 and (ac_electricBuses[0].volts >= ac_volt_min and ac_electricBuses[1].volts >= ac_volt_min)) {
		setprop("/controls/electrical/gnd-svc-switch", 0);
	}
	
	# GND SVC Relays
	if (getprop("/controls/electrical/gnd-svc-switch") == 1 and getprop("/services/ext-pwr/enable") == 1) {
		relays[6].relayOpen();
		relays[7].relayOpen();
	} else {
		relays[6].relayClose();
		relays[7].relayClose();
	}
	
	# GND SVC Bus 1
	if (relays[6].state == 1 and ac_electricBuses[0].volts >= ac_volt_min) {
		ac_electricBuses[6].volts = ac_volt_std;
	} elsif (relays[6].state == 0 and getprop("/services/ext-pwr/enable") == 1) {
		ac_electricBuses[6].volts = ac_volt_std;
	} else {
		ac_electricBuses[6].volts = 0;
	}
	
	if (ac_electricBuses[6].volts >= ac_volt_min) {
		setprop("/systems/electrical/ac-gndsvc1-avail", 1);
	} else {
		setprop("/systems/electrical/ac-gndsvc1-avail", 0);
	}
	
	# GND SVC Bus 2
	if (relays[7].state == 1 and ac_electricBuses[1].volts >= ac_volt_min) {
		ac_electricBuses[7].volts = ac_volt_std;
	} elsif (relays[7].state == 0 and getprop("/services/ext-pwr/enable") == 1) {
		ac_electricBuses[7].volts = ac_volt_std;
	} else {
		ac_electricBuses[7].volts = 0;
	}
	
	if (ac_electricBuses[7].volts >= ac_volt_min) {
		setprop("/systems/electrical/ac-gndsvc2-avail", 1);
	} else {
		setprop("/systems/electrical/ac-gndsvc2-avail", 0);
	}
	
	stbyPwSw = getprop("/controls/electrical/stby-pw-sw");
	
	# STBY AC Bus
	if (stbyPwSw != 0) {
		if (ac_electricBuses[0].volts >= ac_volt_min and stbyPwSw == 1) {
			ac_electricBuses[8].volts = ac_electricBuses[0].volts;
		} elsif ((ac_electricSources[4].volts >= ac_volt_min and stbyPwSw == 1 and getprop("/systems/electrical/stbyMode") == 1) or stbyPwSw == -1) {
			ac_electricBuses[8].volts = ac_electricSources[4].volts;
		} else {
			ac_electricBuses[8].volts = 0;
		}
	} elsif (stbyPwSw == 0) {
		ac_electricBuses[8].volts = 0;
	}
	
	if (ac_electricBuses[8].volts >= ac_volt_min) {
		setprop("/systems/electrical/ac-stby-avail", 1);
	} else {
		setprop("/systems/electrical/ac-stby-avail", 0);
	}
	
	# Bus Transfer logic
	bustransfersw = getprop("/controls/electrical/bus-transfer-sw");
	crossbus = getprop("/controls/electrical/crossbus");
	
	if (ac_electricBuses[0].volts < ac_volt_min and ac_electricBuses[1].volts >= ac_volt_min and sourceL == "") {
		setprop("/controls/electrical/crossbus", -1);
	} elsif (ac_electricBuses[0].volts >= ac_volt_min and ac_electricBuses[1].volts < ac_volt_min and sourceR == "") { 
		setprop("/controls/electrical/crossbus", 1);
	} elsif (crossbus == -1 and (ac_electricSources[0].volts > ac_volt_min and sourceL == "engL") or (ac_electricSources[2].volts > ac_volt_min and (sourceL == "apuL" or sourceL == "apuR")) or (ac_electricSources[3].volts > ac_volt_min and sourceL == "ext")) {
		setprop("/controls/electrical/crossbus", 0);
	} elsif (crossbus == 1 and (ac_electricSources[1].volts > ac_volt_min and sourceR == "engR") or (ac_electricSources[2].volts > ac_volt_min and (sourceR == "apuL" or sourceR == "apuR")) or (ac_electricSources[3].volts > ac_volt_min and sourceR == "ext")) {
		setprop("/controls/electrical/crossbus", 0);
	}
	
	print("crossbus", crossbus);
	
	if (bustransfersw == 1) {
		if (crossbus == 1 or crossbus == -1) {
			relays[0].relayClose();
			relays[1].relayClose();
		} elsif ((sourceL == "ext" or sourceR == "ext" or sourceL == "apuL" or sourceR == "apuL" or sourceL == "apuR" or sourceR == "apuR") and (sourceL != "engL" and sourceR != "engR")) {
			relays[0].relayClose();
			relays[1].relayClose();
		} elsif (sourceL == "engL" and sourceR != "engL" and sourceR != "") {
			relays[0].relayOpen();
			relays[1].relayClose();
		} elsif (sourceL != "engL" and sourceR == "engL" and sourceL != "") {
			relays[0].relayClose();
			relays[1].relayOpen();
		} else {
			relays[0].relayOpen();
			relays[1].relayOpen();
		}
	} else {
		relays[0].relayOpen();
		relays[1].relayOpen();
	}
	
	# Generators
	# Engine Generators
	
	# GCB1
	if (engL == 1 and sourceL == "engL") {
		relays[2].relayClose();
	} elsif (engL == -1) {
		relays[2].relayOpen();
	}
	
	# GCB2
	if (engR == 1 and sourceR == "engR") {
		relays[3].relayClose();
	} elsif (engR == -1) {
		relays[3].relayOpen();
	}
	
	# IDG 1
	if (getprop("/systems/electrical/IDG-discL") == 1) { # ensure this property cannot be set to 0 in air
		setprop("/systems/electrical/gen1-avail", 0);
	} elsif (getprop("/controls/electrical/IDG-discSwL") == 1 and getprop("/controls/engines/engine[0]/cutoff") == 0) {
		setprop("/systems/electrical/gen1-avail", 0);
		setprop("/systems/electrical/IDG-discL", 1);
	} elsif (getprop("/engines/engine[0]/n2") >= 54) {
		setprop("/systems/electrical/gen1-avail", 1);
	} else {
		setprop("/systems/electrical/gen1-avail", 0);
	}
	
	# IDG 2
	if (getprop("/systems/electrical/IDG-discR") == 1) {
		setprop("/systems/electrical/gen2-avail", 0);
	} elsif (getprop("/controls/electrical/IDG-discSwR") == 1 and getprop("/controls/engines/engine[1]/cutoff") == 0) {
		setprop("/systems/electrical/gen2-avail", 0);
		setprop("/systems/electrical/IDG-discR", 1);
	} elsif (getprop("/engines/engine[1]/n2") >= 54) {
		setprop("/systems/electrical/gen2-avail", 1);
	} else {
		setprop("/systems/electrical/gen2-avail", 0);
	}
	
	# APU
	# GCBAPU
	if (apuL == 1 or apuR == 1) {
		relays[4].relayClose();
	} elsif (apuL == -1 or apuR == -1) {
		relays[4].relayOpen();
	}
		
	# APU Automatic Switching to engine generators in flight
	if ((sourceL == "apuL" or sourceR == "apuR") and rpmapu < 94.9 and getprop("/b737/sensors/air-ground") == 0) {
		setprop("/systems/electrical/sourceL", "engL"); 
		setprop("/systems/electrical/sourceR", "engR");
	}
	
	# External Power
	extpwr_on = getprop("/services/ext-pwr/enable");
	ext = getprop("/controls/electrical/ext/sw");
	
	# GCBEXT
	if (ext == 1) {
		relays[5].relayClose();
	} elsif (ext == -1) {
		relays[5].relayOpen();
	}
	
	if (relays[5].state == 1 and extpwr_on) {
		setprop("/controls/electrical/extpwr-avail", 1);
	} else {
		setprop("/controls/electrical/extpwr-avail", 0);
	}
	
	# Static Inverter
	if ((getprop("/controls/electrical/battery-switch") == 0 or getprop("/controls/electrical/stby-pw-sw") == 0) or (ac_electricBuses[0].volts >= ac_volt_min and stbyPwSw == 1)) {
		setprop("/systems/electrical/stat-inv-avail", 0);
	} elsif (getprop("/controls/electrical/battery-switch") == 1 and getprop("/controls/electrical/stby-pw-sw") != 0) {
		setprop("/systems/electrical/stat-inv-avail", 1);
	} else {
		setprop("/systems/electrical/stat-inv-avail", 0);
	}
	
	######################
	# DC System          #
	######################
	
	# TR1
	if (ac_electricBuses[0].volts >= ac_volt_min) {
		setprop("/systems/electrical/tr1-avail", 1);
	} else {
		setprop("/systems/electrical/tr1-avail", 0);
	}
	
	# TR2
	if (ac_electricBuses[1].volts >= ac_volt_min) {
		setprop("/systems/electrical/tr2-avail", 1);
	} else {
		setprop("/systems/electrical/tr2-avail", 0);
	}
	
	# TR3
	if (ac_electricBuses[1].volts >= ac_volt_min or ac_electricBuses[0].volts >= ac_volt_min) {
		setprop("/systems/electrical/tr3-avail", 1);
	} else {
		setprop("/systems/electrical/tr3-avail", 0);
	}
	
	# Cross Bus Tie Relay
	if (getprop("/autopilot/display/pitch-mode") == "G/S" or getprop("/controls/electrical/bus-transfer-sw") == 0) {
		relays[8].relayOpen();
	} else {
		relays[8].relayClose();
	}
	
	# DC Bus 1
	if (dc_electricSources[2].volts >= dc_volt_min) {
		dc_electricBuses[0].volts = dc_electricSources[2].volts;
	} elsif ((dc_electricSources[3].volts >= dc_volt_min) and relays[8].state == 1) {
		dc_electricBuses[0].volts = dc_electricSources[3].volts;
	} elsif ((dc_electricSources[4].volts >= dc_volt_min) and relays[8].state == 1) {
		dc_electricBuses[0].volts = dc_electricSources[4].volts;
	} else {
		dc_electricBuses[0].volts = 0;
	}
	
	if (dc_electricBuses[0].volts >= dc_volt_min) {
		setprop("/systems/electrical/dc1-avail", 1);
	} else {
		setprop("/systems/electrical/dc1-avail", 0);
	}
	
	# DC Bus 2
	if (dc_electricSources[3].volts >= dc_volt_min) {
		dc_electricBuses[1].volts = dc_electricSources[3].volts;
	} elsif ((dc_electricSources[2].volts >= dc_volt_min) and relays[8].state == 1) {
		dc_electricBuses[1].volts = dc_electricSources[2].volts;
	} elsif (dc_electricSources[4].volts >= dc_volt_min) {
		dc_electricBuses[1].volts = dc_electricSources[4].volts;
	} else {
		dc_electricBuses[1].volts = 0;
	}
	
	if (dc_electricBuses[1].volts >= dc_volt_min) {
		setprop("/systems/electrical/dc2-avail", 1);
	} else {
		setprop("/systems/electrical/dc2-avail", 0);
	}
	
	# DC STBY Bus
	
	if (ac_electricSources[0].volts == 0 and ac_electricSources[1].volts == 0 and ac_electricSources[2].volts == 0 and ac_electricSources[3].volts == 0 and ac_electricSources[4].volts == 0) {
		batOnly = 1;
	} else {
		batOnly = 0;
	}
	
	if (stbyPwSw != 0) {	
		if (batOnly == 1 and getprop("/controls/electrical/battery-switch") == 1) {
			if (dc_electricSources[2].volts >= dc_volt_min) {
				dc_electricBuses[2].volts = dc_electricSources[2].volts;
			} elsif ((dc_electricSources[3].volts >= dc_volt_min) and relays[8].state == 1) {
				dc_electricBuses[2].volts = dc_electricSources[3].volts;
			} elsif ((dc_electricSources[4].volts >= dc_volt_min) and relays[8].state == 1) {
				dc_electricBuses[2].volts = dc_electricSources[4].volts;
			} elsif (dc_electricSources[0].volts >= dc_volt_min and ((getprop("/controls/electrical/stby-pw-sw") == -1) or (getprop("/systems/electrical/stbyMode") == 1 and getprop("/controls/electrical/stby-pw-sw") == 1))) {
				dc_electricBuses[2].volts = dc_electricSources[0].volts;
			} elsif (dc_electricSources[1].volts >= dc_volt_min and ((getprop("/controls/electrical/stby-pw-sw") == -1) or (getprop("/systems/electrical/stbyMode") == 1 and getprop("/controls/electrical/stby-pw-sw") == 1))) {
				dc_electricBuses[2].volts = dc_electricSources[1].volts;
			} else {
				dc_electricBuses[2].volts = 0;
			}
		} elsif (batOnly == 0) {
			if (dc_electricSources[2].volts >= dc_volt_min) {
				dc_electricBuses[2].volts = dc_electricSources[2].volts;
			} elsif ((dc_electricSources[3].volts >= dc_volt_min) and relays[8].state == 1) {
				dc_electricBuses[2].volts = dc_electricSources[3].volts;
			} elsif ((dc_electricSources[4].volts >= dc_volt_min) and relays[8].state == 1) {
				dc_electricBuses[2].volts = dc_electricSources[4].volts;
			} elsif (dc_electricSources[0].volts >= dc_volt_min and ((getprop("/controls/electrical/stby-pw-sw") == -1) or (getprop("/systems/electrical/stbyMode") == 1 and getprop("/controls/electrical/stby-pw-sw") == 1))) {
				dc_electricBuses[2].volts = dc_electricSources[0].volts;
			} elsif (dc_electricSources[1].volts >= dc_volt_min and ((getprop("/controls/electrical/stby-pw-sw") == -1) or (getprop("/systems/electrical/stbyMode") == 1 and getprop("/controls/electrical/stby-pw-sw") == 1))) {
				dc_electricBuses[2].volts = dc_electricSources[1].volts;
			} else {
				dc_electricBuses[2].volts = 0;
			}
		} else {
			dc_electricBuses[2].volts = 0;
		}
	} else {
		dc_electricBuses[2].volts = 0;
	}
	
	if (dc_electricBuses[2].volts >= dc_volt_min) {
		setprop("/systems/electrical/dc-stby-avail", 1);
	} else {
		setprop("/systems/electrical/dc-stby-avail", 0);
	}
	
	# DC Battery Bus
	if (getprop("/controls/electrical/battery-switch") == 1) {
		if (dc_electricSources[4].volts >= dc_volt_min and getprop("/controls/electrical/stby-pw-sw") == 1) {
			dc_electricBuses[3].volts = dc_electricSources[4].volts;
		} elsif (dc_electricSources[0].volts >= dc_volt_min and ((getprop("/controls/electrical/stby-pw-sw") == -1) or (getprop("/systems/electrical/stbyMode") == 1 and getprop("/controls/electrical/stby-pw-sw") == 1))) {
			dc_electricBuses[3].volts = dc_electricSources[0].volts;
		} elsif (dc_electricSources[1].volts >= dc_volt_min and ((getprop("/controls/electrical/stby-pw-sw") == -1) or (getprop("/systems/electrical/stbyMode") == 1 and getprop("/controls/electrical/stby-pw-sw") == 1))) {
			dc_electricBuses[3].volts = dc_electricSources[1].volts;
		} else {
			dc_electricBuses[3].volts = 0;
		}
	} else {
		dc_electricBuses[3].volts = 0;
	}
	
	if (dc_electricBuses[3].volts >= dc_volt_min) {
		setprop("/systems/electrical/dc-bat-avail", 1);
	} else {
		setprop("/systems/electrical/dc-bat-avail", 0);
	}
	
	# HOT Bus
	# Always on
	if (dc_electricSources[0].volts > dc_volt_min) {
		dc_electricBuses[4].volts = dc_electricSources[0].volts;
	} elsif (dc_electricSources[1].volts > dc_volt_min and getprop("/systems/electrical/stat-inv-avail") == 1) {
		dc_electricBuses[4].volts = dc_electricSources[1].volts;
	} else {
		dc_electricBuses[4].volts = 0;
	}
	
	if (dc_electricBuses[4].volts >= dc_volt_min) {
		setprop("/systems/electrical/dc-hot-bat-avail", 1);
	} else {
		setprop("/systems/electrical/dc-hot-bat-avail", 0);
	}
	
	# Switched HOT Bus
	if (getprop("/controls/electrical/battery-switch") == 1 and dc_electricSources[0].volts > dc_volt_min) {
		dc_electricBuses[5].volts = dc_electricSources[0].volts;
	} elsif (getprop("/controls/electrical/battery-switch") == 1 and dc_electricSources[1].volts > dc_volt_min and getprop("/systems/electrical/stat-inv-avail") == 1) {
		dc_electricBuses[5].volts = dc_electricSources[1].volts;
	} else {
		dc_electricBuses[5].volts = 0;
	}
	
	if (dc_electricBuses[5].volts >= dc_volt_min) {
		setprop("/systems/electrical/dc-hot-bat-sw-avail", 1);
	} else {
		setprop("/systems/electrical/dc-hot-bat-sw-avail", 0);
	}
	
	######################
	# STBY System        #
	######################
	
	# Mode
	if (dc_electricBuses[0].volts == 0 or ac_electricBuses[0].volts == 0 and getprop("/controls/electrical/stby-pw-sw") == 1) {
		setprop("/systems/electrical/stbyMode", 1);
	} else {
		setprop("/systems/electrical/stbyMode", 0);
	}
	
	######################
	# Write Bus Voltages #
	######################
	
	writeProperties();
	
	######################
	# Check / set Lights #
	######################
	
	warningLoop();
	setprop("/instrumentation/attitude-indicator/spin", 1);
}

######################
# Electrical Outputs #
######################

var outputs = ["adf", "audio-panel","audio-panel[1]","autopilot","avionics-fan","beacon","bus","cabin-lights","DG","dme","efis","flaps","fuel-pump","fuel-pump[1]","fuel-pump[2]","fuel-pump[3]","gps","gps-mfd","hsi",
"instr-ignition-switch","instrument-lights","landing-lights","map-lights","mk-viii","nav","nav[1]","pitot-head","stobe-lights","tacan","taxi-lights","transponder","turn-coordinator"
];

setlistener("/systems/electrical/bus/DC1", func {
	foreach(var output; outputs) {
		if (getprop("/systems/electrical/bus/DC1") >= dc_volt_min) {
			setprop("systems/electrical/outputs/"~output, dc_volt_std);
		} else {
			setprop("systems/electrical/outputs/"~output, 0);
		}
	}
});

######################
# Guarded Switches   #
######################

setlistener("/controls/electrical/battery-switch-cvr", func() {
	if (getprop("/controls/electrical/battery-switch-cvr") == 0) {
		setprop("/controls/electrical/battery-switch", 1);
	}
}, 0, 0);

######################
# Warning lights     #
######################

var warnlights = ["driveL", "driveR", "stby-off", "transL-off", "transR-off", "srcL-off", "srcR-off", "tr-unit", "bat-dischg", "elec", "apu-gen-off", "engL-gen-off", "engR-gen-off", "gnd-pwr-avail"];

var warningLoop = func {
	if (ac_electricBuses[0].volts < ac_volt_min) {
		setprop("/systems/electrical/warning-lights/transL-off", 1);
	} else {
		setprop("/systems/electrical/warning-lights/transL-off", 0);
	}
	
	if (ac_electricBuses[1].volts < ac_volt_min) {
		setprop("/systems/electrical/warning-lights/transR-off", 1);
	} else {
		setprop("/systems/electrical/warning-lights/transR-off", 0);
	}
	
	sourceL = getprop("/systems/electrical/sourceL");
	sourceR = getprop("/systems/electrical/sourceR");
	
	if (sourceL == "" or (sourceL == "engL" and ac_electricSources[0].volts < ac_volt_min) or ((sourceL == "apuL" or sourceL == "apuR") and ac_electricSources[2].volts < ac_volt_min) or (sourceL == "ext" and ac_electricSources[3].volts < ac_volt_min)) {
		setprop("/systems/electrical/warning-lights/srcL-off", 1);
	} else {
		setprop("/systems/electrical/warning-lights/srcL-off", 0);
	}
	
	if (sourceR == "" or (sourceR == "engR" and ac_electricSources[1].volts < ac_volt_min) or ((sourceR == "apuL" or sourceR == "apuR") and ac_electricSources[2].volts < ac_volt_min) or (sourceR == "ext" and ac_electricSources[3].volts < ac_volt_min)) {
		setprop("/systems/electrical/warning-lights/srcR-off", 1);
	} else {
		setprop("/systems/electrical/warning-lights/srcR-off", 0);
	}
	
	rpmapu = getprop("/systems/apu/rpm");
	
	if (sourceL != "apuL" and sourceR != "apuL" and sourceL != "apuR" and sourceR != "apuR" and rpmapu > 94.9) {
		setprop("/systems/electrical/warning-lights/apu-gen-off", 1);
	} else {
		setprop("/systems/electrical/warning-lights/apu-gen-off", 0);
	}
	
	extpwr_on = getprop("/services/ext-pwr/enable");
	
	if (extpwr_on == 1) {
		setprop("/systems/electrical/warning-lights/gnd-pwr-avail", 1);
	} else {
		setprop("/systems/electrical/warning-lights/gnd-pwr-avail", 0);
	}
	
	if (ac_electricBuses[8].volts < ac_volt_min or dc_electricBuses[2].volts < dc_volt_min or dc_electricBuses[3].volts < dc_volt_min) {
		setprop("/systems/electrical/warning-lights/stby-off", 1);
	} else {
		setprop("/systems/electrical/warning-lights/stby-off", 0);
	}
	
	if (getprop("/systems/electrical/IDG-discL") == 1 or getprop("/engines/engine[0]/n2") < 54) {
		setprop("/systems/electrical/warning-lights/driveL", 1);
	} else {
		setprop("/systems/electrical/warning-lights/driveL", 0);
	}
	
	if (getprop("/systems/electrical/IDG-discR") == 1 or getprop("/engines/engine[1]/n2") < 54) {
		setprop("/systems/electrical/warning-lights/driveR", 1);
	} else {
		setprop("/systems/electrical/warning-lights/driveR", 0);
	}
	
	if ((getprop("/b737/sensors/air-ground") == 1 and (dc_electricSources[2].volts < dc_volt_min or dc_electricSources[3].volts < dc_volt_min or dc_electricSources[4].volts < dc_volt_min))
		or (getprop("/b737/sensors/air-ground") == 0 and (dc_electricSources[2].volts < dc_volt_min or (dc_electricSources[3].volts < dc_volt_min and dc_electricSources[4].volts < dc_volt_min)))) {
		setprop("/systems/electrical/warning-lights/tr-unit", 1);
	} else {
		setprop("/systems/electrical/warning-lights/tr-unit", 0);
	}
	
	
	if (getprop("/systems/electrical/warning-lights/driveL") == 1 or getprop("/systems/electrical/warning-lights/driveR") == 1
		or getprop("/systems/electrical/warning-lights/stby-off") == 1 or getprop("/systems/electrical/warning-lights/tr-unit") == 1
		or getprop("/systems/electrical/warning-lights/transL-off") == 1 or getprop("/systems/electrical/warning-lights/transR-off") == 1) {
		setprop("/systems/weu/elec-failed", 1);
	} else {
		setprop("/systems/weu/elec-failed", 0);
	}
}
######################
# Init				 #
######################

var elec_init = func {
	setprop("/controls/electrical/extpwr-avail", 0);
	setprop("/systems/electrical/gen1-avail", 0);
	setprop("/systems/electrical/gen2-avail", 0);
	setprop("/systems/electrical/stat-inv-avail", 0);
	setprop("/systems/electrical/tr1-avail", 0);
	setprop("/systems/electrical/tr2-avail", 0);
	setprop("/systems/electrical/tr3-avail", 0);
	setprop("/systems/electrical/trans1-avail", 0);
	setprop("/systems/electrical/trans2-avail", 0);
	setprop("/systems/electrical/ac1-avail", 0);
	setprop("/systems/electrical/ac2-avail", 0);
	setprop("/systems/electrical/ac-galyab-avail", 0);
	setprop("/systems/electrical/ac-galycd-avail", 0);
	setprop("/systems/electrical/ac-gndsvc1-avail", 0);
	setprop("/systems/electrical/ac-gndsvc2-avail", 0);
	setprop("/systems/electrical/ac-stby-avail", 0);
	setprop("/systems/electrical/dc1-avail", 0);
	setprop("/systems/electrical/dc2-avail", 0);
	setprop("/systems/electrical/dc-stby-avail", 0);
	setprop("/systems/electrical/dc-bat-avail", 0);
	setprop("/systems/electrical/dc-hot-bat-avail", 0);
	setprop("/systems/electrical/dc-hot-bat-sw-avail", 0);
	setprop("/controls/electrical/battery-switch", 0);
	setprop("/controls/electrical/battery-switch-cvr", 1);
	setprop("/systems/electrical/battery-avail", 1);
	setprop("/systems/electrical/aux-battery-avail", 1);
	setprop("/controls/electrical/gnd-svc-switch", 0);
	setprop("/controls/electrical/ext/sw", 0);
	setprop("/controls/electrical/emerpwr", 0);
	setprop("/controls/electrical/galley", 1);
	setprop("/controls/electrical/xtie/acxtie", 1);
	setprop("/controls/electrical/xtie/dcxtie", 0);
	setprop("/controls/electrical/xtie/xtieL", 0);
	setprop("/controls/electrical/xtie/xtieR", 0);
	setprop("/controls/electrical/stby-pw-sw", 1);
	setprop("/controls/electrical/bus-transfer-sw", 1);
	setprop("/controls/electrical/apu/Lsw", 0);
	setprop("/controls/electrical/apu/Rsw", 0);
	setprop("/controls/electrical/eng/Lsw", 0);
	setprop("/controls/electrical/eng/Rsw", 0);
	setprop("/systems/electrical/sourceL", "");
	setprop("/systems/electrical/sourceR", "");
	setprop("/systems/electrical/stbyMode", 0); # 0 = norm 1 = altn
	setprop("/systems/electrical/shed/galyAB", 0);
	setprop("/systems/electrical/shed/galyCD", 0);
	setprop("/systems/electrical/shed/mainAC1", 0);
	setprop("/systems/electrical/shed/mainAC2", 0);
	setprop("/controls/electrical/IDG-discSwL", 0);
	setprop("/controls/electrical/IDG-discSwR", 0);
	setprop("/systems/electrical/IDG-discL", 0);
	setprop("/systems/electrical/IDG-discR", 0);
	setprop("/b737/sounds/relay", 0);
	setprop("/controls/electrical/crossbus", 0);
	
	foreach(var outputName; outputs) {
		setprop("systems/electrical/outputs/"~outputName, 0);
	}
	
	foreach(var lightName; warnlights) {
		setprop("/systems/electrical/warning-lights/"~lightName, 0);
	}
	
	elec_timer.start();
}

###################
# Update Function #
###################

var update_electrical = func {
	master_elec_loop();
}

var elec_timer = maketimer(0.2, update_electrical);
