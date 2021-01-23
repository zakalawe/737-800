


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

        # core FMC update timer
        maketimer(0.5, func me.updateFlightPhase());

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

            me.updateClimb();
        } elsif (phase == FMC.PHASE_CRUISE) {
            me.updateCruise();

        } elsif (phase == FMC.PHASE_DESCENT) {
            me.updateDescent();
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
        me.computeClimb();
        me.updateClimb();
        me.computeDescent();

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

    _computeFuelConsumption: func {
        # use leg altitude / speeds to compute fuel usage per leg
    },

    updateCruise: func
    {
        # avoid spurious computations
        if (phase > FMC.PHASE_CRUISE) {
            return;
        }

       if (flightplan() == nil) {
           print("B737 FMC: updateCruise: No active flightplan yet");
           return;
       }

        # compute step point and savings for changed altitude


    # update TO T/D time / distance
        var d = me._pathDistanceToTOD();
        if (d < 0.1) {
            # enter DESenct mode
            print('FMC at ToD, stsrting DESCENT');
            me._advanceToPhase(FMC.PHASE_DESCENT);
        }

        var t = me._pathTimeToTOD();

        setprop(FMC.rootPath ~ 'descent/to-top-distance-nm', d);
        setprop(FMC.rootPath ~ 'descent/to-top-time-sec', t);


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

    _timeToClimb: func(from, to)
    {
        var result = 0; # time in seconds
        if ((from < 18000) and (to > 18000)) {
            result = ((18000 - from) / 1800) * 60
            from = 18000;
        }
    
        if (to > 28000) {
            # bias this by weight especially

            # 500 FPM above FL280
            result += ((to - 28000) / 500) * 60;
            to = 28000;
        }

        # 1000FPM from 18000 up to C/O alt
        result += ((to - from) / 1000) * 60

        return result;
    },

    _climbSpeed: func
    {
        # compute speed
        # FIXME : use real V2 speed
        var v2Speed = 155;

        var climbKts = 280;
        var md = me.climbMode();
        if (md == FMC.MODE_CLB_MAX_ANGLE) {
            # use V2 + 80
            # taken from the Tech Guide rules of thumb
            climbKts = v2Speed + 80;
        } elsif (md == FMC.MODE_CLB_MAX_RATE) {
            # use V2 + 120
            # taken from the Tech Guide rules of thumb
            climbKts = v2Speed + 120;
        } else {
            # ECON / LRC
            climbKts = 280;
        }

        return climbKts;
    },

    computeClimb: func
    {
        var fp = flightplan();
    
        var curAlt = fp.departure.getElevationFt();;
        if (phase == FMC.PHASE_CLIMB) {
            curAlt = me._indicatedAlt.getValue();
        }

        var cruiseAlt = fp.cruiseAltitudeFt
        var climbTime = me._timeToClimb(curAlt, cruiseAlt);

        var kts = me._climbSpeed();
        # fixme compsensate for groundspeed/wind
        var lateralDistanceNm = (climbTime / 3600.0) * kts;

        var offset = me._normalisePathOffset(0, lateralDistanceNm);

        setprop(FMC.rootPath ~ 'climb/top-wp-index',  offset.wpIndex);
        setprop(FMC.rootPath ~ 'climb/top-wp-offset-nm',  offset.offsetNm);

        me._climbTopGeod = fp.pathGeod(pathIndex, lateralDistanceNm);
        setprop(FMC.rootPath ~ 'climb/top-latitude-deg',  me._climbTopGeod.lat);
        setprop(FMC.rootPath ~ 'climb/top-longitude-deg',  me._climbTopGeod.lon);
    },

    updateClimb: func
    {
        var kts = me._climbSpeed();
        
        # overkill to call this each update?
        computeClimb();

        setprop(FMC.rootPath ~ 'climb/computed-speed-kt', kts);
        setprop(FMC.rootPath ~ 'climb/computed-speed-mach', 0.74);

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

        # time to top of climb?
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
        if ((fp == nil) or (fp.active == 0))
            return -1.0;

        var index = fp.current + 1;
        
        # distance direct to current wp
        var cd = courseAndDistance(fp.currentWP());
        var d = cd[1];

        for (; index <= wp.index; index +=1) {
            d += fp.getWP(index).leg_distance;
        }

        return d;
    },

    _pathTimeToWP: func(wp, offset)
    {
        var fp = flightplan();
        if ((fp == nil) or (fp.active == 0))
            return -1.0;

        var index = fp.current + 1;
        var gs = getprop("/velocities/groundspeed-kts");

        # distance direct to current wp
        var cd = courseAndDistance(fp.currentWP());
        var d = cd[1];
        var t = (d / gs) * 3600.0;

        for (; index <= wp; index +=1) {
            var leg = fp.getWP(index);
            t += _predictedDurationForLegSeconds(leg);
        }

        # and account for any offset
        if (offset > 0.0) {
            var gs = me._groundspeedForLeg(fp.getWP(wp));
            t += (offset / gs) * 3600.0;
        }

        return t;
    },

    _pathDistanceToTOD: func 
    {
        var todIndex = getprop(FMC.rootPath ~ 'descent/top-wp-index');
        var todOffset = getprop(FMC.rootPath ~ 'descent/top-wp-offset-nm');
        return me._pathDistanceToWp(todIndex) + todOffset;
    },

    _pathTimeToTOD: func 
    {
        var todIndex = getprop(FMC.rootPath ~ 'descent/top-wp-index');
        var todOffset = getprop(FMC.rootPath ~ 'descent/top-wp-offset-nm');
        return me._pathTimeToWP(todIndex, todOffset);
    },

    _normalisePathOffset: func(index, offsetNm)
    {
        if (offsetNm < 0.0) {
            # base case: we're at the beginning
            if (index == 0) {
                return { wpIndex: 0, offsetNm: offsetNm};
            }

            var d = flightplan().getWP( index- 1).leg_distance;
            return self._normalisePathOffset(index - 1, offsetNm + d);
        }

        # offset is positive
        var d = flightplan().getWP(index).leg_distance;
        if (offsetNm < d) {
            # we're done, found the containing leg
            return {wpIndex: index, offsetNm: offsetNm};
        }

        if (index >= (flightplan.numWaypoints() - 1)) {
            # we're done, off the end of the route
            return {wpIndex: index, offsetNm: offsetNm};
        }

        # recurse forward
        return self._normalisePathOffset(index + 1, offsetNm - d);
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
        # if (leg.. is Cruise)
        # add/subtract cruise wind

        return 400.0;
    },

    _predictedDurationForLegSeconds: func(leg)
    {
        var d = leg.leg_distance;
        var gsKnots = _groundspeedForLeg(leg);
        return (d / gsKnots) * 3600.0;
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

        var timeZ = me._pathTimeToWP(wp);
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

        # if we're in the descent, use current altitude instead
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

        # if we're still in the cruise, comppute Top-of-Descent data
        if (me._phase < PHASE_DESCENT) {
            # FIXME use correct value for last approach point here
            # right now this will start from the missed approach which is not what we want
            var pathIndex = fp.numWaypoints() - 1;
            if (firstDescentRestriction != nil) {
                pathIndex = firstDescentRestriction.index;
            }

            var offset = me._normalisePathOffset(pathIndex, -lateralDistanceNm);

            setprop(FMC.rootPath ~ 'descent/top-wp-index',  offset.wpIndex);
            setprop(FMC.rootPath ~ 'descent/top-wp-offset-nm',  offset.offsetNm);

            me._descentTopGeod = fp.pathGeod(pathIndex, - lateralDistanceNm);
            setprop(FMC.rootPath ~ 'descent/top-latitude-deg',  me._descentTopGeod.lat);
            setprop(FMC.rootPath ~ 'descent/top-longitude-deg',  me._descentTopGeod.lon);
        }
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

    departureChanged: func
    {
        # set this so V-speeds offset is correct
        setprop('instrumentation/fmc/inputs/takeoff-elevation-ft', me._plane.departure.getElevationFt());
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

var _cdu = nil;

var enterLSK = func(entry, lsk)
{
    _cdu.setScratchpad(entry);
    _cdu.lsk(lsk);
}

var execTest1 = func() 
{
    print("Running FMC test 1");
    _cdu = Boeing.cdu;

    setprop('instrumentation/fmc/settings/ref-airport', 'EDDM');
    setprop('instrumentation/fmc/pos-init-complete', 1);

    # route page

    var routePage = Boeing.cdu.getPage('route');
    Boeing.cdu.displayPage(routePage);

    enterLSK('EDDM', 'L1');
    enterLSK('EGKK', 'R1');
    enterLSK('KL1278', 'R2');

    # should select 'departure' page
    _cdu.lsk('R6');
    print("Page title is:" ~ _cdu.currentPage().title());

    # select runway


# perf init pages

    setprop('instrumentation/fmc/gross-weight-lbs', 60 * 1000);
    
    # CDU entry of cruise altitude
    var perfPage = Boeing.cdu.getPage('performance');
    Boeing.cdu.displayPage(perfPage);
    
    enterLSK('FL340', 'R1');
    Boeing.cdu.button_exec();

    # reserves
    enterLSK('2.1', 'L4');

    # cost index  
    enterLSK('200', 'L5');

    # limits page
    var n1Preflight = Boeing.cdu.getPage('thrust-lim');
    Boeing.cdu.displayPage(n1Preflight);
    
    # assumed temp
    enterLSK('20', 'L1');

    # select CLB-1
    Boeing.cdu.lsk('R3');

    # takeoff page
    boeing737.fmc.setTakeoffFlaps(10);
};


registerFlightPlanDelegate(BoeingFMCDelegate.new);

var unload = func() {
    unregisterFlightPlanDelegate("boeing737-fmc");
    boeing737.fmc = nil;
}

var main = func {
    registerFlightPlanDelegate(BoeingFMCDelegate.new, "boeing737-fmc");
    #copy to original namespace (or edit all other source files  to use new module namespace)
    boeing737.fmc = fmc;
    fmc.execTest1 = execTest1;
}