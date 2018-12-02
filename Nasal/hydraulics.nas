# 737-800 Hydraulic System
# Joshua Davidson (it0uchpods)

#############
# Init Vars #
#############

var a_eng1_pump_switch = props.globals.initNode("/controls/hydraulic/a-eng1-pump", 0, "BOOL");
var a_elec2_pump_switch = props.globals.initNode("/controls/hydraulic/a-elec2-pump", 0, "BOOL");
var b_elec1_pump_switch = props.globals.initNode("/controls/hydraulic/b-elec1-pump", 0, "BOOL");
var b_eng2_pump_switch = props.globals.initNode("/controls/hydraulic/b-eng2-pump", 0, "BOOL");
var a_b_cross_pump_switch = props.globals.initNode("/controls/hydraulic/a-b-cross-pump", 0, "BOOL");
var stby_pump_switch = props.globals.initNode("/controls/hydraulic/stby-pump", 0, "BOOL");
var fctl_a_switch = props.globals.initNode("/controls/hydraulic/fctl-a", 1, "BOOL");
var fctl_b_switch = props.globals.initNode("/controls/hydraulic/fctl-b", 1, "BOOL");
var spoiler_a_switch = props.globals.initNode("/controls/hydraulic/spoiler-a", 1, "BOOL");
var spoiler_b_switch = props.globals.initNode("/controls/hydraulic/spoiler-b", 1, "BOOL");
var a_pressure = props.globals.initNode("/systems/hydraulic/a-psi", 0, "DOUBLE");
var b_pressure = props.globals.initNode("/systems/hydraulic/b-psi", 0, "DOUBLE");
var stby_pressure = props.globals.initNode("/systems/hydraulic/stby-psi",  0, "DOUBLE");
var aileronAvail = props.globals.initNode("/systems/hydraulic/aileron-active", 0, "DOUBLE");
var elevatorAvail = props.globals.initNode("/systems/hydraulic/elevator-active", 0, "DOUBLE");
var rudderAvail = props.globals.initNode("/systems/hydraulic/rudder-active", 0, "DOUBLE");
var spoilerAavail = props.globals.initNode("/systems/hydraulic/spoiler-a-active", 0, "DOUBLE");
var spoilerBavail = props.globals.initNode("/systems/hydraulic/spoiler-b-active", 0, "DOUBLE");

var parkbrk = props.globals.getNode("/controls/gear/brake-parking", 1);
var n2_left = props.globals.getNode("/engines/engine[0]/n2", 1);
var n2_right = props.globals.getNode("/engines/engine[1]/n2", 1);

var acL = 0;
var acR = 0;

var hyd_init = func {
    hyd_timer.start();
}

#######################
# Main Hydraulic Loop #
#######################

var master_hyd = func {
    a_eng1_pump_sw = a_eng1_pump_switch.getValue();
    a_elec2_pump_sw = a_elec2_pump_switch.getValue();
    b_elec1_pump_sw = b_elec1_pump_switch.getValue();
    b_eng2_pump_sw = b_eng2_pump_switch.getValue();
    a_b_cross_pump_sw = a_b_cross_pump_switch.getValue();
    stby_pump_sw = stby_pump_switch.getValue();
    a_psi = a_pressure.getValue();
    b_psi = b_pressure.getValue();
    stby_psi = stby_pressure.getValue();
    n2_1 = n2_left.getValue();
    n2_2 = n2_right.getValue();
    
    # Temporary: until electrical system is simulated
    
    if (n2_1 > 55) {
        acL = 110;
    } else { 
        acL = 0;
    }
    
    if (n2_2 > 55) {
        acR = 110;
    } else { 
        acR = 0;
    }
    
    if ((a_eng1_pump_sw or a_elec2_pump_sw) and (n2_1 >= 47 or n2_2 >= 47)) {
        if (a_psi < 2900) {
            a_pressure.setValue(a_psi + 100);
        } else {
            a_pressure.setValue(3000);
        }
    } else if (a_b_cross_pump_sw and b_psi >= 1500) {
        if (a_psi < 2400) {
            a_pressure.setValue(a_psi + 100);
        } else {
            a_pressure.setValue(2500);
        }
    } else {
        if (a_psi > 1) {
            a_pressure.setValue(a_psi - 50);
        } else {
            a_pressure.setValue(0);
        }
    }
    
    if ((b_elec1_pump_sw or b_eng2_pump_sw) and (acL >= 110 or acR >= 110)) {
        if (b_psi < 2900) {
            b_pressure.setValue(b_psi + 100);
        } else {
            b_pressure.setValue(3000);
        }
    } else {
        if (b_psi > 1) {
            b_pressure.setValue(b_psi - 50);
        } else {
            b_pressure.setValue(0);
        }
    }
    
    if (stby_pump_sw and (acL >= 110 or acR >= 110)) {
        if (stby_psi < 2400) {
            stby_pressure.setValue(stby_psi + 100);
        } else {
            stby_pressure.setValue(2500);
        }
    } else {
        if (stby_psi > 1) {
            stby_pressure.setValue(stby_psi - 50);
        } else {
            stby_pressure.setValue(0);
        }
    }
}

###################
# Update Function #
###################

var update_hydraulic = func {
    master_hyd();
}

var hyd_timer = maketimer(0.2, update_hydraulic);
