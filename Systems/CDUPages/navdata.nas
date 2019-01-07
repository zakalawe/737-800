
#####################

var WaypointSelectModel =
{
    new: func(ident, navlist, cb)
    {
        m = {parents: [WaypointSelectModel, CDU.AbstractModel.new()],
           _ident: ident,
           _navaids: navlist,
           _callback: cb
        };

        return m;
    },

    # CDU logic looks for a method with this name to support dynamic titles
    pageTitle: func { 'SELECTED DESIRED ' ~ me._ident; },

    firstLineForWaypoint: func 0,
    countForWaypoint: func size(me._navaids),
    
    titleForWaypoint: func(index) {
        '~' ~ me._stringForType(me._navaids[index]) ~ ' ' ~ me._navaids[index].name;
    },

    dataForWaypoint: func(index) {
        var nav = me._navaids[index];
        var prefix = '';
        if ((nav.type == "VOR") or (nav.type == "ILS") or (nav.type == "DME")) {
            prefix = sprintf('%6.2f ', nav.frequency / 100.0);
        }
        
        return prefix ~ CDU.formatLatLonString(nav);
    },

    selectWaypoint: func(index) {
        cdu.popTemporaryPage();
        me._callback(me._navaids[index]);
        return 1;
    },

    # right and left LSKs do the same thing
    firstLineForWaypointR: func 0,
    dataForWaypointR: func nil,
    countForWaypointR: func me.countForWaypoint(),
    selectWaypointR: func(index) { me.selectWaypoint(index) },

    _typeRemap: {
        dme: 'DME',
        fix: 'WPT'
    },

    _stringForType: func(nav) {
        if (contains(me._typeRemap, nav.type))
            return me._typeRemap[nav.type];
        return nav.type;
    },
};

var makeWaypointSelect = func(cdu, ident, navlist, cb)
{
    var wptSelectPage = CDU.MultiPage.new(cdu:cdu, title:'SELECTED DESIRED', 
        model:WaypointSelectModel.new(ident, navlist, cb),
        linesPerPage: 6);
    wptSelectPage.addField(CDU.Field.new(pos:'L1', tag:'Waypoint', selectable: 1));
    wptSelectPage.addField(CDU.Field.new(pos:'R1', tag:'WaypointR', selectable: 1));
    cdu.pushTemporaryPage(wptSelectPage);
    return wptSelectPage;
};

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