#############

var ProgressModel = 
{
    new: func()
    {
      m = {parents: [ProgressModel, CDU.AbstractModel.new()]};
      return m;
    },
    
    titleForFrom: func { '~LAST   ALT   ATA   FUEL' },
    dataForFrom: func { getprop('instrumentation/fmc/from-wpt/ident'); },
    
    dataForFromR: func
    {
        var fromTime = getprop('instrumentation/fmc/from-wpt/time-gmt');
        if (fromTime == nil) return nil;
        
        var fromAlt = getprop('instrumentation/fmc/from-wpt/altitude-ft');
        var fromFuel = getprop('instrumentation/fmc/from-wpt/total-fuel-lbs');
        sprintf('%s %sz %5.1f', CDU.formatAltitude(fromAlt), fromTime, fromFuel);
    },
    
    titleForNext: func { '~TO      DTG  ETA' },
    dataForNext: func(index)
    {
        var fp = flightplan();
        var wp = nil;
        if (index < 2) {
            wp = fp.getWP(fp.current + index);
            if (wp == nil) return nil;
            return wp.wp_name;
        } else {
            return fp.destination;
        }    
    },
    
    dataForNextR: func(index)
    {
        var fp = flightplan();
        if (fp.currentWP() == nil) return nil;
        
        var eta = 0;
        var fuel = 0;
        
        var distance = fp.currentWP().courseAndDistanceFrom(geo.aircraft_position())[1];
        if (index < 2) {
            wp = fp.getWP(fp.current + index);
            if (wp == nil) return nil;
            if (index == 1) distance += wp.leg_distance;
        } else {
            wp = fp.getWP(fp.getPlanSize() - 1);
            distance += wp.distance_along_route - fp.currentWP().distance_along_route;
        }
        
        sprintf('%4d %4d~Z!  %4.1f', distance, eta, fuel);
    },
	
    titleForDest: func { '~DEST' },
    dataForDest: func()
    {
		var fp = flightplan();
		var distance = getprop('autopilot/route-manager/distance-remaining-nm');
        sprintf('%s    %4d', fp.destination.id, distance);
    },
    
    dataForFuel: func { 
        var total = getprop('consumables/fuel/total-fuel-lbs');
        return sprintf('%5.1f', total / 1000);
    },
    
    dataForNextAltitudeChangePoint: {
    
    },
    
    dataForWind: func {
        var windHdg = getprop('environment/wind-from-heading-deg');
        var windSpeed = getprop('environment/wind-speed-kt');
        return CDU.formatBearingSpeed(windHdg, windSpeed);
    },
    
    dataForWindKt: func { me.dataForWind() ~ '~KT'; },
    
    titleForHeadOrTailWind: func {
        (getprop('instrumentation/fmc/headwind-kt') > 0 ? '~H/WIND' : '~T/WIND')~'   WIND';
    },
    
    dataForHeadOrTailWind: func {
        var speed = abs(getprop('instrumentation/fmc/headwind-kt'));
        var windHdg = getprop('environment/wind-from-heading-deg');
        var windSpeed = getprop('environment/wind-speed-kt');
        sprintf('%3d~KT', speed)~'!   '~CDU.formatBearingSpeed(windHdg, windSpeed);
    },
    
    dataForCrosswind: func {
        var crosswind = getprop('instrumentation/fmc/crosswind-kt');
        sprintf('%s%3d~KT', (crosswind < 0) ? 'L':'R', abs(crosswind));
    },
    
    dataForSAT: func {
        var sat = getprop('environment/temperature-degc');
        sprintf('%3dgC', sat);
    },
    
    dataForCrosstrackError: func {
        var xtk = getprop('instrumentation/gps/wp/wp[1]/course-error-nm');
        if (xtk > 99.9) return nil; # FCOM - blank if error is greater than 99.9nm
        sprintf('%s%4.1f~NM', (xtk < 0) ? 'L':'R', abs(xtk));
    },
    
    dataForVerticalDeviation: func {
        return nil;
    },
    
    dataForTrueAirspeed: func {
        sprintf('%3d~KT', getprop('instrumentation/airspeed-indicator/true-speed-kt'));
    },
    
    dataForFuelUsed: func {
        sprintf('%5.1f %5.1f  %5.1f %5.1f', getprop('fdm/jsbsim/propulsion/engine[0]/fuel-used-lbs')/1000*LB2KG,getprop('fdm/jsbsim/propulsion/engine[1]/fuel-used-lbs')/1000*LB2KG,getprop('fdm/jsbsim/propulsion/engine[2]/fuel-used-lbs')/1000*LB2KG,getprop('fdm/jsbsim/propulsion/engine[3]/fuel-used-lbs')/1000*LB2KG);
    },
	
    dataForTotalFuelUsed: func {
		var totalFuelUsed = getprop('fdm/jsbsim/propulsion/engine[0]/fuel-used-lbs')+getprop('fdm/jsbsim/propulsion/engine[1]/fuel-used-lbs')+getprop('fdm/jsbsim/propulsion/engine[2]/fuel-used-lbs')+getprop('fdm/jsbsim/propulsion/engine[3]/fuel-used-lbs');
        '~ TOT '~sprintf('%5.1f', totalFuelUsed/1000*LB2KG);
    },
};

var progModel = ProgressModel.new();
var progress1 = CDU.Page.new(owner:cdu, title:"PROGRESS", model:progModel);

progress1.addAction(CDU.Action.new('NAV STATUS', 'R6', func {cdu.displayPageByTag("navigation-status");} ));
  
progress1.addField(CDU.Field.new(pos:'L1', tag:'From', dynamic: 1));
progress1.addField(CDU.Field.new(pos:'R1', tag:'FromR', dynamic: 1));
progress1.addField(CDU.Field.new(pos:'L2', rows: 2, tag:'Next', dynamic:1));
progress1.addField(CDU.Field.new(pos:'R2', rows: 2, tag:'NextR', dynamic:1));
progress1.addField(CDU.Field.new(pos:'L4', tag:'Dest', dynamic:1));

progress1.addField(CDU.Field.new(pos:'L5', tag:'NextAltitudeChangePoint', dynamic: 1));
progress1.addField(CDU.Field.new(pos:'R6', tag:'WindKt', dynamic:1));
progress1.addField(CDU.Field.new(pos:'R5', tag:'Fuel', dynamic:1));

var progress2 = CDU.Page.new(owner:cdu, title:"PROGRESS", model:progModel);
  
progress2.addField(CDU.Field.new(pos:'L1', tag:'HeadOrTailWind', dynamic: 1));
progress2.addField(CDU.Field.new(pos:'R1', tag:'Crosswind', title: '~X/WIND', dynamic:1));
progress2.addField(CDU.Field.new(pos:'L2', tag:'CrosstrackError', title:'~XTK ERROR', dynamic: 1));
progress2.addField(CDU.Field.new(pos:'R2', tag:'VerticalDeviation', title:'~VERT DEV', dynamic:1));
progress2.addField(CDU.Field.new(pos:'L3', tag:'TrueAirspeed', title:'~TAS', dynamic:1));
progress2.addField(CDU.Field.new(pos:'L3+7', tag:'TotalFuelUsed', title:'~FUEL USED', dynamic:1));
progress2.addField(CDU.Field.new(pos:'R3', tag:'SAT', title:'~SAT', dynamic:1));
progress2.addField(CDU.Field.new(pos:'L4', tag:'FuelUsed', title:'~  1     2      3     4', dynamic:1));

var progress3 = CDU.Page.new(owner:cdu, title:"RTA PROGRESS", model:progModel);
  
progress3.addField(CDU.Field.new(pos:'L1', tag:'RTAWaypoint', title:'RTA WPT'));
progress3.addField(CDU.Field.new(pos:'R1', tag:'RTATime', title:'RTA'));

var progress4 = CDU.Page.new(owner:cdu, title:"RNP PROGRESS", model:progModel);
progress4.addField(CDU.Field.new(pos:'L1', tag:'RNPWaypoint', dynamic:1));
progress4.addField(CDU.Field.new(pos:'L2', tag:'RNPActual', dynamic:1));
progress4.addField(CDU.Field.new(pos:'L3', tag:'CrosstrackError', title:'XTK ERROR', dynamic: 1));
progress4.addField(CDU.Field.new(pos:'R3', tag:'VerticalDeviation', title:'VERT DEV', dynamic:1));

CDU.linkPages([progress1, progress2, progress3, progress4]);
cdu.addPage(progress1, "progress");
cdu.addPage(progress3, "rta");
