var PerformanceModel = 
{
    new: func()
    {
      m = {parents: [PerformanceModel, CDU.AbstractModel.new()]};
      return m;
    },
    
    dataForGrossWeight: func { 
		var gw = getprop('/fdm/jsbsim/inertia/weight-kg')/1000;
        #var gw = getprop('instrumentation/fmc/gross-weight-lbs') / 1000;
        if (gw < 1.0) return CDU.BOX3_1;
        return sprintf('~%5.1f', gw);
    },
    
    dataForCruiseCG: func { 
        var ccg = getprop('instrumentation/fmc/cruise/cg-percent') ;
        if (ccg < -900) return '--.-%';
        return sprintf('~%5.1f%%', ccg);
    },
    
    dataForCruiseAltitude: func { 
        var crzAlt = getprop('autopilot/route-manager/cruise/altitude-ft') ;
        if (crzAlt <= 0) return CDU.BOX5;
        return CDU.formatAltitude(crzAlt);
    },
    
    editCruiseAltitude: func(scratch) {
        var alt = CDU.parseAltitude(scratch);
        if (alt < -1000) return 0; # parse error
        setprop('autopilot/route-manager/cruise/altitude-ft', alt);
        return 1;
    },
    
    dataForTripAltitude: func { 
        var alt = getprop('instrumentation/fmc/cruise/trip-altitude-ft') ;
        return CDU.formatAltitude(alt) ~ '/';
    },
    
    dataForZeroFuelWeight: func { 
		var zfw = getprop('/fdm/jsbsim/inertia/zero-fuel-weight-kg') / 1000;
        # var zfw = getprop('instrumentation/fmc/inputs/zero-fuel-weight-lbs') / 1000;
        if (zfw < 1.0) return CDU.BOX3_1;
        return sprintf('~%5.1f', zfw);
    },
    
    editZeroFuelWeight: func(scratch) {
        var zfw = num(scratch) * 1000;
        if ((zfw < 10000) or (zfw > 100000)) return 0;
        setprop('instrumentation/fmc/inputs/zero-fuel-weight-lbs', zfw);
        return 1;
    },
    
    dataForFuelOnBoard: func {
        var total = getprop('consumables/fuel/total-fuel-lbs');
        return sprintf('~%5.1f', total / 1000)~' ~SENSED';
    },
    
    dataForFuelReserves: func {
        var rf = getprop('instrumentation/fmc/inputs/reserve-fuel-lbs') / 1000;
        if (rf < 1.0) return CDU.BOX3_1;
        return sprintf('%5.1f', rf);
    },
    
    editFuelReserves: func(scratch) {
        var rf = num(scratch) * 1000;
        if ((rf < 900) or (rf > 50000)) return 0;
        setprop('instrumentation/fmc/inputs/reserve-fuel-lbs', rf);
        return 1;
    },
    
    dataForCostIndex: func {
        var cost = getprop('instrumentation/fmc/inputs/cost-index');
        if (cost < 0) return CDU.BOX4;
        return sprintf('%4d', cost);
    },
    
    editCostIndex: func (scratch) {
        var n = num(scratch);
        if ((n < 0) or (n > 9999)) return 0;
        setprop('instrumentation/fmc/inputs/cost-index', n);
        return 1;
    },
    
    dataForCruiseWind: func {
        var windHdg = getprop('instrumentation/fmc/inputs/cruise-wind-bearing-deg');
        var windSpeed = getprop('instrumentation/fmc/inputs/cruise-wind-knots');
        return CDU.formatBearingSpeed(windHdg, windSpeed);
    },
    
    dataForToCOAT: func {
        return '---gF ---gC';
    },
    
    dataForTransitionAltitude: func { getprop('instrumentation/fmc/inputs/transition-altitude-ft'); },
    
    dataForTimeErrorTolerance: func { getprop('instrumentation/fmc/setting/rta-tolerance-sec'); },
    dataForMinSpeed: func { return '100/.400'; },
    dataForMaxSpeed: func { return '340/.820'; },
    
	titleForSelectedTemperature: func {
		if (getprop('gear/gear/wow')) return '~SEL      OAT';
	},
	
    dataForSelectedTemperature: func {
		if (!getprop('gear/gear/wow')) return 0;
        var temp = getprop('instrumentation/fmc/inputs/assumed-temp-deg-c');
        if (temp < 0 or temp > 99) return sprintf('--        %2dgC', getprop('environment/temperature-degc'));
        return sprintf('%2dgC      %2dgC', temp, getprop('environment/temperature-degc'));
    },
    
    editSelectedTemperature: func (scratch)
    {
        if (scratch != nil) {
            var n = CDU.parseTemperatureAsCelsius(scratch);
            if ((n < 0) or (n > 99)) return 0;
            setprop('instrumentation/fmc/inputs/assumed-temp-deg-c', n);
			if (getprop("instrumentation/fmc/speeds/v1-kt") != 0) {
				setprop("instrumentation/fmc/speeds/v1-kt",0);
				setprop("instrumentation/fmc/speeds/v2-kt",0);
				setprop("instrumentation/fmc/speeds/vr-kt",0);
			}
			return 1;
        }
    },
    
    titleForTakeoffThrustLimit: func {
		var sel = getprop('instrumentation/fmc/inputs/takeoff-derate-index');
        return (sel == 0) ? '~TO N1' : sprintf('~TO %d N1',sel);
    },
    
    dataForTakeoffThrustLimit: func {
        var lim = getprop('fdm/jsbsim/eec/reference-thrust/to-n1');
        return sprintf('%5.01f', lim)~'%';
    },
    
    titleForTakeoffThrust: func(index) {
        if (getprop('gear/gear/wow')) sprintf((index == 0) ? '' : '~TO %d', index);
    },
    
    dataForTakeoffThrust: func(index) {
		if (getprop('gear/gear/wow')) {
			var derate = (index == 1) ? '5% ' : '15%';
			var s = (index == 0) ? '<TO  ' : '<-'~derate;
			var sel = getprop('instrumentation/fmc/inputs/takeoff-derate-index');
			return (sel == index) ? s ~ ' <SEL>' : s;
		} else {
			if (index == 0) return '<GA';
			elsif (index == 1) return '<CON';
			else return '<CRZ';
		}
    },
    
    selectTakeoffThrust: func(index) {
        if (getprop('gear/gear/wow')) {
			setprop('instrumentation/fmc/inputs/takeoff-derate-index', index);
			if (index != 0) me.selectClimbThrust(index);
		} else setprop('instrumentation/fmc/inputs/in-flight-thrust-mode-index', index);
        return 1;
    },
    
    titleForClimbThrust: func '',
    dataForClimbThrust: func(index) {
        var s = (index == 0) ? '  CLB>' : sprintf('CLB %d>', index);
        var sel = getprop('instrumentation/fmc/inputs/climb-derate-index');
        return (sel == index) ? '<ARM> ' ~ s : s;
    },
    
    selectClimbThrust: func(index) {
        setprop('instrumentation/fmc/inputs/climb-derate-index', index);
        return 1;
    },
    
    dataForThrustSelection: func(index) {
        var labels = ['<AUTO', '<GA  ', '<CON ', '<CLB ', '<CRZ '];
        var sel = getprop('instrumentation/fmc/inputs/thrust-limit-index');
        return labels[index] ~ ((sel == index) ? ' <ACT>' : '');
    },
    
# N1 flight version values    
    dataForThrustN1: func(index) {
        if (index == 0) return nil;
        var limitProps = [nil, 'takeoff/takeoff-thrust-n1', 
            'max-continuous-thrust-n1', 'climb/climb-thrust-n1',
            'cruise/cruise-thrust-n1'];
        
        var n1 = getprop('instrumentation/fmc/' ~ limitProps[index]);
        return sprintf('%5.1f/ %5.1f', n1 * 100, n1 * 100);
    },
    
    dataForClimb1Select: func {
        var sel = getprop('instrumentation/fmc/inputs/climb-derate-index');
        return '<CLB-1' ~ ((sel == 1) ? ' <ACT>' : '');
    },
    
    dataForClimb2Select: func {
        var sel = getprop('instrumentation/fmc/inputs/climb-derate-index');
        return ((sel == 2) ? ' <ACT>' : '') ~ 'CLB-2>';
    },
    
    selectClimb1Select: func {
        if (cdu.getScratchpad() == 'DELETE')
            setprop('instrumentation/fmc/inputs/climb-derate-index', 0);
        else
            setprop('instrumentation/fmc/inputs/climb-derate-index', 1);
        return 1;
    },
    
    selectClimb2Select: func {
        if (cdu.getScratchpad() == 'DELETE')
            setprop('instrumentation/fmc/inputs/climb-derate-index', 0);
        else
            setprop('instrumentation/fmc/inputs/climb-derate-index', 2);
        return 1;
    },  
};

#############
  var perfInit = CDU.Page.new(cdu, "       PERF INIT");
  var perfModel = PerformanceModel.new();
    
  perfInit.setModel(perfModel);
  perfInit.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");} ));
  perfInit.addAction(CDU.Action.new('THRUST LIM', 'R6', func {cdu.displayPageByTag("thrust-lim");} ));
  
  perfInit.addField(CDU.Field.new(pos:'L1', title:'~GR WT', tag:'GrossWeight', dynamic:1));
  perfInit.addField(CDU.Field.new(pos:'R1', title:'~CRZ ALT', tag:'CruiseAltitude'));
  perfInit.addField(CDU.Field.new(pos:'L2', title:'~FUEL', tag:'FuelOnBoard', dynamic:1)); 
  perfInit.addField(CDU.Field.new(pos:'L3', title:'~ZFW', tag:'ZeroFuelWeight')); 
  perfInit.addField(CDU.Field.new(pos:'L4', title:'~RESERVES', tag:'FuelReserves'));
  perfInit.addField(CDU.Field.new(pos:'R4', title:'~CRZ CG', tag:'CruiseCG'));
  perfInit.addField(CDU.Field.new(pos:'L5', title:'~COST INDEX', tag:'CostIndex')); 
    
  var perfLimits = CDU.Page.new(cdu, "PERF LIMITS");
  perfLimits.setModel(perfModel);
    
  perfLimits.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");} ));
  perfLimits.addAction(CDU.Action.new('RTA', 'R6', func {cdu.displayPageByTag("rta");} ));
    
  perfLimits.addField(CDU.Field.new(pos:'L1', title:'~TIME ERROR TOLERANCE', tag:'TimeErrorTolerance'));
  perfLimits.addField(CDU.Field.new(pos:'L2', rows: 3, title:'~MIN SPD', tag:'MinSpeed'));
  perfLimits.addField(CDU.Field.new(pos:'R2', rows: 3, title:'~MAX SPD', tag:'MaxSpeed'));
  perfLimits.addField(CDU.StaticField.new(pos:'L2+8', title:'--CLB--'));
  perfLimits.addField(CDU.StaticField.new(pos:'L3+8', title:'--CRZ--'));
  perfLimits.addField(CDU.StaticField.new(pos:'L4+8', title:'--DES--'));
      
  CDU.linkPages([perfInit, perfLimits]);
  cdu.addPage(perfInit, "performance");
    
  var n1Limit = CDU.Page.new(cdu, '       THRUST LIM');
  n1Limit.setModel(perfModel);
    
  n1Limit.addField(CDU.Field.new(pos:'L1', tag:'SelectedTemperature'));
  n1Limit.addField(CDU.Field.new(pos:'R1', tag:'TakeoffThrustLimit'));
  n1Limit.addField(CDU.Field.new(pos:'L2', tag:'TakeoffThrust', rows:3, selectable:1));
  n1Limit.addField(CDU.Field.new(pos:'R2', tag:'ClimbThrust', rows:3, selectable:1));
    
  n1Limit.addAction(CDU.Action.new('PERF INIT', 'L6', func {cdu.displayPageByTag("performance");} ));
  n1Limit.addAction(CDU.Action.new('TAKEOFF', 'R6', func {cdu.displayPageByTag("takeoff");} ));
    
  var n1Flight = CDU.Page.new(cdu, 'THRUST LIM');
  n1Flight.setModel(perfModel);
    
  cdu.addPageWithFlightVariant("thrust-lim", n1Limit, n1Flight);
  
  n1Flight.addField(CDU.Field.new(pos:'L1', tag:'ThrustSelection', rows:5, selectable:1));
  n1Flight.addField(CDU.Field.new(pos:'R2', tag:'ThrustN1', rows:5));
     
  n1Flight.addField(CDU.Field.new(pos:'L6', tag:'Climb1Select', title:'------reduced clb-------', selectable:1));
  n1Flight.addField(CDU.Field.new(pos:'R6', tag:'Climb2Select', selectable:1));
  