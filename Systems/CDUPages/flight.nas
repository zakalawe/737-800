


#############

var ClimbModel = 
{
    new: func()
    {
      m = {
          parents: [ClimbModel, CDU.AbstractModel.new()],
          _modClimbMode : nil,
          _modSpeed : nil
        };
      return m;
    },
    
    dataForCruiseAltitude: func { 
        CDU.formatAltitude(flightplan().cruiseAltitudeFt);
    },
    
    editCruiseAltitude: func(scratch) {
        # is this even editable here?
        return 0; # FIXME
    },
    
    titleForClimbThrust: func {
        var sel = getprop('instrumentation/fmc/inputs/climb-derate-index');
        if (sel == 0) return 'CLB N1';
        return sprintf('CLB-%d N1', sel);
    },
    
    dataForClimbThrust: func {
        var n1 = getprop('instrumentation/fmc/climb/climb-thrust-n1') or 0;
        return sprintf('%4.1f/ %4.1f%%', n1 * 100, n1 * 100);
    },
    
    titleForNextRestrictionAltitude: func {
        var wp = boeing737.fmc.activeAltitudeRestrictionWP();
        if (wp == nil) return nil;
        return '~AT ' ~ wp.wp_name;
    },
    
    dataForNextRestrictionAltitude: func {
        var wp = boeing737.fmc.activeAltitudeRestrictionWP();
        if (wp == nil) return nil;
        return CDU.formatAltRestriction(wp);
    },
    
    dataForTargetSpeed: func {
        var targetKt = getprop('instrumentation/fmc/climb/target-speed-kt');
        var targetMach = getprop('instrumentation/fmc/climb/target-speed-mach');

        var kt = "";
        var m = "";

        if (targetKt != nil) {
            kt = sprintf('%3d', targetKt);
        } else {
            kt = sprintf('~%3d', getprop('instrumentation/fmc/climb/computed-speed-kt'));
        }

        if (targetMach != nil) {
            m = sprintf('.%03d', targetMach * 1000);
        } else {
            m = sprintf('~.%03d', getprop('instrumentation/fmc/climb/computed-speed-mach') * 1000);
        }

        return kt ~ "/" ~ m;
    },

    editTargetSpeed : func(sp) {
        var speed = CDU.parseKnotsMach(sp);
        if (speed == nil) {
            return -1;
        }

        me._modSpeed = speed;
        me.selectMode(boeing737.FMC.MODE_SPEED);
        return 1;
    },
    
    dataForSpeedRestriction: func {
        var restrictedSpeed = getprop('/instrumentation/fmc/active-speed-restrict-kt') or 0;
        if (restrictedSpeed < 0) return nil; # no restriction
        
        return sprintf('%3d/%s', restrictedSpeed, getprop('instrumentation/fmc/speed-restrict-reason'));
    },
    
    titleForTimeDistanceToNextRestriction: func {
        var wp = var wp = boeing737.fmc.activeAltitudeRestrictionWP();
        # FIXME isn't this to T/C if no restriction exists?
        if (wp == nil) return nil;
        return '~TO ' ~ wp.wp_name;
    },
    
    dataForTimeDistanceToNextRestriction: func {
        var wp = var wp = boeing737.fmc.activeAltitudeRestrictionWP();
        # FIXME isn't this to T/C if no restriction exists?
        if (wp == nil) return nil;
        
        var f = boeing737.fmc.forecastForWP(wp.index);
        return sprintf('%2d%2d~Z!/%3dnm',  
            f.eta_hour, f.eta_min, 
            boeing737.fmc.distanceToWP(wp));
    },
    
    dataForNextRestrictionError: func {
        #var wp = me._nextAltRestrictionWP();
        #if (wp == nil) return nil;
        return '150lo'; # TODO
    },

    pageTitle: func {
        var cm = me._modClimbMode or boeing737.fmc.climbMode();
        if (cm == boeing737.FMC.MODE_ECON) return 'ECON CLB';
        if (cm == boeing737.FMC.MODE_MAX_ANGLE) return 'MAX RATE CLB';
        if (cm == boeing737.FMC.MODE_MAX_RATE) return 'MAX ANGLE CLB';

        if (cm == boeing737.FMC.MODE_SPEED) {
            var speed = me._modSpeed or { knots: getprop('instrumentation/fmc/climb/target-speed-kt'),
                                    mach: getprop('instrumentation/fmc/climb/target-speed-mach')};

            if (speed.mach and speed.knots) {
                var aboveCrossover = boeing737.fmc.isAboveCrossover(knots, mach);
                if (!aboveCrossover) sped.mach = nil;
            }

            if (speed.mach) return sprintf("M%.03d CLB", speed.mach * 1000);
            return sprintf('%3d KT CLB', speed.knots);
        }

        print('CDU CLB: invalid climb mode');
        return 'FIXME';
    },

    pageStatus: func(page) {
        if (me._modClimbMode != nil) return CDU.STATUS_MOD;
        if (boeing737.fmc.activeFlightPhase() == boeing737.FMC.PHASE_CLIMB)
            return CDU.STATUS_ACTIVE;
        return nil;
    },

    selectMode: func(md) {
        me._modClimbMode = md;
        cdu.setupExec(func { 
            if (me._modSpeed) {
                setprop('instrumentation/fmc/climb/target-speed-kt', m._modSpeed.knots);
                setprop('instrumentation/fmc/climb/target-speed-mach', m._modSpeed.mach);
                me._modSpeed = nil;
            }

            boeing737.fmc.setClimbMode(me._modClimbMode);
            me._modClimbMode = nil;
        }, 
        func { me._modClimbMode = nil; }
        );
    }
};

var climbModel = ClimbModel.new();
var climb = CDU.Page.new(owner:cdu, title:"CLB", model:climbModel);

climb.addAction(CDU.Action.new('ECON', 'L4', func { climbModel.selectMode(boeing737.FMC.MODE_ECON); } ));
climb.addAction(CDU.Action.new('MAX RATE', 'L5', func { climbModel.selectMode(boeing737.FMC.MODE_MAX_RATE); } ));
climb.addAction(CDU.Action.new('MAX ANGLE', 'L6', func { climbModel.selectMode(boeing737.FMC.MODE_MAX_ANGLE); } ));
climb.addAction(CDU.Action.new('ENG OUT', 'R5', func {cdu.displayPageByTag("engine-out");} ));
climb.addAction(CDU.Action.new('RTA', 'R6', func {cdu.displayPageByTag("rta");} ));
  
climb.addField(CDU.Field.new(pos:'L1', title:'~CRZ ALT', tag:'CruiseAltitude'));
climb.addField(CDU.Field.new(pos:'L2', title:'~TGT SPD', tag:'TargetSpeed'));
climb.addField(CDU.Field.new(pos:'L3', title:'~SPD REST', tag:'SpeedRestriction', dynamic:1));

climb.addField(CDU.Field.new(pos:'R2', tag:'TimeDistanceToPoint', dynamic:1));
climb.addField(CDU.Field.new(pos:'R3', tag:'NextRestrictionError', dynamic:1));
climb.addField(CDU.Field.new(pos:'R4', tag:'ClimbThrust', dynamic:1));

#############

var CruiseModel = 
{
    new: func()
    {
        m = {
            parents: [CruiseModel, CDU.AbstractModel.new()],
            _modCruiseAlt: nil,
            _modCruiseMode : nil,
            _modCruiseKnots : nil,
            _modCruiseMach : nil
        };
        return m;
    },

    pageTitle: func { 
        var cm = me._modCruiseMode or boeing737.fmc.cruiseMode();
        if (cm == boeing737.FMC.MODE_ECON) return 'ECON CRZ';
        if (cm == boeing737.FMC.MODE_LRC) return 'LRC CRZ';
        if (cm == boeing737.FMC.MODE_SPEED) {
            var mach = me._modCruiseMach or flightplan().cruiseSpeedMach;
            var knots = me._modCruiseKnots or flightplan().cruiseSpeedKnots;
            var aboveCrossover = boeing737.fmc.isAboveCrossover(knots, mach);
            if (aboveCrossover)
                return sprintf("M%3.3f CRZ", mach);
            return sprintf('%3d KT CRZ', knots);
        }
        print('CDU CRS: invalid cruise mode');
        return 'FIXME';
    },

    dataForCruiseAltitude: func { 
        if (me._modCruiseAlt != nil) {
            return CDU.formatAltitude(me._modCruiseAlt);
        }

        CDU.formatAltitude(getprop('autopilot/route-manager/cruise/altitude-ft'));
    },
    
    dataForOptMaxAltitude: func {
        var optAlt = getprop('instrumentation/fmc/cruise/optimum-altitude-ft');
        var maxAlt = getprop('instrumentation/fmc/cruise/maximum-altitude-ft');
        if ((optAlt < 0) or (maxAlt < 0)) return nil;
        
        CDU.formatAltitude(optAlt) ~ '/' ~ CDU.formatAltitude(maxAlt)
    },
    
    editCruiseAltitude: func(scratch) {
        alt = CDU.parseAltitude(scratch);

        var modPage = selectPageForCruiseClimbDescent(alt);
        me._modCruiseAlt = alt;
        cdu.displayPage(modPage);

        cdu.setupExec(
            func { me.execAltitudeChange(); }, 
            func { cdu.displayPageByTag('cruise'); });

        return 1;
    },

    execCruiseAltitudeChange: func {
        boeing737.fmc.editCruiseAltitude(me._modCruiseAlt);
        me._modCruiseAlt = nil;
    },
    
    dataForTargetSpeed: func {
        var mach = me._modCruiseMach or flightplan().cruiseSpeedMach;
        var knots = me._modCruiseKnots or flightplan().cruiseSpeedKt;
        var aboveCrossover = boeing737.fmc.isAboveCrossover(knots, mach);
        if (aboveCrossover)
            return sprintf("M%3.3f", mach);
        return sprintf('%3d~KT', knots);
    },

    editTargetSpeed: func(sp) {
        var speed = CDU.parseSpeed(sp);
        if (!speed) {
            return 0;
        }

        if (contains(speed, 'mach')) {
            me._modCruiseMach = speed.mach;
        } else if (contains(speed, 'knots')) {
            me._modCruiseKnots = speed.knots;
        }

        cdu.setupExec(
            func { me.execSpeedChange(); }, 
            func { 
                me._modCruiseMach = nil;
                me._modCruiseKnots = nil;
            });
    },

    execSpeedChange: func {
        if (me._modCruiseKnots) {
            flightplan().cruiseSpeedKnots = me._modCruiseKnots;
        }

        if (me._modCruiseMach) {
            flightplan().cruiseSpeedMach = me._modCruiseMach;
        }

        boeing737.fmc.setCruiseMode(boeing737.FMC.MODE_SPEED);
        me._modCruiseMach = nil;
        me._modCruiseKnots = nil;
    },
    
    titleForTimeDistanceToPoint: func {
        var pageTag = cdu.currentPage().tag();
        if ((pageTag == 'cruise-climb') or (pageTag == 'cruise-descent')) {

            # FIXME - check if new T/D is reached before new alt, in
            # which case this falls through to the code below

            var alt = me._modCruiseAlt or flightplan().cruiseAltitudeFt;
            return sprintf('~TO ', CDU.formatAltitude(alt));
        }

        var step = getprop(FMC ~ 'cruise/step-altitude-ft') or 0;
        if (step != 0) {
            return '~STEP POINT';
        }

        # default if nothing else is going on
        return '~TO T/D';
    },

    dataForTimeDistanceToPoint: func
    {
        # if (me._modCruiseAlt != nil) {
        #     return sprintf('~TO ', CDU.formatAltitude(me._modCruiseAlt));
        # }

        # var cm = boeing737.fmc.cruiseMode();
        # if ((cm == boeing737.FMC.CRUISE_CLIMB) or (cm == boeing737.FMC.CRUISE_DESCENT)) {
        #     return sprintf('~TO ', CDU.formatAltitude(flightplan().cruiseAltitudeFt));
        # }

        # var step = getprop(FMC ~ 'input/step-altitude-ft') or 0;
        # if (step != 0) {
        #     return '~STEP POINT';
        # }

        # # default if nothing else is going on
        # return '~TO T/D';

        return '1946.1~Z!/ 4242~NM';
    },
    
    dataForStep: func() {
        var alt = getprop(FMC ~ 'cruise/step-altitude-ft') or 0;
        if (alt < 1) return CDU.EMPTY_FIELD5;
        CDU.formatAltitude(alt);
    },
    
    editStep: func(scratch) {
        if (scratch == 'DELETE') {
            boeing737.fmc.enterStepAltitude(nil);
            return 1;
        }

        var stepAlt = CDU.parseAltitude(scratch);
        if (stepAlt > 0) {
            boeing737.fmc.enterStepAltitude(stepAlt);
            return 1;
        }
        
        return 0;
    },
    
    dataForWind: func {
        var windHdg = getprop('environment/wind-from-heading-deg');
        var windSpeed = getprop('environment/wind-speed-kt');
        return CDU.formatBearingSpeed(windHdg, windSpeed);
    },
    
    dataForTurbulenceN1: func {
        var n1 = 0.90;
        return sprintf('%4.1f/ %4.1f%%', n1 * 100, n1 * 100);
    },
    
    titleForFuelAtDestination: func {
        if (flightplan().destination == nil) return nil;
        return '~FUEL AT ' ~ flightplan().destination.id;
    },
    
    dataForFuelAtDestination: func {
        # find forecast for destination runway 
        return '0.0';
    },

    titleForSavings: func {
        (me._modCruiseAlt == nil) ? nil : 'SAVINGS';
    },

    dataForSavings: func {
        # blank when executed
        if (me._modCruiseAlt == nil) return nil;
        # FIXME fmc compute savings for cruise altitude change
        return '0.0%';
    },

    dataForSpeedRestriction: func {
        var speed = getprop(FMC ~ 'cruise/speed-restriction-knots');
        var alt = getprop(FMC ~ 'cruise/speed-restriction-ft');
        
        if (speed == nil) {
            if (getprop('/position/altitude-ft') < 10000) {
                speed = 250;
                alt = 10000;
            }
        }
        
        if (speed == nil) return '---/-----';
        return CDU.formatSpeedAltitude(speed, alt);
        
    },

    editSpeedRestriction: func(sp) {
        if (sp == 'DELETE') {
            setprop(FMC ~ 'cruise/speed-restriction-knots', nil);
            setprop(FMC ~ 'cruise/speed-restriction-ft', nil);
            return 1;    
        }
        
        var d = CDU.parseSpeedAltitude(sp);
        if (contains(d, 'knots')) { 
            setprop(FMC ~ 'cruise/speed-restriction-knots', d.knots);
        }

        if (contains(d, 'altitude')) { 
            setprop(FMC ~ 'cruise/speed-restriction-ft', d.altitude);
        }
        
        return 1;
    },

    pageStatus: func(page) {
        if (me._modCruiseAlt or me._modCruiseMode or me._modCruiseKnots or me._modCruiseMach) 
            return CDU.STATUS_MOD;
        if (boeing737.fmc.activeFlightPhase() == boeing737.FMC.PHASE_CRUISE)
            return CDU.STATUS_ACTIVE;
        return nil;
    },

    selectMode: func(md) {
        me._modCruiseMode = md;
        cdu.setupExec(func { 
            boeing737.fmc.setCruiseMode(me._modCruiseMode);
            me._modCruiseMode = nil;
        }, 
        func { me._modCruiseMode = nil; }
        );
    }
};

var cruiseModel = CruiseModel.new();

var cruise = CDU.Page.new(owner:cdu, title:"CRZ", model:cruiseModel);

cruise.addAction(CDU.Action.new('ECON', 'L5', func { cruiseModel.selectMode(boeing737.FMC.MODE_ECON); }));
cruise.addAction(CDU.Action.new('LRC', 'L6', func { cruiseModel.selectMode(boeing737.FMC.MODE_LRC); }));  

cruise.addAction(CDU.Action.new('ENG OUT', 'R5', func {cdu.displayPageByTag("engine-out");} ));    
cruise.addAction(CDU.Action.new('RTA', 'R6', func {cdu.displayPageByTag("rta");} ));
  
cruise.addField(CDU.Field.new(pos:'L1', title:'~CRZ ALT', tag:'CruiseAltitude'));
cruise.addField(CDU.Field.new(pos:'L2', title:'~TGT SPD', tag:'TargetSpeed'));
cruise.addField(CDU.Field.new(pos:'L3', title:'~N1', tag:'TurbulenceN1'));

cruise.addField(CDU.Field.new(pos:'R1', title:'~STEP', tag:'Step'));
cruise.addField(CDU.Field.new(pos:'R2', tag:'TimeDistanceToPoint'));
cruise.addField(CDU.Field.new(pos:'R3', title:'~ACTUAL WIND', tag:'ActualWind'));
cruise.addField(CDU.Field.new(pos:'L4', tag:'FuelAtDestination'));
cruise.addField(CDU.Field.new(pos:'R4', tag:'Savings'));
cruise.addField(CDU.Field.new(pos:'L1+8', title:'~OPT    MAX', tag:'OptMaxAltitude', dynamic:1));

cruise.fixedSeparator = [4, 4];

var cruiseClimb = CDU.Page.new(owner:cdu, title:"CRZ CLB", tag:'cruise-climb', model:cruiseModel);

cruiseClimb.addAction(CDU.Action.new('ECON', 'L4', func { cruiseModel.selectMode(boeing737.FMC.MODE_ECON); } ));  
cruiseClimb.addAction(CDU.Action.new('MAX RATE', 'L5', func { cruiseModel.selectMode(boeing737.FMC.MODE_MAX_RATE); } ));
cruiseClimb.addAction(CDU.Action.new('MAX ANGLE', 'L6', func { cruiseModel.selectMode(boeing737.FMC.MODE_MAX_ANGLE);} ));  

cruiseClimb.addAction(CDU.Action.new('ENG OUT', 'R5', func {cdu.displayPageByTag("engine-out");} ));    
  
cruiseClimb.addField(CDU.Field.new(pos:'L1', title:'~CRZ ALT', tag:'CruiseAltitude'));
cruiseClimb.addField(CDU.Field.new(pos:'L2', title:'~TGT SPD', tag:'TargetSpeed'));
cruiseClimb.addField(CDU.Field.new(pos:'L3', title:'~SPD REST', tag:'SpeedRestriction'));

cruiseClimb.addField(CDU.Field.new(pos:'R1', tag:'TimeError'));
cruiseClimb.addField(CDU.Field.new(pos:'R2', tag:'TimeDistanceToPoint'));
cruiseClimb.addField(CDU.Field.new(pos:'R3', title:'~ACTUAL WIND', tag:'ActualWind'));
cruiseClimb.addField(CDU.Field.new(pos:'R4', tag:'Savings'));

#cruiseClimb.fixedSeparator = [4, 4];

var cruiseDes = CDU.Page.new(owner:cdu, title:"CRZ DES", tag:'cruise-descent', model:cruiseModel);

cruiseDes.addAction(CDU.Action.new('PLANNED DES', 'R5', func {} ));  
cruiseDes.addAction(CDU.Action.new('RTA', 'R6', func {cdu.displayPageByTag("rta");} ));    

# same fields as cruise-climb
cruiseDes.addField(CDU.Field.new(pos:'L1', title:'~CRZ ALT', tag:'CruiseAltitude'));
cruiseDes.addField(CDU.Field.new(pos:'L2', title:'~TGT SPD', tag:'TargetSpeed'));
cruiseDes.addField(CDU.Field.new(pos:'L3', title:'~SPD REST', tag:'SpeedRestriction'));
cruiseDes.addField(CDU.Field.new(pos:'R1', tag:'TimeError'));
cruiseDes.addField(CDU.Field.new(pos:'R2', tag:'TimeDistanceToPoint'));
cruiseDes.addField(CDU.Field.new(pos:'R3', title:'~ACTUAL WIND', tag:'ActualWind'));
cruiseDes.addField(CDU.Field.new(pos:'R4', tag:'Savings'));

cruiseDes.fixedSeparator = [4, 4];

selectPageForCruiseClimbDescent = func(newAlt) 
{
    if (newAlt < flightplan().cruiseAltitudeFt) return cruiseDes;
    return cruiseClimb;
};

#############

cdu.addPage(climb, "climb");
cdu.addPage(cruise, "cruise");

#############

var ApproachModel = 
{
    new: func()
    {
      m = {parents: [ApproachModel, CDU.AbstractModel.new()]};
      return m;
    },
	
    dataForVref25: func { 
        var vref = getprop('instrumentation/fmc/speeds/vref25-kt');
		if (vref != 0) return sprintf('25g   %3d', vref)~'~KT';
    },
	
    dataForVref30: func { 
        var vref = getprop('instrumentation/fmc/speeds/vref30-kt');
		if (vref != 0) return sprintf('30g   %3d', vref)~'~KT';
    },
	
    titleForRwyLength: func { 
		if (flightplan().departure == nil) return 0;
		sprintf('~%s%s',flightplan().departure.id,flightplan().departure_runway.id);
	},
    dataForRwyLength: func {
		if (flightplan().departure == nil) return 0;
        sprintf('%5d~FT!%4d~M', flightplan().departure_runway.length * M2FT, flightplan().departure_runway.length);
    },
	
    dataForFlaps: func {
        var f = getprop('instrumentation/fmc/landing/landing-flaps');
		var s = getprop('instrumentation/fmc/landing/vapp-kt') or '---';
        if (f != 25 and f != 30) return '--/'~s;
        return sprintf('%2d', f)~'/'~s;
    },
    
    editFlaps: func(scratch) {
        var fields = CDU.parseDualFieldInput(scratch);
        debug.dump('fields:', scratch, fields);
		if (size(fields[0]) == 3) {
			fields[1] = fields[0];
			fields[0] = nil;
		}
        
        if (fields[0] != nil) {
            var f = num(fields[0]);
			if ((f != 25) and (f != 30)) return 0;
			setprop('instrumentation/fmc/landing/landing-flaps', f);
			Boeing747.vspeeds();
        }
        
        if (fields[1] != nil) {
            var n = fields[1];
            setprop('instrumentation/fmc/landing/vapp-kt', n);
			Boeing747.vspeeds();
        }
		
        return 1;
    },
};

var approach = CDU.Page.new(owner:cdu, title:"      APPROACH REF", model:ApproachModel.new());

approach.addField(CDU.StaticField.new(pos:'L1', title:'~GROSS WT'));
#approach.addField(CDU.StaticField.new('L1+12', '~FLAPS', ' 25g'));
#approach.addField(CDU.StaticField.new('L2+12', '', ' 30g'));
approach.addField(CDU.Field.new(pos:'R1', title:'~FLAPS   VREF', tag:'Vref25'));
approach.addField(CDU.Field.new(pos:'R2', tag:'Vref30'));
approach.addField(CDU.Field.new(pos:'R4', title:'~FLAP/SPEED', tag:'Flaps'));
approach.addField(CDU.Field.new(pos:'L4', tag:'RwyLength'));
approach.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");} ));
approach.addAction(CDU.Action.new('THRUST LIM', 'R6', func {cdu.displayPageByTag("thrust-lim");} ));

cdu.addPage(approach, "approach");