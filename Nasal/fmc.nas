


var FMC = {
    rootPath: 'instrumentation/fmc/',

    PHASE_PREFLIGHT: 0,
    PHASE_TAKEOFF: 1,
    PHASE_CLIMB: 2, # do we need a climb-2 here?
    PHASE_CRUISE: 3,
    PHASE_DESCENT: 4,
    PHASE_APPROACH: 5,

    MODE_ECON: 0,
    MODE_SPEED : 1,
    MODE_LRC : 2,
    MODE_CLB_MAX_ANGLE : 3,
    MODE_CLB_MAX_RATE : 4,
    MODE_DES_PATH : 5,
    MODE_RTA : 6,

    new: func {
        m = { 
            parents: [FMC],
            _root: props.globals.getNode(FMC.rootPath, 1),
            _reducedThrust: 0,
            _refreshCallbacks: []
        };

        m._root.getNode('preflight-complete', 1).setBoolValue(0);
        m._root.getNode('perf-complete', 1).setBoolValue(0);
        m._root.getNode('pos-init-complete', 1).setBoolValue(0);

        m._phase = m._root.getNode('phase-index', 1);
        m._phase.setIntValue(FMC.PHASE_PREFLIGHT);

        m._climbMode = m._root.getNode('climb/mode', 1);
        m._climbMode.setIntValue(FMC.MODE_ECON);

        m._climbComputedKnots = m._root.getNode('climb/computed-speed-kts', 1);
        m._climbComputedKnots.setIntValue(280);
        m._climbComputedMach = m._root.getNode('climb/computed-speed-mach', 1);
        m._climbComputedMach.setDoubleValue(0.78);

        m._cruiseMode = m._root.getNode('cruise/mode', 1);
        m._cruiseMode.setIntValue(FMC.MODE_ECON);

        # squat switch
        m._airGround = props.globals.getNode("/b737/sensors/air-ground", 1);
        m._indicatedAlt = props.globals.getNode("/instrumentation/altimeter[0]/indicated-altitude-ft", 1);

        # init some data
        m.updateCruise();

        return m;
    },

    grossWeightKg: func {
        var gw = getprop(FMC.rootPath ~ 'gross-weight-kg');
        if (!gw) {
            gw = getprop('/fdm/jsbsim/inertia/weight-kg');
        }

        return gw /= 1000.0;
    },

    isPreflightComplete: func {
        return getprop(FMC.rootPath ~ 'preflight-complete');
    },

    fuelTotalKg: func {
        return getprop('consumables/fuel/total-fuel-kg');
    },

    updatePreflightComplete: func {
        # perf complete, route active, pos init complete
        # takeoff flaps selected, crusie altitude selected
        # anything else?
        var c = me._computePreflightComplete();
        me._root.getNode('preflight-complete').setBoolValue(c);
        if (c) {
            if (me._phase.getValue() == FMC.PHASE_PREFLIGHT) {
                me._phase.setIntValue(FMC.PHASE_TAKEOFF);
            }
        }
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

    activeFlightPhase: func {me._phase.getValue(); },

    updateFlightPhase: func {
        var phase = me._phase.getValue();
        if (phase == FMC.PHASE_PREFLIGHT) {
            
        } elsif (phase == FMC.PHASE_TAKEOFF) {
           if (me._airGround.getValue() == 0) {
                print('FMC detected liftoff');
                me._advanceToPhase(FMC.PHASE_CLIMB);
            }
        } elsif (phase == FMC.PHASE_CLIMB) {
            var alt = me._indicatedAlt.getValue();
            var diff = abs(alt - flightplan().cruiseAltitudeFt);
            if (abs < 100) {
                print('FMC Reached cruise altitude');
                me._advanceToPhase(FMC.PHASE_CRUISE);
            }
        } elsif (phase == FMC.PHASE_CRUISE) {
            # if distance to ToD is < 0.1 name
            # me.doDescentNow();
        }

    },

    doDescentNow: func {
        var phase = me._phase.getValue();
        if (phase != FMC.PHASE_CRUISE) {
            print("Not in cruise, can't start descent");
            return 0;
        }

        print('FMC descent now');
        me._advanceToPhase(FMC.PHASE_DESCENT);
    },

    _advanceToPhase: func(p) {
        if (me._phase.getValue() == p) return;



        me._phase.setIntValue(p);

        # recompute all modes for now
        me.updateClimb();
        me.updateCruise();

        # likely everything has changed :)
        me.signalRefresh();
    },

    forecastForWP: func(index) {
        #print('compute/return VNav data for WP');

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

    distanceToWP: func(wp) {
        var fp = flightplan();
        if (wp.index < fp.current) return nil;
        var distance = fp.currentWP().courseAndDistanceFrom(geo.aircraft_position())[1];
        for (var i = fp.current + 1; i < wp.index; i +=1) {
            distance += fp.getWP(i).leg_distance;
        }
    },

    activeSpeedRestrictionWP: func {
        var wp = me._nextRestrictionWP();
        while ((wp != nil) and (wp.speed_cstr_type == nil)) {
             wp = me._nextRestrictionWP(wp);
        }
        return wp;
    },

    activeAltitudeRestrictionWP: func {
        var wp = me._nextRestrictionWP();
        while ((wp != nil) and (wp.alt_cstr_type == nil)) {
             wp = me._nextRestrictionWP(wp);
        }
        return wp;
    },

    activeRestrictionWP : func {
        me._nextRestrictionWP();
    },

    _nextRestrictionWP : func(after = nil) {
        var fp = flightplan();
        var sz = fp.getPlanSize();
        var index = (after == nil) ? fp.currentWP().index : after.index + 1;
        for (; index < sz; index +=1 ) {
            var wp = fp.getWP(index);
            if ((wp.speed_cstr_type != nil) or (wp.alt_cstr_type != nil)) {
                return wp;
            }
        }
        return nil;
    },

    doAltitudeIntervention: func {
        # delete active altitude restriction
        var wp = me.activeAltitudeRestrictionWP();
        if (wp) {
            print('Deleting altitude restriction on ' ~ wp.wp_name);
            wp.setAltitude(nil);
        }
    },

    _computeVNAVProfile: func {
        var fp = flightplan();

        var cruiseAlt = fp.cruiseAltitudeFt;
        var climbKnots = 280;
        var descentKnots = 280;

        # need to know climb rate to estimate time / distance to ToC

        # similar for descent rate

    },

    _computeFuelConsumption: func {
        # use leg altitude / speeds to compute fuel usage per leg
    },

    updateCruise: func
    {
       
        # compute step point and savings for changed altitude
    },

    # given twp structs with {speed:nnn, altitude:mmmmmm}, select
    # the applicable one 
    _selectApplicableSpeedRestriction: func(a,b)
    {
        var alt = me._indicatedAlt.getValue();
        if (a.altitude < alt) return b;
        if (b.altitude < alt) return a;

        # both are active for altitude, select based on lower speed
        return (a.speed < b.speed) ? a : b;
    },

    updateClimb: func
    {
        # compute speed

        var md = me.climbMode();
        if (md == FMC.MODE_CLB_MAX_ANGLE) {
            # use V2 + 80
            # taken from the Tech Guide rules of thumb
        } elsif (md == FMC.MODE_CLB_MAX_RATE) {
            # use V2 + 120
            # taken from the Tech Guide rules of thumb
        } else {
            # ECON / LRC
            setprop(FMC.rootPath ~ 'climb/computed-speed-kt', 280);
            setprop(FMC.rootPath ~ 'climb/computed-speed-mach', 0.74);
        }

        # figure out limit speed based on cross-over, active restriction
        var above10000 = (me._indicatedAlt.getValue() >= 10000);

        var entered = {speed: getprop(FMC.rootPath ~ 'climb/input-speed-restriction-kt'),
                        altitude: getprop(FMC.rootPath ~ 'climb/input-speed-restriction-ft'),
                        entered: 1};
        var r = above10000 ? nil : {speed: 250, altitude: 10000};
        if (entered.speed != nil and r != nil) {
            r = me._selectApplicableSpeedRestriction(entered, r);
        }

        # check for restriction on active WP
        # apply if necessary

        if (r == nil) {
            setprop(FMC.rootPath ~ 'climb/active-speed-restriction-kt', 0);
            setprop(FMC.rootPath ~ 'climb/active-speed-restriction-ft', 0);
        } else {
            setprop(FMC.rootPath ~ 'climb/active-speed-restriction-kt', r.speed);
            setprop(FMC.rootPath ~ 'climb/active-speed-restriction-ft', r.altitude);
        }
    },

    cruiseMode: func {
        return me._cruiseMode.getValue();
    },

    setCruiseMode: func(md) {
        me._cruiseMode.setIntValue(md);
    },

    climbMode: func { return me._climbMode.getValue(); },
    setClimbMode: func(md) {
        me._climbMode.setIntValue(md);
        me.updateClimb();
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
    },

    addRefreshCallback: func(cb) {
        append(me._refreshCallbacks, cb);
    },

    signalRefresh: func {
        foreach (var c; me._refreshCallbacks) {
            c();
        }
    },

    enterStepAltitude: func(alt)
    {
        setprop(FMC.rootPath ~ 'cruise/step-altitude-ft', alt);
    },

    isAboveCrossover: func(knots, mach)
    {
        # FIXME find actual crossover for the mach value
        var crossOverAlt = 30000;
        return (me._indicatedAlt.getValue() >= crossOverAlt);
    },
};

var fmc = FMC.new();

var BoeingFMCDelegate = {
    new: func(fp) {
        m = { 
            parents: [BoeingFMCDelegate],
            _plan: fp
        };
        return m;
    },

    waypointsChanged: func()
    {
        # fmc recompute
    },

    endOfFlightPlan: func 
    {

    },

    currentWaypointChanged: func {
        # capture previous waypoint
        if (me._plan.currentWP().index > 0) {
            var prevWP = me._plan.getWP(me._plan.currentWP().index - 1);
            setprop('instrumentation/fmc/from-wpt/ident', prevWP);
            var curAlt = getprop('/instrumentation/altimeter/indicated-altitude-ft');
            setprop('instrumentation/fmc/from-wpt/altitude-ft', curAlt);
            # capture GMT now
            setprop('instrumentation/fmc/from-wpt/time-gmt', nowGMT);
            setprop('instrumentation/fmc/from-wpt/fuel-kg', fmc.fuelTotalKg());
        } else {
            setprop('instrumentation/fmc/from-wpt/ident', '');
            setprop('instrumentation/fmc/from-wpt/altitude-ft', 0);
            setprop('instrumentation/fmc/from-wpt/time-gmt', 0);
            setprop('instrumentation/fmc/from-wpt/total-fuel-kg', 0);
        }

        fmc.signalRefresh();
    }
};

registerFlightPlanDelegate(BoeingFMCDelegate.new);
