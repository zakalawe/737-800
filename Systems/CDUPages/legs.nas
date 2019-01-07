var LegsModel = 
{
    _wpIndexFromModel: func(index) { 
        var fp = flightplan();
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
      return m;
    },

    firstLineForActiveLeg: func 0,
    countForActiveLeg: func 1,

    firstLineForLegs: func 1,
    countForLegs: func { 
        var fp = flightplan();
        return fp.getPlanSize() - (fp.current + 1);
    },
    firstLineForSpeedAlt: func 0,
    countForSpeedAlt: func { return me.countForLegs() + 1; },
    
    titleForActiveLeg: func(index) {
        # compute actual heading and distance to active WP
        var wp = me._wpFromModel(0);
        if (wp==nil) return nil;
        if (me._modDirect != nil) {
            wp = me._modDirect;
        }

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
        if (wp.alt_cstr_type == nil and wp.speed_cstr_type == nil) {
            var f = boeing737.fmc.forecastForWP(me._wpIndexFromModel(index));
            return '~' ~ CDU.formatWayptSpeedAltitude(f);
        }

        return CDU.formatWayptSpeedAltitude(wp);
    },
    
    editActiveLeg: func(index, sp) {
        # check SP corresponds to a point in the active plan
        print('SP is:' ~ sp);
        var wp = me._findWaypointByIdent(sp);
        if (wp == nil) {
            cdu.message('NO WAYPT IN RTE');
            return 0;
        }

        me._modDirect = w;
        cdu.setExecCallback(func me.execDirectTo(); );
       # cdu.setPageModified(1);



        return 1;
    },

    execDirectTo : func {
        print('Inform FMC were going direct now');
        flightplan().current = me._modDirect.index;
     #   cdu.clearPageModified();
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
var legsPage = CDU.MultiPage.new(cdu:cdu, title:"      RTE 1 LEGS", 
    model:legsModel, dynamicActions:1);

legsPage.addAction(CDU.Action.new('ACTIVATE', 'R6', 
	func {
		cdu.setExecCallback(activateRoute);
	},
	func {
		var inactive = (getprop('autopilot/route-manager/active') == 0);
		var fp = flightplan();
		return inactive and (fp.departure != nil) and (fp.destination != nil);
	}
));
		  
legsPage.addAction(CDU.Action.new('RTE DATA', 'R6', 
    func { cdu.displayPageByTag("route-data"); }, 
    func { 
		var act = (getprop('autopilot/route-manager/active') != 0);
		return act and (getprop('instrumentation/efis/mfd/mode-num') != 3);
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

legsPage.addAction(CDU.Action.new('~ABEAM PTS', 'R5', 
	func { legsModel.toggleAbeamPoints(); },
	func { legsModel.haveModDirect(); }
));

    
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

