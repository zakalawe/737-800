# 3D switches

var ISFD_createProperties = func() {
    ISFD_animation_properties = ["app", "baro-mode", "rst", "plus", "minus", "baro-knob"];
    foreach(var propertyISFD; ISFD_animation_properties) {
        setprop("/controls/ISFD/animation-3D/btn-" ~ propertyISFD, 0);
    }
}

# Create ISFD instance

var _list = setlistener("sim/signals/fdm-initialized", func() {
    var ourISFD = isfd.ISFD.new();
    ISFD_createProperties();
    
    print('Created ISFD instance');
    # ourISFD.display(ISFDScreen); add to object - not working?

    removelistener(_list); # run ONCE
});

# 3D button functions

var plusBtn = func() { 
}

var minusBtn = func() { 
}

var rstBtn = func() { 
}

var appBtn = func() { 
}

var baroModeBtn = func() { 
}

