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
      m._runways = keys(apt.runways);
      m._selectedRunway = (fp.departure_runway != nil) ? fp.departure_runway.id : nil;
      m._sids = (m._selectedRunway != nil) ? apt.sids(m._selectedRunway) : apt.sids();
      m._selectedSID = (fp.sid != nil) ? fp.sid.id : nil;
      
      return m;
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
        if (s == me._selectedSID) return s ~ '<SEL>';
        return s;
    },
    
    selectSIDs: func(index) {
        me._selectedSID = me._sids[index];
        flightplan().sid = me._airport.getSid(me._selectedSID);
        return 1;
    },
    
    dataForRunways: func(index) {
        var rwy = me._runways[index];
        if (rwy== me._selectedRunway) return '<SEL>' ~ rwy;
        return rwy;
    },
    
    selectRunways: func(index) {
        me._selectedRunway = me._runways[index];
        flightplan().departure_runway = me._airport.runway(me._selectedRunway);
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
      m._selectedRunway = (fp.destination_runway != nil) ? fp.destination_runway.id : nil;
      m._stars = (m._selectedRunway != nil) ? apt.stars(m._selectedRunway) : apt.stars();
      m._selectedSTAR = (fp.star != nil) ? fp.star.id : nil;
      m.updateApproachesRunways();
      return m;
    },

    updateApproachesRunways: func
    {
        var fp = flightplan();
        if (fp.approach != nil) { #approach already selected
            me._approaches = [fp.approach.id];
            me._runways = [];
            return;
        } elsif (fp.destination_runway != nil) {
            # runway selected
            me._approaches = [];
            me._runways = [fp.destination_runway];
            return;
        }

        if (fp.star != nil) {
            me._approaches = me._airport.getApproachList(fp.star);
            me._runways = fp.star.runways;
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
        if (flightplan().approach != nil) return 0;
        return size(me._runways) or 1; 
    },

    firstLineForTransitions: func { me.countForSTARs(); },
    countForTransitions: func {
        if (me._selectedSTAR == nil) return 0;
        return size(flightplan().star.transitions);
    },
    
    titleForSTARs: func(index) { (index == 0) ? '~STARS' : ''; },
    titleForApproaches: func(index) { (index == 0) ? '~APPROACHES' : ''; },
    titleForRunways: func(index) { (index == 0) ? '~RUNWAYS' : ''; },
    titleForTransitions: func(index) { (index == 0) ? '~TRANS' : ''; },
    
    dataForSTARs: func(index) {
		if (size(me._stars) == 0) return 'NONE';
		if (me._selectedSTAR != '' and me._selectedSTAR != nil) return me._selectedSTAR~ '<SEL>';
        var s = me._stars[index];
        return s;
    },
    
    selectSTARs: func(index) {
        if (me._selectedSTAR != nil) return 0;
        me._selectedSTAR = me._stars[index];
        flightplan().star = me._airport.getStar(me._selectedSTAR);
        me.updateApproachesRunways();
        return 1;
    },
    
    dataForApproaches: func(index) {
        if (flightplan().approach != nil) {
            return '<SEL> ' ~ flightplan().approach.id;
        }
        return me._approaches[index];
    },

    selectApproaches: func(index) {
        if (flightplan().approach != nil) return 0;
        flightplan().approach = me._approaches[index];
        me.updateApproachesRunways();
        return 1;
    },

    dataForRunways: func(index) {
		if (me._selectedRunway != '' and me._selectedRunway != nil) return me._selectedRunway~ '<SEL>';
        var rwy = me._runways[index];
        return rwy;
    },
    
    selectRunways: func(index) {
        if (me._selectedRunway != nil) return 0;
        me._selectedRunway = me._runways[index];
        flightplan().destination_runway = me._airport.runway(me._selectedRunway);
        me.updateApproachesRunways();
        return 1;
    },
    
    dataForTransitions: func(index) {
        if (me._selectedSTAR == nil) return "<BOGUS>";
        return me._selectedSTAR.transitions[index].id;
    }
};

var makeArrivalsPage = func(apt, other = 0)
{
    var mdl = ArrivalsModel.new(apt, other);
    var pg = CDU.MultiPage.new(cdu:cdu, title:"   " ~ (apt.id or "    ") ~ " ARRIVALS", model:mdl);
    
    pg.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("departure-arrival");}, func { 
		return ((flightplan().star == '' or flightplan().star == nil) and (flightplan().destination_runway == '' or flightplan().destination_runway == nil)); 
	} ));
	pg.addAction(CDU.Action.new('ERASE', 'L6', func {
		flightplan().star = '';
		flightplan().destination_runway= '';
	}, func { return (flightplan().star != '' and flightplan().star != nil and flightplan().destination_runway != '' or flightplan().destination_runway != nil); } ));
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