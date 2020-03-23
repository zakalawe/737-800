


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
    
    MODE_DES_ECON_PATH : 5,
    MODE_DES_SPEED_PATH : 6,
    MODE_DES_SPEED : 7,

    MODE_RTA : 8,

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

    # descent properties
        m._descentMode = m._root.getNode('descent/mode', 1);
        # default DES mode is ECON-PATH if available
        m._descentMode.setIntValue(FMC.MODE_DES_ECON_PATH);

        m._descentEndAltitude = m._root.getNode('descent/end-altitude-ft', 1);

        m._descentTargetSpeedKnots = m._root.getNode('descent/target-speed-kts', 1);
        m._descentTargetSpeedMach = m._root.getNode('descent/target-speed-mach', 1);

        m._descentRestrictionWaypt = m._root.getNode('descent/restriction-waypt', 1);
        m._descentRestrictionSpeed = m._root.getNode('descent/restriction-speed-kts', 1);
        m._descentRestrictionAltitude = m._root.getNode('descent/restriction-altitude-ft', 1);
        # boolean flag to mark when the user enters a restriction manually,
        # as opposed to being computed
        m._descentRestrictionFromUser = m._root.getNode('descent/restriction-user', 1);

        m._descentHaveFlightPath = m._root.getNode('descent/flight-path-active', 1);
        m._descentHaveFlightPath.setBoolValue(0);

        m._descentVerticalDeviation = m._root.getNode('descent/vertical-deviation-ft', 1);
        m._descentFPA = m._root.getNode('descent/flight-path-angle-deg', 1);
        m._descentVS = m._root.getNode('descent/vertical-speed-fpm', 1);


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

    _permittedTakeoffFlaps: [1, 2, 5, 10, 15, 25],

    # validate the flaps setting and update related values
    # eg v-speeds
    setTakeoffFlaps: func (flaps) {
        var ok = 0;
        foreach (var fl; me._permittedTakeoffFlaps) {
            if (fl == flaps) ok = 1;
        }

        if (!ok) {
            return 0;
        }

        setprop(FMC.rootPath ~ 'inputs/takeoff-flaps', flaps);
        vspeed.updateFromFMC();
        me.updateTakeoffTrim();
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
        if (!me._root.getNode('pos-init-complete').getValue()) return 0;
        if (!me._root.getNode('perf-complete').getValue()) return 0;

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
                print('FMC detected liftoff, switching to CLIMB');
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

    activeDescentMode: func {
        return me._descentMode;
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

    # find the first descent WP (starting from the current one)
    # with an altitude resriction. 
    # return nil if no such restriction exists
    _nextDescentRestictionWP : func 
    {
        var fp = flightplan();
        var sz = fp.getPlanSize();
        var index = fp.currentWP().index;

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


    # update TO T/D time / distance
        # compute along path distance to ToD point
        # use me._descentTopGeod
        setprop(FMC.rootPath ~ 'descent/to-top-distance-nm', 0.74);
        setprop(FMC.rootPath ~ 'descent/to-top-time-sec', 0.74);
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
        if (getprop('autopilot/route-manager/settings/reserve-fuel-kg') == nil) return 0;
        
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
        var crossOverAlt = 26000;
        return (me._indicatedAlt.getValue() >= crossOverAlt);
    },

    _pathDistanceToWp: func(wp)
    {
        # distance to cur wp

        var fp = flightplan();
        var index = fp.current + 1;
        
        # distance direct to current wp
        var cd = courseAndDistance(fp.currentWP());
        var d = cd[1];

        for (; index <= wp.index; index +=1) {
            d += fp.getWP(index).leg_distance;
        }

        return d;
    },

    _groundspeedForLeg: func (leg)
    {
        var alt = leg.alt_cstr;
        if ((leg.speed_cstr_type == 'computed-mach') or 
            (leg.speed_cstr_type == 'computed'))
        {
            # convert Mach to GS
        } else {
            # convert IAS to GS
        }

        # should account for forecast winds for crusie legs
    },

    _predictedDurationForLegSeconds: func(leg)
    {
        var d = leg.leg_distance;
        var gsKnots = _groundspeedForLeg(leg);
        return (d / gsKnots) * 3600.0;
    },

    _predictedArrivalTime: func(wp)
    {
        return 1000.0;
    },

    updateDescent: func
    {
        var wp = me._nextDescentRestictionWP();
        if (wp) {
            setprop(FMC.rootPath ~ 'descent/restriction-waypoint', wp.wp_name);
            setprop(FMC.rootPath ~ 'descent/restriction-altitude-ft', wp.alt_cstr);
            setprop(FMC.rootPath ~ 'descent/restriction-speed-kts', wp.speed_cstr);
        } else {
            # no down-path restriction
            setprop(FMC.rootPath ~ 'descent/restriction-waypoint', nil);
        }

        # compute distance along path to wp
        var pathDistance = me._pathDistanceToWp(wp);
        setprop(FMC.rootPath ~ 'descent/restriction-distance-nm', pathDistance);

        var timeZ = me._predictedArrivalTime(wp);
        setprop(FMC.rootPath ~ 'descent/restriction-time-zulu', timeZ);

        # FPA / vertical bearing computations
        # 
        # check if it's destination runway also

    },

    computeEndOfDescent: func
    {
        var endAltitude = flightplan().destination.elevation + 1000;
        # if we have a destination runway, use its threshold elevation
        # otherwise use destination field-elevation + 1000
        if (flightplan().destination_runway != nil) {
            endAltitude = flightplan().destination_runway.elevation;
        }
        setprop(FMC.rootPath ~ 'descent/end-altitude-ft', endAltitude);
    },

    computeDescent: func
    {
        var fp = flightplan();
        me.computeEndOfDescent();
    
        var curAlt = fp.cruiseAltitudeFt;
        var endAlt = getprop(FMC.rootPath ~ 'descent/end-altitude-ft');

        # if we're in the descent, use current alttidue instead
        if (me._phase >= PHASE_DESCENT) {
            curAlt = me._indicatedAlt;
        }

        var firstDescentRestriction = me._nextDescentRestictionWP();
        if (firstDescentRestriction != nil) {
            endAlt = firstDescentRestriction.alt_cstr;
        }

        var descentChange = curAlt - endAlt;
        # eg, descent FL340 to 10000, 24000 difference -> 24 * 3 = 72NM out
        # maybe a bit excessive?
        var lateralDistanceNm = (descentChange / 1000) * 3;

        # FIXME use correct value for last approach point here
        # right now this will start from the missed approach which is not what we want
        var pathIndex = fp.numWaypoints() - 1;
        if (firstDescentRestriction != nil) {
            pathIndex = firstDescentRestriction.index;
        }

        me._descentTopGeod = fp.pathGeod(pathIndex, - lateralDistanceNm);

        setprop(FMC.rootPath ~ 'descent/top-latitude-deg',  me._descentTopGeod.lat);
        setprop(FMC.rootPath ~ 'descent/top-longitude-deg',  me._descentTopGeod.lon);
    },

    enterDescentTargetSpeed: func(s)
    {
        var spd = CUD.parseKnotsMach(s);
        if (spd == nil) {
            print('Invalid descent target speed entry');
            return;
        }        

        setprop(FMC.rootPath ~ 'descent/target-speed-kts', spd.knots);
        setprop(FMC.rootPath ~ 'descent/target-speed-mach', spd.mach);

        if (me._descentMode == MODE_DES_ECON_PATH) {
            # transition to SPEED_PATH,
            # anything else to do here?
            me._descentMode = MODE_DES_SPEED_PATH;
        }
    }
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

    activated: func()
    {
        # flight plan activation
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
