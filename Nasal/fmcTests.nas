var _fmc = nil;
var _cdu = nil;

var enterLSK = func(entry, lsk)
{
    _cdu.setScratchpad(entry);
    _cdu.lsk(lsk);
}

var execTest1 = func() 
{
    print("Running FMC test 1");
    _cdu = Boeing.cdu;

    setprop('instrumentation/fmc/settings/ref-airport', 'EDDM');
    setprop('instrumentation/fmc/pos-init-complete', 1);

    # route page

    var routePage = Boeing.cdu.getPage('route');
    Boeing.cdu.displayPage(routePage);

    enterLSK('EDDM', 'L1');
    enterLSK('EGKK', 'R1');
    enterLSK('KL1278', 'R2');

    # should select 'departure' page
    _cdu.lsk('R6');
    print("Page title is:" ~ _cdu.currentPage().title());

    # select runway


# perf init pages

    setprop('instrumentation/fmc/gross-weight-lbs', 60 * 1000);
    
    # CDU entry of cruise altitude
    var perfPage = Boeing.cdu.getPage('performance');
    Boeing.cdu.displayPage(perfPage);
    
    enterLSK('FL340', 'R1');
    Boeing.cdu.button_exec();

    # reserves
    enterLSK('2.1', 'L4');

    # cost index  
    enterLSK('200', 'L5');

    # limits page
    var n1Preflight = Boeing.cdu.getPage('thrust-lim');
    Boeing.cdu.displayPage(n1Preflight);
    
    # assumed temp
    enterLSK('20', 'L1');

    # select CLB-1
    Boeing.cdu.lsk('R3');

    # takeoff page
    _fmc.setTakeoffFlaps(10);
};

var init = func(fmc)
{
    print("Registering FMC test scripts");
    _fmc = fmc;
    fmc.execTest1 = execTest1;
}
