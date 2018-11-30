var DeparturesModel = 
{
    new: func(apt)
    {
      m = {parents: [DeparturesModel, CDU.AbstractModel.new()]};
      m._airport = apt;
      
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
    countForTransitions: func 1,
    
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
        return 'TRANS';
    }
};

var makeDeparturesPage = func(apt)
{
    if (apt == nil) return nil;
    
    var mdl = DeparturesModel.new(apt);
    var pg = CDU.MultiPage.new(cdu:cdu, title:"   " ~ (apt.id or "    ") ~ " DEPARTURES", model:mdl);
    
    pg.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("departure-arrival");} ));
    pg.addAction(CDU.Action.new('ROUTE', 'R6', func {cdu.displayPageByTag("route");} ));
    
    pg.addField(CDU.ScrolledField.new(tag:'SIDs', selectable:1));
    pg.addField(CDU.ScrolledField.new(tag:'Runways', selectable:1, alignRight:1));
    pg.addField(CDU.ScrolledField.new(tag:'Transitions', selectable:1));
    
    return pg;
}

var ArrivalsModel = 
{
    new: func(apt)
    {
      m = {parents: [ArrivalsModel, CDU.AbstractModel.new()]};
      m._airport = apt;
      
      var fp = flightplan();
      m._runways = keys(apt.runways);
      m._selectedRunway = (fp.destination_runway != nil) ? fp.destination_runway.id : nil;
      m._stars = (m._selectedRunway != nil) ? apt.stars(m._selectedRunway) : apt.stars();
      m._selectedSTAR = (fp.star != nil) ? fp.star.id : nil;
      return m;
    },
    
    firstLineForSTARs: func 0,
    countForSTARs: func {
		if (me._selectedSTAR != '' and me._selectedSTAR != nil) return 1;
		return size(me._stars) or 1;
	},
    firstLineForRunways: func 0,
    countForRunways: func {
		if (me._selectedRunway != '' and me._selectedRunway != nil) return 1;
		return size(me._runways) or 1;
	},
    firstLineForTransitions: func { me.countForSTARs(); },
    countForTransitions: func 6,
    
    titleForSTARs: func(index) { (index == 0) ? '~STARS' : ''; },
    titleForRunways: func(index) { (index == 0) ? '~RUNWAYS' : ''; },
    titleForTransitions: func(index) { (index == 0) ? '~TRANS' : ''; },
    
    dataForSTARs: func(index) {
		if (size(me._stars) == 0) return 'NONE';
		if (me._selectedSTAR != '' and me._selectedSTAR != nil) return me._selectedSTAR~ '<SEL>';
        var s = me._stars[index];
        return s;
    },
    
    selectSTARs: func(index) {
        me._selectedSTAR = me._stars[index];
        flightplan().star = me._airport.getStar(me._selectedSTAR);
        return 1;
    },
    
    dataForRunways: func(index) {
		if (me._selectedRunway != '' and me._selectedRunway != nil) return me._selectedRunway~ '<SEL>';
        var rwy = me._runways[index];
        return rwy;
    },
    
    selectRunways: func(index) {
        me._selectedRunway = me._runways[index];
        flightplan().destination_runway = me._airport.runway(me._selectedRunway);
        return 1;
    },
    
    dataForTransitions: func(index) {
        return 'TRANS' ~ index;
    }
};

var makeArrivalsPage = func(apt)
{
    var mdl = ArrivalsModel.new(apt);
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
    pg.addField(CDU.ScrolledField.new(tag:'Runways', selectable:1, alignRight:1));
    pg.addField(CDU.ScrolledField.new(tag:'Transitions', selectable:1));
    
    return pg;
}

#############

    var depArrIndex = CDU.Page.new(cdu, "DEP/ARR INDEX");
    
    depArrIndex.addField(CDU.PropField.new(pos:'L1+9', prop:'autopilot/route-manager/departure/airport'));
    depArrIndex.addField(CDU.PropField.new(pos:'L2+9', prop:'autopilot/route-manager/destination/airport'));
    depArrIndex.addField(CDU.StaticField.new(pos:'L6+9', data:'OTHER'));
    
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
    
    cdu.addPage(depArrIndex, "departure-arrival");
    
#####################

var NavdataModel = 
{
    new: func()
    {
      m = {parents: [NavdataModel, CDU.AbstractModel.new()],
           _active:nil,
           _airport:nil,
           _isWpt:0,
           _isNavaid:0,
           _isRunway:0,
           _isAirport:0
           };
      return m;
    },
    
    _selectedAirportOrRunway: func() { return me._isAirport or me._isRunway; },
    _selectedNotWpt: func { return !me._isWpt; },
    
	dataForIdent: func {
		if (me._active == nil)  return CDU.EMPTY_FIELD5;
		if (me._isRunway) return me._airport~me._active.id;
		return me._active.id;
	},
	
    editIdent: func(scratch) {
        if (scratch == 'DELETE') return me._clear();
		if (size(scratch) < 2) return 0;
        
		me._isAirport = me._isNavaid = me._isWpt = me._isRunway = 0;
        
		var apt = airportinfo(substr(scratch,0,4));
		if (apt != nil) {
			var rwy = apt.runway(substr(scratch,4));
			me._airport = apt.id;
		}
		
        if (size(var navs = findNavaidsByID(scratch)) > 0) {
			me._active = navs[0];
			me._isNavaid = 1;
		} elsif (rwy != nil) {
            me._active = rwy;
            me._isRunway = 1;
        } elsif (apt != nil and size(scratch) == 4) {
			me._active = apt;
			me._isAirport = 1;
		} elsif (size(var fixes = findFixesByID(scratch)) > 0) {
            me._active = fixes[0];
            me._isWpt = 1;
		} else return 0;
        return 1;
    },
    
    _clear: func()
    {
        me._active = nil;
        me._isNavaid = me._isWpt = me._isRunway = me._isAirport = 0;
        return 1;
    },
    
    titleForLatitude: func {  (me._active == nil) ? nil : '~LATITUDE'},
    titleForLongitude: func {  (me._active == nil) ? nil : '~LONGITUDE'},
    
    dataForLatitude: func {
        if (me._active == nil) return nil;
        CDU.formatLatitude(me._active.lat);
    },
    
    dataForLongitude: func {
        if (me._active == nil) return nil;
        CDU.formatLongitude(me._active.lon);
    },
    
    titleForNavaidFrequency: func { me._isNavaid ? '~FREQ' : nil; },
    dataForNavaidFrequency: func { 
        if (!me._isNavaid) return nil;
        sprintf('%6.2f', me._active.frequency / 100);
    },
    
    titleForElevation: func { (me._active!= nil) and !me._isWpt ? '~ELEVATION' : nil; },
    dataForElevation: func {
        if ((me._active == nil) or me._isWpt) return nil;
        sprintf('%4d~FT', me._active.elevation);
    },
    
    titleForRunwayLength: func { 
		if (me._active == nil) return nil;
		if (me._isRunway) return '~LENGTH';
		elsif (me._isNavaid) return '~MAG VAR';
	},
    dataForRunwayLength: func { 
		if (me._active == nil) return nil;
        if (me._isRunway)
			sprintf('%5d~FT!%4d~M', me._active.length * M2FT, me._active.length);
		elsif (me._isNavaid)
			return CDU.formatMagVar(magvar(me._active));
    },
};

var navdataPage = CDU.Page.new(owner:cdu, title:'      REF NAV DATA', model:NavdataModel.new());
navdataPage.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");} ));

navdataPage.addField(CDU.Field.new(pos:'L1', title:'~IDENT', tag:'Ident'));
navdataPage.addField(CDU.Field.new(pos:'R1', tag:'NavaidFrequency'));
navdataPage.addField(CDU.Field.new(pos:'L2', tag:'Latitude'));
navdataPage.addField(CDU.Field.new(pos:'R2', tag:'Longitude'));
navdataPage.addField(CDU.Field.new(pos:'L3', tag:'RunwayLength'));
navdataPage.addField(CDU.Field.new(pos:'R3', tag:'Elevation'));

cdu.addPage(navdataPage, 'nav-data');

var NavradioModel = 
{
    new: func()
    {
      m = {parents: [NavradioModel, CDU.AbstractModel.new()],
           };
      return m;
    },
    
    dataForvorL: func {
		var vorLFreq = getprop('instrumentation/nav[0]/frequencies/selected-mhz');
		var vorLId = getprop('instrumentation/nav[0]/nav-id');
        return sprintf('%6.02f~M!%s', vorLFreq, vorLId);
    },
	
    dataForcrsL: func {
        return sprintf('%3d', getprop('instrumentation/nav[0]/radials/selected-deg'));
    },
    editcrsL: func(scratch) {
		if (size(scratch) != 3) return 0;
        setprop('instrumentation/nav[0]/radials/selected-deg', scratch);
        return 1;
    },
    dataForradL: func {
        return sprintf('%3d', getprop('instrumentation/nav[0]/radials/reciprocal-radial-deg'));
    },
	
    dataForcrsR: func {
        return sprintf('%3d', getprop('instrumentation/nav[1]/radials/selected-deg'));
    },
    editcrsR: func(scratch) {
		if (size(scratch) != 3) return 0;
        setprop('instrumentation/nav[1]/radials/selected-deg', scratch);
        return 1;
    },
    dataForradR: func {
        return sprintf('%3d', getprop('instrumentation/nav[1]/radials/reciprocal-radial-deg'));
    },
    
    editvorL: func(scratch) {
        setprop('instrumentation/nav[0]/frequencies/selected-mhz', scratch);
        return 1;
    },
    
    dataForvorR: func {
		var vorRFreq = getprop('instrumentation/nav[1]/frequencies/selected-mhz');
		var vorRId = getprop('instrumentation/nav[1]/nav-id');
        return sprintf('%s~M!%6.02f', vorRId, vorRFreq);
    },
    
    editvorR: func(scratch) {
        setprop('instrumentation/nav[1]/frequencies/selected-mhz', scratch);
        return 1;
    },
    
    dataForadfL: func {
        return sprintf('%6.01f', getprop('instrumentation/adf[0]/frequencies/selected-khz'));
    },
    
    editadfL: func(scratch) {
        setprop('instrumentation/adf[0]/frequencies/selected-khz', scratch);
        return 1;
    },
    
    dataForadfR: func {
        return sprintf('%6.01f', getprop('instrumentation/adf[1]/frequencies/selected-khz'));
    },
    
    editadfR: func(scratch) {
        setprop('instrumentation/adf[1]/frequencies/selected-khz', scratch);
        return 1;
    },
};

var navradioPage = CDU.Page.new(owner:cdu, title:'       NAV RADIO', model:NavradioModel.new());
navradioPage.addField(CDU.Field.new(pos:'L1', title:'~VOR L', tag:'vorL', dynamic: 1));
navradioPage.addField(CDU.Field.new(pos:'R1', title:'~VOR R', tag:'vorR', dynamic: 1));
navradioPage.addField(CDU.Field.new(pos:'L2', title:'~CRS', tag:'crsL'));
navradioPage.addField(CDU.Field.new(pos:'L2+8', title:'~RADIAL', tag:'radL', dynamic: 1));
navradioPage.addField(CDU.Field.new(pos:'R2+8', title:'', tag:'radR', dynamic: 1));
navradioPage.addField(CDU.Field.new(pos:'R2', title:'~CRS', tag:'crsR'));
navradioPage.addField(CDU.Field.new(pos:'L3', title:'~ADF L', tag:'adfL'));
navradioPage.addField(CDU.Field.new(pos:'R3', title:'~ADF R', tag:'adfR'));
cdu.addPage(navradioPage, 'nav-radio');