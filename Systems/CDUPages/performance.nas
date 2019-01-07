var PerformanceModel = 
{
    new: func()
    {
      m = {parents: [PerformanceModel, CDU.AbstractModel.new()]};
      return m;
    },

    dataForGrossWeightCruiseCG: func {
        return me.dataForGrossWeight() ~ '/' ~ me.dataForCruiseCG();
    },
    
    dataForGrossWeight: func { 
        var entered = getprop('instrumentation/fmc/gross-weight-lbs');
        if (entered) {
            return sprintf('%5.1f', gw / 1000); #entered value
        }
		var gw = (getprop('/fdm/jsbsim/inertia/weight-kg') or 0) / 1000;
        if (gw < 1.0) return CDU.BOX3_1;
        return sprintf('~%5.1f', gw);
    },

    editGrossWeightCruiseCG: func(scratch) {
        var fields = CDU.parseDualFieldInput(scratch);
         if (fields[0] != nil) {
            var f = num(fields[0]) * 1000;
            me.enterGrossWeight(f);
        }
        
        if (fields[1] != nil) {
            var cg = num(fields[1]);
            me.editCruiseCG(cg);
        }
	
        return 1;
    },

    enterGrossWeight: func(gw)
    {
        setprop('instrumentation/fmc/gross-weight-lbs', gw * 1000);
    },
    
    dataForCruiseCG: func { 
        var ccg = getprop('instrumentation/fmc/cruise/cg-percent');
        if (ccg) {
            return sprintf('%5.1f%%', ccg);
        }

        ccg = getprop(FMC ~ 'cruise/default-cg-percent');
        return sprintf('~%5.1f%%', ccg);
    },

    editCruiseCG: func(cg)
    {
        if ((cg < 5) or (cg > 40)) return;
        setprop('instrumentation/fmc/cruise/cg-percent', cg);
    },
    
    dataForCruiseAltitude: func { 
        var crzAlt = getprop('autopilot/route-manager/cruise/altitude-ft') ;
        if (crzAlt <= 0) return CDU.BOX5;
        return CDU.formatAltitude(crzAlt);
    },
    
    editCruiseAltitude: func(scratch) {
        var alt = CDU.parseAltitude(scratch);
        if (alt < -1000) {
            cdu.postMessage(CDU.INVALID_DATA_ENTRY, 'INVALID ALTITUDE');
            return 0;
        }

        me.setModifiedData('CruiseAltitude', CDU.formatAltitude(alt));
        cdu.setupExec( func { 
            setprop('autopilot/route-manager/cruise/altitude-ft', alt);
            boeing737.fmc.updatePerformance();
        }, nil, boeing737.fmc.isPerformanceActive());

        ;
        return 1;
    },
    
    dataForTripAltitude: func { 
        var alt = getprop('instrumentation/fmc/cruise/trip-altitude-ft') ;
        return CDU.formatAltitude(alt) ~ '/';
    },
    
    dataForZeroFuelWeight: func { 
        var entered = getprop('instrumentation/fmc/inputs/zero-fuel-weight-lbs');
        if (entered)
            return sprintf('%5.1f', entered / 1000); #big text

		var zfw = (getprop('/fdm/jsbsim/inertia/zero-fuel-weight-kg') or 0) / 1000;
        if (zfw < 1.0) return CDU.BOX3_1;
        return sprintf('~%5.1f', zfw); # small text
    },
    
    selectZeroFuelWeight: func {
        # fall through to edit normally
        if (cdu.getScratchpad() != '') return -1;

        # Simulator convenience: if selected the empty ZFW, place the computed value into the sp
        var zfw = getprop('/fdm/jsbsim/inertia/weight-kg') - getprop('consumables/fuel/total-fuel-lbs');
        cdu.setScratchpad(sprintf("%.1f", zfw / 1000.0));
        return 1;
    },

    editZeroFuelWeight: func(scratch) {
        var zfw = (num(scratch) or 0) * 1000;
        print('ZFW='~zfw ~ ' for scratch:' ~ scratch);
        debug.dump(scratch, num(scratch));

        if ((zfw < 10000) or (zfw > 100000)) return 0;
        setprop('instrumentation/fmc/inputs/zero-fuel-weight-lbs', zfw);
        return 1;
    },

    enterGrossWeight: func(gw) {
        var zfw = gw - getprop('consumables/fuel/total-fuel-lbs');
        setprop('instrumentation/fmc/inputs/zero-fuel-weight-lbs', zfw);
        # should cause update of ZFW
        return 1;
    },

    dataForFuelOnBoard: func {
        var total = getprop('consumables/fuel/total-fuel-lbs');
        return sprintf('~%5.1f', total / 1000);
    },
    
    dataForFuelReserves: func {
        var rf = (getprop('instrumentation/fmc/settings/reserve-fuel-lbs') or 0) / 1000;
        if (rf < 1.0) return CDU.BOX3_1;
        return sprintf('%5.1f', rf);
    },
    
    editFuelReserves: func(scratch) {
        var rf = num(scratch) * 1000;
        if ((rf < 900) or (rf > 50000)) return 0;
        setprop('instrumentation/fmc/settings/reserve-fuel-lbs', rf);
        boeing737.fmc.updatePerformance();
        return 1;
    },
    
    dataForCostIndex: func {
        var cost = getprop('instrumentation/fmc/inputs/cost-index') or -1;
        if (cost < 0) return CDU.BOX3;
        return sprintf('%3d', cost);
    },
    
    editCostIndex: func (scratch) {
        var n = num(scratch);
        if ((n < 0) or (n > 9999)) return 0;
        setprop('instrumentation/fmc/inputs/cost-index', n);
        boeing737.fmc.updatePerformance();
        return 1;
    },
    
    dataForCruiseWind: func {
        var windHdg = getprop('instrumentation/fmc/cruise/wind-bearing-deg') or -1;
        var windSpeed = getprop('instrumentation/fmc/cruise/wind-knots') or -1;
        return CDU.formatBearingSpeed(windHdg, windSpeed);
    },
    
    editCruiseWind: func(sp) {
        var hdgSpd = CDU.parseBearingSpeed(sp);
        if (hdgSpd == nil) {
            cdu.postMessage(CDU.INVALID_DATA_ENTRY, "INVALID CRZ WIND");
            return 0;
        }

        me.setModifiedData('CruiseAltitude',CDU.formatBearingSpeed(hdgSpd.bearing, hdgSpd.speed));
        cdu.setupExec(func {
            setprop('instrumentation/fmc/cruise/wind-bearing-deg', hdgSpd.bearing);
            setprop('instrumentation/fmc/cruise/wind-knots', hdgSpd.speed);
            boeing737.fmc.updatePerformance();
        }, nil, boeing737.fmc.isPerformanceActive());
       
        return 1;
    },

    dataForToCOAT: func {
        return '---gF ---gC';
    },
    
    dataForTransitionAltitude: func { 
        getprop('instrumentation/fmc/inputs/transition-altitude-ft') or 18000; 
    },
    
    editTransitionAltitude: func(sp) {
        var ft = CDU.parseAltitude(sp);
        setprop('instrumentation/fmc/inputs/transition-altitude-ft', ft);
        return 1;
    },

    dataForTimeErrorTolerance: func { getprop('instrumentation/fmc/setting/rta-tolerance-sec'); },
    dataForMinSpeed: func { return '100/.400'; },
    dataForMaxSpeed: func { return '340/.820'; },
    
	titleForSelectedTemperature: func {
		if (getprop('gear/gear/wow')) return '~SEL      OAT';
	},
	
    dataForSelectedTemperature: func {
		if (!getprop('gear/gear/wow')) return 0;
        var temp = getprop('instrumentation/fmc/inputs/assumed-temp-deg-c') or 9999;
        if (temp < 0 or temp > 99) return sprintf('--        %2dgC', getprop('environment/temperature-degc'));
        me._formatSelTemp(temp);
    },

    _formatSelTemp: func(temp) {
        sprintf('%2dgC      %2dgC', temp, getprop('environment/temperature-degc'));
    },
    
    editSelectedTemperature: func (scratch)
    {
        if (scratch != nil) {
            var n = CDU.parseTemperatureAsCelsius(scratch) or -99;
            if ((n < 0) or (n > 99)) {
                cdu.postMessage(CDU.INVALID_DATA_ENTRY, 'INVALID ASSUMED TEMP');
                return 0;
            }

            setprop('instrumentation/fmc/inputs/assumed-temp-deg-c', n);
            boeing737.fmc.updateTakeoffThrust();
            boeing737.vspeed.clearFMCSpeeds();
			return 1;
        }
    },
    
    titleForTakeoffThrustLimit: func {
        return boeing737.fmc.takeoffThrustTitle();
    },
    
    dataForTakeoffThrustLimit: func {
        return boeing737.fmc.takeoffThrustN1();
    },
    
    titleForTakeoffThrust: func(index) {
        return '~' ~ getprop(FMC ~ 'derated-to[' ~ index ~ ']/title');
    },
    
    dataForTakeoffThrust: func(index) {
		var s = '<' ~ getprop(FMC ~ 'derated-to[' ~ index ~ ']/prompt');
        if (getprop(FMC ~ 'takeoff/derate-index') == index) {
            s ~= '<ACT>';
        }
        return s;
    },
    
    selectTakeoffThrust: func(index) {
		setprop(FMC ~ 'takeoff/derate-index', index);
        var climbIndex = getprop(FMC ~ 'derated-to[' ~ index ~ ']/climb-thrust-index');
        boeing737.fmc.updateTakeoffThrust();
        me.selectClimbThrust(climbIndex);
        return 1;
    },
    
    titleForClimbThrust: func '',
    dataForClimbThrust: func(index) {
        var s = (index == 0) ? '  CLB>' : sprintf('CLB %d>', index);
        var sel = getprop('instrumentation/fmc/climb/derate-index');
        return (sel == index) ? '<ARM> ' ~ s : s;
    },
    
    selectClimbThrust: func(index) {
        setprop('instrumentation/fmc/climb/derate-index', index);
        return 1;
    },
    
    dataForThrustSelection: func(index) {
        var labels = ['<AUTO', '<GA  ', '<CON ', '<CLB ', '<CRZ '];
        var sel = getprop('instrumentation/fmc/inputs/thrust-limit-index') or 0;
        return labels[index] ~ ((sel == index) ? ' <ACT>' : '');
    },
    
# N1 flight version values    
    dataForThrustN1: func(index) {
        if (index == 0) return nil;
        var limitProps = [nil, 'takeoff/takeoff-thrust-n1', 
            'max-continuous-thrust-n1', 'climb/climb-thrust-n1',
            'cruise/cruise-thrust-n1'];
        
        var n1 = getprop(FMC ~ limitProps[index]);
        return sprintf('%5.1f/ %5.1f', n1 * 100, n1 * 100);
    },
    
    dataForClimb1Select: func {
        var sel = getprop('instrumentation/fmc/climb/derate-index');
        return '<CLB-1' ~ ((sel == 1) ? ' <ACT>' : '');
    },
    
    dataForClimb2Select: func {
        var sel = getprop('instrumentation/fmc/climb/derate-index');
        return ((sel == 2) ? ' <ACT>' : '') ~ 'CLB-2>';
    },
    
    selectClimb1Select: func {
        if (cdu.getScratchpad() == 'DELETE')
            setprop('instrumentation/fmc/climb/derate-index', 0);
        else
            setprop('instrumentation/fmc/climb/derate-index', 1);
        return 1;
    },
    
    selectClimb2Select: func {
        if (cdu.getScratchpad() == 'DELETE')
            setprop('instrumentation/fmc/climb/derate-index', 0);
        else
            setprop('instrumentation/fmc/climb/derate-index', 2);
        return 1;
    },  

    dataForPerfInitRequest: func { "REQUEST>" },
    selectPerfInitRequest: func {
        print('Request pefect init');
        return 1;
    },

    pageStatus: func(page) {
        if (boeing737.fmc.isPerformanceActive()) return CDU.STATUS_ACTIVE;
        return nil;
    }
};

#############
  var perfInit = CDU.Page.new(owner:cdu, title:"       PERF INIT", tag:'perf-init');
  var perfModel = PerformanceModel.new();
    
  perfInit.setModel(perfModel);
  perfInit.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");} ));
  perfInit.addAction(CDU.Action.new('N1 LIMIT', 'R6', func {cdu.displayPageByTag("thrust-lim");} ));
  perfInit.addField(CDU.Field.new(pos: 'R5', title: '~PERF INIT', selectable: 1, tag:'PerfInitRequest'));

  perfInit.addField(CDU.Field.new(pos:'L1', title:'~GW/CRZ CG', tag:'GrossWeightCruiseCG', dynamic:1));
  perfInit.addField(CDU.Field.new(pos:'R1', title:'~CRZ ALT', tag:'CruiseAltitude'));
  perfInit.addField(CDU.Field.new(pos:'R2', title:'~CRZ WIND', tag:'CruiseWind'));

  # not supporting the PLANed fuel option here yet
  # (allows entering fuel for predictions before loaded)
  perfInit.addField(CDU.Field.new(pos:'L2', title:'~FUEL', tag:'FuelOnBoard', dynamic:1)); 
  perfInit.addField(CDU.Field.new(pos:'L3', title:'~ZFW', tag:'ZeroFuelWeight', selectable:1)); 
  perfInit.addField(CDU.Field.new(pos:'L4', title:'~RESERVES', tag:'FuelReserves'));
  perfInit.addField(CDU.Field.new(pos:'R4', title:'~TRANS ALT', tag:'TransitionAltitude'));
  perfInit.addField(CDU.Field.new(pos:'L5', title:'~COST INDEX', tag:'CostIndex')); 
    
  var perfLimits = CDU.Page.new(owner:cdu, title:"PERF LIMITS", tag:'perf-limits');
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
    
  var n1Limit = CDU.Page.new(owner:cdu, title:'     N1 LIMIT', tag:'n1-limit');
  n1Limit.setModel(perfModel);
    
  n1Limit.addField(CDU.Field.new(pos:'L1', tag:'SelectedTemperature'));
  n1Limit.addField(CDU.Field.new(pos:'R1', tag:'TakeoffThrustLimit'));
  n1Limit.addField(CDU.Field.new(pos:'L2', tag:'TakeoffThrust', rows:4, selectable:1));
  n1Limit.addField(CDU.Field.new(pos:'R2', tag:'ClimbThrust', rows:3, selectable:1));
    
  n1Limit.addAction(CDU.Action.new('PERF INIT', 'L6', func {cdu.displayPageByTag("performance");} ));
  n1Limit.addAction(CDU.Action.new('TAKEOFF', 'R6', func {cdu.displayPageByTag("takeoff");} ));
    
  var n1Flight = CDU.Page.new(cdu, '    N1 LIMIT');
  n1Flight.setModel(perfModel);
    
  cdu.addPageWithFlightVariant("thrust-lim", n1Limit, n1Flight);
  
  n1Flight.addField(CDU.Field.new(pos:'L1', tag:'ThrustSelection', rows:5, selectable:1));
  n1Flight.addField(CDU.Field.new(pos:'R1', tag:'ThrustN1', rows:5));
     
  n1Flight.addField(CDU.Field.new(pos:'L6', tag:'Climb1Select', title:'------reduced clb-------', selectable:1));
  n1Flight.addField(CDU.Field.new(pos:'R6', tag:'Climb2Select', selectable:1));
  