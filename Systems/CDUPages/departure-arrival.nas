var DepArrModel =
{
    new: func {
        m = {
            parents: [DepArrModel, CDU.AbstractModel.new()],
        };
      return m;
    },

    dataForOtherDep: func { return "<DEP"; },
    dataForOtherArr: func { return "ARR>"; },

    selectOtherDep: func {
        var apt = airportinfo(getprop('instrumentation/fmc/navdata/other-airport[0]'));
        if (apt == nil) return 0;
        cdu.displayPage(makeDeparturesPage(apt:apt, other:1));
        return 1;
    },

    selectOtherArr: func {
        var apt = airportinfo(getprop('instrumentation/fmc/navdata/other-airport[1]'));
        if (apt == nil) return 0;
        cdu.displayPage(makeArrivalsPage(apt:apt, other:1));
        return 1;
    },

    dataForOtherAirport0: func {
        var icao = getprop('instrumentation/fmc/navdata/other-airport[0]');
        var apt = icao ? airportinfo(icao) : nil;
        return (apt == nil) ? CDU.EMPTY_FIELD4 : apt.id;
    },

    dataForOtherAirport1: func {
        var icao = getprop('instrumentation/fmc/navdata/other-airport[1]');
        var apt = icao ? airportinfo(icao) : nil;
        return (apt == nil) ? CDU.EMPTY_FIELD4 : apt.id;
    },

    editOtherAirport0: func(data) { return me.editOtherAirport(data, 0); },
    editOtherAirport1: func(data) { return me.editOtherAirport(data, 1); },

    editOtherAirport: func(data, index) {
        var apt = airportinfo(data);
        if (apt == nil) {
            cdu.message('NOT IN DATA BASE');
            return 0;
        }
        setprop('instrumentation/fmc/navdata/other-airport[' ~ index ~ ']', data);
        return 1; 
    }
};

var DeparturesModel = 
{
    new: func(apt, other)
    {
      m = {parents: [DeparturesModel, CDU.AbstractModel.new()]};
      m._airport = apt;
      m._other = other;
        
        var fp = flightplan();
        me._selectedRunway = fp.departure_runway;
        me._selectedSID = fp.sid;
        m._refreshBasedOnSelected();
      
      return m;
    },

    # called when we select something, to update our display
    _refreshBasedOnSelected: func {
        var fp = flightplan();
        me._runways = keys(me._airport.runways);
        me._sids = (me._selectedRunway != nil) ? me._airport.sids(me._selectedRunway) :  me._airport.sids();
    },
    
    firstLineForSIDs: func 0,
    countForSIDs: func { 
		var count = size(me._sids);
		if (count == 0) return 1;
		return count;
	},

    firstLineForRunways: func 0,
    countForRunways: func size(me._runways),
    firstLineForTransitions: func { me.countForSIDs(); },
    countForTransitions: func {
        if (me._selectedSID == nil) return 0;
        return size(me._selectedSID.transitions);
    },
    
    titleForSIDs: func(index) { (index == 0) ? '~SIDS' : ''; },
    titleForRunways: func(index) { (index == 0) ? '~RUNWAYS' : ''; },
    titleForTransitions: func(index) { (index == 0) ? '~TRANS' : ''; },
    
    dataForSIDs: func(index) {
		if (size(me._sids) == 0) return 'NONE';
        var s = me._sids[index];
        if ((flightplan().sid != nil) and (s == flightplan().sid.id)) {
            return s ~ '<ACT>';
        }

        if ((me._selectedSID != nil) and (s == me._selectedSID.id)) 
            return s ~ '<SEL>';
        return s;
    },
    
    selectSIDs: func(index) {
        me._selectedSID = me._airport.getSid(me._sids[index]);
        me._refreshBasedOnSelected();
        me.page.reloadModel();
        cdu.setupExec(func { me._doExec(); }, nil, flightplan().active);
        return 1;
    },

    _doExec: func {
        flightplan().sid = me._selectedSID;
        flightplan().departure_runway = me._selectedRunway;
    },
    
    dataForRunways: func(index) {
        var rwy = me._runways[index];
         if ((flightplan().departure_runway != nil) and (rwy == flightplan().departure_runway.id)) {
            return '<ACT> ' ~ rwy;
        }
        if ((me._selectedRunway != nil) and (rwy == me._selectedRunway.id)) 
            return '<SEL>' ~ rwy;
        return rwy;
    },
    
    selectRunways: func(index) {
        me._selectedRunway = me._airport.runway(me._runways[index]);
        me._refreshBasedOnSelected();
        me.page.reloadModel();
        cdu.setupExec(func { me._doExec(); }, nil, flightplan().active);
        return 1;
    },
    
    dataForTransitions: func(index) {
        if (me._selectedSID == nil) return "<BOGUS>";
        return me._selectedSID.transitions[index].id;
    }
};

var makeDeparturesPage = func(apt, other = 0)
{
    if (apt == nil) return nil;
    
    var mdl = DeparturesModel.new(apt, other);
    var pg = CDU.MultiPage.new(cdu:cdu, title:"   " ~ (apt.id or "    ") ~ " DEPARTURES", model:mdl);
    mdl.page = pg;

    # this action sometimes appears as ERASE, not sure what that does
    # clears *all* selections?
    pg.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("departure-arrival");} ));
    pg.addAction(CDU.Action.new('ROUTE', 'R6', func {cdu.displayPageByTag("route");} ));
    
    pg.addField(CDU.ScrolledField.new(tag:'SIDs', selectable:1));
    pg.addField(CDU.ScrolledField.new(tag:'Runways', selectable:1, alignRight:1));
    pg.addField(CDU.ScrolledField.new(tag:'Transitions', selectable:1));
    
    return pg;
}

var ArrivalsModel = 
{
    new: func(apt, other)
    {
      m = {parents: [ArrivalsModel, CDU.AbstractModel.new()]};
      m._airport = apt;
      m._other = other;
      
        var fp = flightplan();
        m._selectedSTAR = fp.star;
        m._selectedApproach = fp.approach;
        m._selectedRunway = (m._selectedApproach == nil) ? fp.destination_runway : nil;

      m._updateApproachesRunways();
      return m;
    },

    _updateApproachesRunways: func
    {
        me._stars = (me._selectedRunway != nil) ? me._airport.stars(me._selectedRunway) : me._airport.stars();
        if (me._selectedApproach != nil) { #approach already selected
            me._approaches = [me._selectedApproach.id];
            me._runways = [];
            return;
        } elsif (me._selectedRunway != nil) {
            # runway selected
            me._approaches = [];
            me._runways = [me._selectedRunway];
            return;
        }

        if (me._selectedSTAR  != nil) {
            me._approaches = me._airport.getApproachList(me._selectedSTAR);
            me._runways = me._selectedSTAR.runways;
        } else {
            # all approaches and runways
            me._approaches = me._airport.getApproachList(me._airport);
            me._runways = keys(me._airport.runways);
        }
    },

    firstLineForSTARs: func 0,
    countForSTARs: func { 
        if (me._selectedSTAR != nil) return 1;
        return size(me._stars) or 1; 
    },

    firstLineForApproaches: func 0,
    countForApproaches: func { size(me._approaches); },

    firstLineForRunways: func { me.countForApproaches(); },
    countForRunways: func { 
        if (me._selectedApproach != nil) return 0;
        return size(me._runways) or 1; 
    },

    firstLineForTransitions: func { me.countForSTARs(); },
    countForTransitions: func {
        if (me._selectedSTAR == nil) return 0;
        return size(me._selectedSTAR.transitions);
    },
    
    titleForSTARs: func(index) { (index == 0) ? '~STARS' : ''; },
    titleForApproaches: func(index) { (index == 0) ? '~APPROACHES' : ''; },
    titleForRunways: func(index) { (index == 0) ? '~RUNWAYS' : ''; },
    titleForTransitions: func(index) { (index == 0) ? '~TRANS' : ''; },
    
    dataForSTARs: func(index) {
		if (size(me._stars) == 0) return 'NONE';
        if (flightplan().star != nil) return flightplan().star.id ~ ' <ACT>';
		if (me._selectedSTAR != nil) return me._selectedSTAR.id ~ ' <SEL>';
        var s = me._stars[index];
        return s;
    },
    
    selectSTARs: func(index) {
        if (me._selectedSTAR != nil) return 0;
        me._selectedSTAR = me._airport.getStar(me._stars[index]);
        me._updateApproachesRunways();
        me.page.reloadModel();
        cdu.setupExec(func { me._performExec(); }, nil, flightplan().active);
        return 1;
    },

    _performExec: func {
        flightplan().star = me._selectedSTAR;
        if (me._selectedApproach != nil) {
            flightplan().approach = me._selectedApproach;
        } else if (me._selectedRunway != nil) {
            flightplan().destination_runway = me._selectedRunway;
        }
        me.page.reloadModel();
    },
    
    dataForApproaches: func(index) {
        if (flightplan().approach != nil) {
            return '<ACT> ' ~ flightplan().approach.id;
        }
        if (me._selectedApproach != nil) {
            return '<SEL> ' ~ me._selectedApproach.id;
        }
        return me._approaches[index];
    },

    selectApproaches: func(index) {
        if (flightplan().approach != nil) return 0;
        me._selectedApproach = me._airport.getIAP(me._approaches[index]);
        me._selectedRunway = nil;
        me._updateApproachesRunways();
        me.page.reloadModel();
        cdu.setupExec(func { me._performExec(); }, nil, flightplan().active);
        return 1;
    },

    dataForRunways: func(index) {
        if (flightplan().departure_runway != nil) {
            return 'ACT ' ~ flightplan().departure_runway.id;
        }
		if (me._selectedRunway != nil) {
            return 'SEL' ~ me._selectedRunway.id;
        }

        return me._runways[index];
    },
    
    selectRunways: func(index) {
        if (me._selectedRunway != nil) return 0;
        me._selectedRunway = me._runways[index];
        me._selectedApproach = nil;
        me._updateApproachesRunways();
        me.page.reloadModel();
        cdu.setupExec(func { me._performExec(); }, nil, flightplan().active);
        return 1;
    },
    
    dataForTransitions: func(index) {
        if (me._selectedSTAR == nil) return "<BOGUS>";
        return me._selectedSTAR.transitions[index];
    },

    canErase: func {
        var fp = flightplan();
        return (fp.star != nil or fp.destination_runway != nil or fp.approach != nil);
    },

    doErase: func {
       var fp = flightplan();
       fp.star = nil;
       fp.approach = nil;
       fp.destination_runway = nil;
       me._selectedApproach = nil;
       me._selectedRunway = nil;
       me._selectedSTAR = nil;
       me._updateApproachesRunways();
       me.page.reloadModel();
    }
};

var makeArrivalsPage = func(apt, other = 0)
{
    var mdl = ArrivalsModel.new(apt, other);
    var pg = CDU.MultiPage.new(cdu:cdu, title:"   " ~ (apt.id or "    ") ~ " ARRIVALS", model:mdl);
    mdl.page = pg;

    pg.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("departure-arrival");}, func { 
		return ((flightplan().star == '' or flightplan().star == nil) and (flightplan().destination_runway == '' or flightplan().destination_runway == nil)); 
	} ));
	pg.addAction(CDU.Action.new('ERASE', 'L6', func { mdl.doErase(); }, 
        func { mdl.canErase(); } ));
    pg.addAction(CDU.Action.new('ROUTE', 'R6', func {cdu.displayPageByTag("route");} ));
    
    pg.addField(CDU.ScrolledField.new(tag:'STARs', selectable:1));
    pg.addField(CDU.ScrolledField.new(tag:'Approaches', selectable:1, alignRight:1));
    pg.addField(CDU.ScrolledField.new(tag:'Runways', selectable:1, alignRight:1));
    pg.addField(CDU.ScrolledField.new(tag:'Transitions', selectable:1));
    
    return pg;
}

#############

    var depArrIndex = CDU.Page.new(owner:cdu, title:"DEP/ARR INDEX", model: DepArrModel.new());
    
    depArrIndex.addField(CDU.PropField.new(pos:'L1+9', prop:'autopilot/route-manager/departure/airport'));
    depArrIndex.addField(CDU.PropField.new(pos:'L2+9', prop:'autopilot/route-manager/destination/airport'));
    depArrIndex.addField(CDU.StaticField.new(pos:'L5+9', data:'OTHER'));
    
    depArrIndex.addAction(CDU.Action.new('DEP', 'L1', func {
            var apt = flightplan().departure;
            if (apt == nil) return;
            cdu.displayPage(makeDeparturesPage(apt));
        } 
    ));
    
    depArrIndex.addAction(CDU.Action.new('ARR', 'R1', func {
            var apt = flightplan().departure;
            if (apt == nil) return;
            cdu.displayPage(makeArrivalsPage(apt));
        } 
    ));
    
    depArrIndex.addAction(CDU.Action.new('ARR', 'R2', func {
            var apt = flightplan().destination;
            if (apt == nil) return;
            cdu.displayPage(makeArrivalsPage(apt));
        } 
    ));
    
    depArrIndex.addField(CDU.Field.new(pos:'L5', selectable:1, tag:'OtherDep'));
    depArrIndex.addField(CDU.Field.new(pos:'R5', selectable:1, tag:'OtherArr'));
    depArrIndex.addField(CDU.Field.new(pos:'L6', selectable:1, tag:'OtherAirport0')); 
    depArrIndex.addField(CDU.Field.new(pos:'R6', selectable:1, tag:'OtherAirport1')); 
    cdu.addPage(depArrIndex, "departure-arrival");