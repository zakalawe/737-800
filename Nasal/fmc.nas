
var FMC = {
    rootPath: 'instrumentation/fmc/',

    new: func {
        m = { 
            parents: [FMC],
            _root: props.globals.getNode(FMC.rootPath, 1),
            _reducedThrust: 0
        };

        m._root.getNode('preflight-complete', 1).setBoolValue(0);
        m._root.getNode('perf-complete', 1).setBoolValue(0);
        m._root.getNode('pos-init-complete', 1).setBoolValue(0);

        # init some data
        m.updateCruise();

        return m;
    },

    grossWeightLbs: func {
        var gw = getprop(FMC.rootPath ~ 'gross-weight-lbs');
        if (!gw) {
            gw = getprop('/fdm/jsbsim/inertia/weight-kg'); # convert KG to LBS
        }

        return gw /= 1000.0;
    },

    isPreflightComplete: func {
        return getprop(FMC.rootPath ~ 'preflight-complete');
    },

    takeoffThrustN1: func {
        var lim = getprop(FMC.rootPath ~ 'takeoff/thrust-n1');
        return sprintf('%5.01f/%5.01f', lim, lim)~'%';
    },

    takeoffThrustTitle: func {
        var sel = getprop(FMC.rootPath ~ 'takeoff/derate-index');
        var t = getprop(FMC.rootPath ~ 'derated-to[' ~ sel ~ ']/short-title');
        if (me._reducedThrust) t = 'RED ' ~ t;
        return t;
    },

     updateTakeoffThrust: func {
        var assumed = getprop(FMC.rootPath ~ 'inputs/assumed-temp-deg-c');
        var oat = getprop('environment/temperature-degc');
        
        var sel = getprop(FMC.rootPath ~ 'takeoff/derate-index');
        var lim = getprop(FMC.rootPath ~ 'derated-to[' ~ sel ~ ']/n1-percent');

        if ((assumed == nil) or (assumed <= oat)) {
            me._reducedThrust = 0;
            setprop(FMC.rootPath ~ 'takeoff/thrust-n1', lim);
            return;
        }

        me._reducedThrust = 1;
        print("FIXME compute thrust reduction based on assumed temp");
        setprop(FMC.rootPath ~ 'takeoff/thrust-n1', lim * 0.8);
    },

    updateTakeoffTrim: func {
        var flaps = getprop(FMC.rootPath ~ 'inputs/takeoff-flaps');
        var cg = getprop(FMC.rootPath ~ 'cg');
        if (!flaps or !cg)
            setprop(FMC.rootPath ~ 'stab-trim-units', nil);
    
        print('FIXME compute takeoff trim from CG and GW');
        setprop(FMC.rootPath ~ 'stab-trim-units', 23.45);
    },

    forecastForWP: func(index) {
        print('compute/return VNav data for WP');

        # forecasts resemble a waypoint for formatted output
        var f = {
            eta_hour: 13,
            eta_min: 33,
            fuel: 23.6,
            alt_cstr_type: 'at',
            alt_cstr: 17000,
            speed_cstr_type: 'at',
            speed_cstr: 260,
            wind_bearing: 234,
            wind_speed: 35
        };

        return f;
    },

    updateCruise: func
    {
        setprop(FMC.rootPath ~ 'cruise/optimum-altitude-ft', 33500);
        setprop(FMC.rootPath ~ 'cruise/max-altitude-ft', 36700);
    },

};

var fmc = FMC.new();
