
var DescentModel = 
{
    new: func()
    {
      m = {parents: [DescentModel, CDU.AbstractModel.new()]};
      return m;
    },

    pageTitle: func {
        var m = oeing737.fmc.activeDescentMode();

        # easy two cases
        if (m == boeing737.FMC.MODE_DES_ECON_PATH) return 'ECON PATH DES';
        if (m == boeing737.FMC.MODE_DES_SPEED) return 'SPD DES';

        # SPD_PATH mode
        if (cm == boeing737.FMC.MODE_DES_SPEED_PATH) {
            var speed = { knots: getprop(FMC ~ 'descent/target-speed-kts'),
                            mach: getprop(FMC ~ 'descent/target-speed-mach')};

            if (speed.mach and speed.knots) {
                var aboveCrossover = boeing737.fmc.isAboveCrossover(knots, mach);
                if (!aboveCrossover) sped.mach = nil;
            }

            if (speed.mach) return sprintf("M%.03d PATH DES", speed.mach * 1000);
            return sprintf('%3d KT DES', speed.knots);
        }

        # handle RTA DES in the future

        print('CDU DES: invalid descent mode');
        return 'FIXME';
    },

    pageStatus: func(page) {
        # TODO : determine DEScent MODification modes
        if (boeing737.fmc.activeFlightPhase() == boeing737.FMC.PHASE_DESCENT)
            return CDU.STATUS_ACTIVE;
        return nil;
    },

    dataForDesNow: func
    {
        if (boeing737.fmc.activeFlightPhase() == boeing737.FMC.PHASE_DESCENT)
            return 'RTA';
        return 'DES NOW';
    },

    titleForEndDescentAltitude: func
    {
        var edAlt = getprop(FMC ~ 'descent/end-altitude-ft');
        if (edAlt == nil) return nil; # not displayed
        return '~ E/D ALT';
    },

    dataForEndDescentAltitude: func
    {
        var edAlt = getprop(FMC ~ 'descent/end-altitude-ft');
        if (edAlt == nil) return nil; # not displayed
        return CDU.formatAltitude(edAlt);
    },
 
    dataForTargetSpeed: func
    {
        var speed = { knots: getprop(FMC ~ 'descent/target-speed-kts'),
                        mach: getprop(FMC ~ 'descent/target-speed-mach')};
        return CDU.formatSpeedMachKnots(speed.mach, speed.knots);
    },

    titleForNextRestriction: func
    {
        var wp = getprop(FMC ~ 'descent/restriction-waypoint');
        if (wp == nil) return nil; # blank if no down-route restriction

        # blank for SPD DES
        if (boeing737.fmc.activeDescentMode() == boeing737.FMC.MODE_DES_SPEED)
            return nil;

        return '~AT ' ~ wp;
    },

    dataForNextRestriction: func 
    {
        var wp = getprop(FMC ~ 'descent/restriction-waypoint');
        if (wp == nil) return nil; # blank if no down-route restriction

        # blank for SPD DES
        if (boeing737.fmc.activeDescentMode() == boeing737.FMC.MODE_DES_SPEED)
            return nil;

        var spd = getprop(FMC ~ 'descent/restriction-speed-kts');
        var alt = getprop(FMC ~ 'descent/restriction-altitude-ft');
        return CDU.formatSpeedAltitude(spd, alt);
    },

    titleForToRestriction: func
    {
        if (boeing737.fmc.activeFlightPhase() == boeing737.FMC.PHASE_DESCENT) {
            var wp =  getprop(FMC ~ 'descent/restriction-waypoint');
            if (wp == nil) return nil;
            
            return '~TO ' ~ wp;
        } else {
            # to top of descent
            return '~TO T/D';
        }
    },

    dataForToRestriction: func
    {
        var distance = 10.0;
        var timeSec = 100;

        # time / distance to the restriction
        if (boeing737.fmc.activeFlightPhase() == boeing737.FMC.PHASE_DESCENT) {
            var wp =  getprop(FMC ~ 'descent/restriction-waypoint');
            if (wp == nil) {
                # FMC handbook doesn't state what happens in this case
                # let's blank the restriction
                return nil;
            }
            distance = getprop(FMC ~ 'descent/restriction-distance-nm');
            timeSec = getprop(FMC ~ 'descent/restriction-time-zulu');
        } else {
            distance = getprop(FMC ~ 'descent/to-top-distance-nm');
            timeSec = getprop(FMC ~ 'descent/to-top-time-sec');
        }

        return CDU.formatTimeDistance(timeSec, distance);
    },

    dataForTargetSpeed: func
    {
        return CDU.formatSpeedMachKnots(getprop(FMC ~ 'descent/target-speed-mach'),
            getprop(FMC ~ 'descent/target-speed-kts'));
    },

    editTargetSpeed: func(s)
    {
        boeing737.fmc.enterDescentTargetSpeed(s);
    },

    titleForSpeedRestriction: func
    {
        return '~ SPD REST';
    },

    dataForSpeedRestriction: func
    {
        return CDU.formatSpeedAltitude(getprop(FMC ~ 'descent/restriction-speed-kts'),
            getprop(FMC ~ 'descent/restriction-altitude-ft'));
    },

    titleForRestriction: func
    {
        return '~WPT/ALT';
    },

    dataForRestriction: func
    {
        var wpt = getprop(FMC ~ 'descent/restriction-waypt');
        var alt = getprop(FMC ~ 'descent/restriction-altitude-ft');
        return wpt ~ '/' ~ CDU.formalAltitude(alt);
    },

    editRestriction: func(s)
    {
        print('Manually entered restriction');
    },

    titleForVerticalDeviation: func
    {
        var active = getprop(FMC ~ 'descent/flight-path-active');
        if (active) return '~ VERT DEV';
        return nil;
    },

    dataForVerticalDeviation: func
    {
        var active = getprop(FMC ~ 'descent/flight-path-active');
        if (!active) return nil;

        var val = getprop(FMC ~ 'descent/vertical-deviation-ft');
        if (val < 0) {
            return sprintf('%4d~LO', val);
        }

        return sprintf('%4d~HI', val);
    },

    titleForFlightPath: func
    {
        var active = getprop(FMC ~ 'descent/flight-path-active');
        if (!active) return nil;
        return '~FPA  V/B   V/S';
    },

    dataForFlightPath: func
    {
        var active = getprop(FMC ~ 'descent/flight-path-active');
        if (!active) return nil;

        var fpa = getprop(FMC ~ 'descent/flight-path-angle-deg');
        var vb = fpa;
        var vs = getprop(FMC ~ 'descent/vertical-speed-fpm');
        return sprintf('%3.1f  %3.1f %5d', fpa, vb, vs);
    },

    # toggle between path and speed modes
    dataForPathOrSpeed: func 
    {
        var md = boeing737.fmc.activeDescentMode();
        if (md == boeing737.fmc.MODE_DES_SPEED) {
            return 'PATH';
        }
        return 'SPEED';
    },

    selectPathOrSpeed: func
    {
        var md = boeing737.fmc.activeDescentMode();
        if (md == boeing737.fmc.MODE_DES_SPEED) {
            boeing737.fmc.selectDescentMode(boeing737.fmc.MODE_DES_ECON_PATH);
        } else {
            boeing737.fmc.selectDescentMode(boeing737.fmc.MODE_DES_SPEED);
        }
    },

    dataForDesNow: func
    {
        var phase = boeing737.fmc.activeFlightPhase();
        if (phase >= boeing737.fmc.PHASE_DESCENT) {
            return 'RTA';
        }

        return 'DES NOW';
    },

    selectDesNow: func
    {
        var phase = boeing737.fmc.activeFlightPhase();
        if (phase >= boeing737.fmc.PHASE_DESCENT) {
            print ('Should execute DESCENT RTA');
        } else {
            boeing737.fmc.doDescentNow();
        }
    }
};

var descent = CDU.Page.new(owner:cdu, title:"             DES", model:DescentModel.new());

descent.addField(CDU.Field.new(pos:'L1', title:'~E/D ALT', tag:'EndDescentAltitude'));
descent.addField(CDU.Field.new(pos:'R1', tag:'NextRestriction'));
descent.addField(CDU.Field.new(pos:'L2', title:'~TGT SPD', tag:'TargetSpeed'));
descent.addField(CDU.Field.new(pos:'R2', tag:'ToRestriction'));

descent.addField(CDU.Field.new(pos:'L3', tag:'SpeedRestriction'));
descent.addField(CDU.Field.new(pos:'R3', tag:'Restriction'));

descent.addField(CDU.Field.new(pos:'L4', tag:'VerticalDeviation'));
descent.addField(CDU.Field.new(pos:'R4', tag:'FlightPath'));

descent.addAction(CDU.Action.new('ECON', 'L5', func {
    boeing737.fmc.selectDescentMode(boeing737.fmc.MODE_DES_ECON_PATH);
} ));

descent.addAction(CDU.Action.new('FORECAST', 'L6', func {
    print('Implement descent forecast')
} ));

descent.addField(CDU.Field.new(pos:'R5', tag:'PathOrSpeed', selectable:1));
descent.addField(CDU.Field.new(pos:'R6', tag:'DesNow', selectable:1));

descent.fixedSeparator = [4, 4];

cdu.addPage(descent, "descent");
