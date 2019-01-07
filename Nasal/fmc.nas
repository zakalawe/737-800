
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
        m._root.getNode('phase-index', 1).setIntValue(0);
        
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

    updatePreflightComplete: func {
        # perf complete, route active, pos init complete
        # takeoff flaps selected, crusie altitude selected
        # anything else?
        me._root.getNode('preflight-complete').setBoolValue(me._computePreflightComplete());
    },

    _computePreflightComplete: func {
        var flaps = getprop('instrumentation/fmc/inputs/takeoff-flaps');
        if (flaps == nil) return 0;

        # covers crz alt
        if (!me._root.getNode('pos-init-complete')) return 0;
        if (!me._root.getNode('perf-complete')) return 0;

        return 1;
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
        # ISA is 15deg, compute difference
        var deltaDeg = assumed - math.max(15, oat);
        if (deltaDeg > 0)  {
            print("FIXME compute thrust reduction based on assumed temp");
            lim -= 0.01 * deltaDeg; # 1% per degree above ISA/actual
        }
        setprop(FMC.rootPath ~ 'takeoff/thrust-n1', lim);
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

    updatePerformance: func 
    {
        var act = me.isPerformanceActive();
        me._root.getNode('perf-complete').setBoolValue(act);
        me.updatePreflightComplete();
    },

    isPerformanceActive: func 
    {
        if (!flightplan().active) return 0;

        if (getprop('autopilot/route-manager/inputs/cost-index') == nil) return 0;
        if (getprop('autopilot/route-manager/settings/reserve-fuel-lbs') == nil) return 0;
        
        # what is this based off? valid cruise altitude, anything else?
        # cruise wind is definitely not needed
        return getprop('autopilot/route-manager/cruise/altitude-ft') > 0;
    }
};

var fmc = FMC.new();
