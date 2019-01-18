var LegsModel = 
{
    _wpIndexFromModel: func(index) { 
        var fp = flightplan();
        if (me._modDirect != nil) {
            return index + me._modDirect.index;
        }

        if (!fp.active) return index;
        return index + fp.current; 
    },
    
    _wpFromModel: func(index) { 
        flightplan().getWP(me._wpIndexFromModel(index)); 
    },
    
    _ndPlanModeActive: func { getprop('instrumentation/efis/mfd/mode-num') == 3; },
    
    new: func()
    {
      m = {parents: [LegsModel, CDU.AbstractModel.new()]};
      m._modDirect = nil; 
      m._interceptAction = nil;
      return m;
    },

    setInterceptAction: func(a) { me._interceptAction = a; },

    firstLineForActiveLeg: func 0,
    countForActiveLeg: func 1,

    _currentWP: func { (me._modDirect != nil) ? me._modDirect : flightplan().currentWP(); },

    firstLineForLegs: func 1,
    countForLegs: func { 
        var fp = flightplan();
        var cur = me._currentWP();
        return fp.getPlanSize() - (cur.index + 1);
    },
    firstLineForSpeedAlt: func 0,
    countForSpeedAlt: func { return me.countForLegs() + 1; },
    
    titleForActiveLeg: func(index) {
        # compute actual heading and distance to active WP
        var wp = me._currentWP();
        if (wp==nil) return nil;
        var r = courseAndDistance(wp);
        if (r[1] < 10)
            return sprintf('~%3dg     %3.1fNM', r[0], r[1]);
        sprintf('~%3dg    %4dNM', r[0], int(r[1]));
    },

    dataForActiveLeg: func(index) me._internalDataForLeg(0),

    titleForLegs: func(index)
    {
        var wp = me._wpFromModel(index+1);
        if (wp==nil) return nil;
        
        if (wp.leg_distance < 10)
            return sprintf('~%3dg     %3.1fNM', wp.leg_bearing, wp.leg_distance);
        sprintf('~%3dg    %4dNM', wp.leg_bearing, int(wp.leg_distance));
    },
        
    dataForLegs: func(index) me._internalDataForLeg(index+1),

    _internalDataForLeg: func(index) {
        var wp = me._wpFromModel(index);
        if (me._ndPlanModeActive() and (index == getprop('instrumentation/efis/inputs/plan-wpt-index'))) {
            return wp.wp_name ~ '   <CTR>';
        }
        
        return wp.wp_name;
    },
    
    dataForSpeedAlt: func(index)
    {
        var wp = me._wpFromModel(index);
        var f = nil;
        if (wp.alt_cstr_type == nil or wp.speed_cstr_type == nil) {
            f = boeing737.fmc.forecastForWP(me._wpIndexFromModel(index));
        } 
        
        return CDU.formatWayptSpeedAltitudeWithForecast(wp, f);
    },
    
    editActiveLeg: func(sp) {
        # check SP corresponds to a point in the active plan
        var wp = me._findWaypointByIdent(sp);
        if (wp == nil) {
            cdu.postMessage(CDU.INVALID_DATA_ENTRY, 'NO WAYPT IN RTE');
            return 0;
        }

        me._modDirect = wp;
        if (me._interceptAction != nil) {
            print('TODO Compute real intercept course');
            var crsDist = courseAndDistance(geo.aircraft_position(), wp);
            me._interceptAction.setPresetCourse(crsDist[0]);
        }
            
        me.page.reloadModel();
        cdu.setupExec(
            func { me.execDirectTo(); }, 
            func { 
                me._modDirect = nil; 
                me.page.reloadModel();
            });

        return 1;
    },

    execDirectTo : func {
        print('Inform FMC were going direct now');
        flightplan().current = me._modDirect.index;
        me._modDirect = nil;
        me.page.reloadModel();
    },

    selectLegs: func(index) 
    {   
        # copy ident to s/p for using in a direct-to
        var wp = me._wpFromModel(index+1);
        cdu.setScratchpad(wp.wp_name);
        return 1;
    },

    editSpeedAlt: func(index, sp) {
        var wp = me._wpFromModel(index);
        if (sp == 'DELETE') {
            wp.alt_cstr_type = 'delete';
            wp.speed_cstr_type = 'delete';
            return 1;
        } elsif (sp == '') {
            # line-selecting a ---/----- entry will place the forecast/
            # computed values into the scratchpad
            if (wp.alt_cstr_type == nil and wp.speed_cstr_type == nil) {
                var f = boeing737.fmc.forecastForWP(me._wpIndexFromModel(index));
                # forecasts aren't waypoints, but intentionally have the same field
                # names for comptability
                cdu.setScratchpad(CDU.formatWayptSpeedAltitude(f));
                return 1;
            }
        }

        var p = CDU.parseSpeedAltitudeConstraint(sp);
        print('Set leg speed/altitude restriction');
        return 1;
    },

    pageStatus: func(page) {
        if (me._modDirect != nil) return CDU.STATUS_MOD;
        if (flightplan().active) return CDU.STATUS_ACTIVE;
        return nil;
    },

    firstLineForRteData: func 0,
    countForRteData: func { return me.countForLegs() + 1; },
    dataForRteData: func(index)
    {
        var wp = me._wpFromModel(index);
        var f = boeing737.fmc.forecastForWP(me._wpIndexFromModel(index)); 

        var eta = sprintf("%02d%02dZ",f.eta_hour,f.eta_min);
		var winds = CDU.formatBearingSpeed(f.wind_bearing, f.wind_speed);

        return wp.wp_name ~ '  ' ~ eta ~ '   ' ~ winds;
    },

    haveModDirect: func { return (me._modDirect != nil); },
    toggleAbeamPoints: func {
        print('Toggle abeam points');
    },

    _findWaypointByIdent: func(ident)
    {
        var fp = flightplan();
        var cur = fp.active ? fp.current : 0;
        for (var i=cur; i < fp.getPlanSize(); i+=1) {
            var wp = fp.getWP(i);
            print('wp:' ~ i ~ ' ' ~ wp.wp_name);
            if (wp.wp_name == ident) return wp;
        }
        return nil;
    }
};

var legsModel = LegsModel.new();

##################

var InterceptCourseAction = 
{
    new: func {
        var m = {
            parents: [InterceptCourseAction, CDU.Action.new(lbl: nil, lsk:'R6', title:'---- ~INTC CRS')],
            _course: nil,
            _presetCourse: nil}
        ;
        return m;
    },

    isEnabled: func { legsModel.haveModDirect(); },

    setPresetCourse: func(pc) {
        _presetCourse = pc;
        _course = nil;
    },

    label: func {
        if (me._course != nil) return '' ~ me._course;
        return (me._presetCourse != nil) ? '~' ~ me._presetCourse : '---';
    },

    showArrow: func {
        if (me._course == nil and me._presetCourse != nil) return 1;
        return 0;
    },

    exec: func {
        var sp = cdu.getScratchpad();
        if (sp == '') {
            if (me._presetCourse != nil) {
                me._course = me._presetCourse;
            }
        } else {
            var hdg = math.mod(num(sp), 360);
            me._course = hdg;
            cdu.clearScratchpad();
        }
    }
};

##################

var RNPAction = 
{
    new: func {
        var m = {
            parents: [RNPAction, CDU.Action.new(lbl: nil, lsk:'L6', title:' ~RNP/ACTUAL----', dynamic:1)]};
        return m;
    },

    label: func {
        sprintf("%4.2f/%4.2fNM", 2, 0.05);
    },

    showArrow: func 0,
    isEnabled: func { !legsModel.haveModDirect(); }
};

##################


var legsPage = CDU.MultiPage.new(cdu:cdu, title:"      RTE 1 LEGS", 
    model:legsModel, dynamicActions:1);
legsModel.page = legsPage;

legsPage.addAction(CDU.Action.new('RTE DATA', 'R6', 
    func { cdu.displayPageByTag("route-data"); }, 
    func { 
		return flightplan().active and (getprop('instrumentation/efis/mfd/mode-num') != 3);
	}
));

# note spaces in title to ensure we over-write 'RTE DATA' when updating
legsPage.addAction(CDU.Action.new('    STEP', 'R6', func {
    var cur = getprop('instrumentation/efis/inputs/plan-wpt-index');
    if ((cur += 1) >= flightplan().getPlanSize()) 
        cur = flightplan().current;
    
    setprop('instrumentation/efis/inputs/plan-wpt-index', cur);
}, 
func {
    getprop('instrumentation/efis/mfd/mode-num') == 3;
}
));

legsPage.addAction(RNPAction.new());

legsPage.addAction(CDU.Action.new('ERASE', 'L6', 
	func { cdu.cancelExec(); },
	func { legsModel.haveModDirect(); }
));

legsPage.addAction(CDU.Action.new('~ABEAM PTS', 'R5', 
	func { legsModel.toggleAbeamPoints(); },
	func { legsModel.haveModDirect(); }
));

var intcAct = InterceptCourseAction.new();
legsPage.addAction(intcAct);
legsModel.setInterceptAction(intcAct);

# first line is a different field, since it needs to update dynamically
legsPage.addField(CDU.ScrolledField.new(tag:'ActiveLeg', selectable:1, dynamic:1));
legsPage.addField(CDU.ScrolledField.new(tag:'Legs', selectable:1));
legsPage.addField(CDU.ScrolledField.new(tag:'SpeedAlt', alignRight:1));

cdu.addPage(legsPage, "legs");

#############

var rteDataPage = CDU.MultiPage.new(cdu:cdu, title:"      RTE 1 DATA", model:legsModel, dynamicActions:1);

rteDataPage.addAction(CDU.Action.new('LEGS', 'R6', 
    func { cdu.displayPageByTag("legs"); }
));

# request winds action?

rteDataPage.addField(CDU.ScrolledField.new(tag:'RteData', selectable:1, dynamic:1));
rteDataPage.addField(CDU.Field.new(pos:'L1', title:'~        ETA   WIND', tag:''));
cdu.addPage(rteDataPage, "route-data");

