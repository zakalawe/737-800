var _fmc = nil;

var execTest1 = func() 
{
    print("Running FMC test 1");

    setprop('instrumentation/fmc/settings/ref-airport', 'EDDM');
    setprop('instrumentation/fmc/pos-init-complete', 1);

    # route page

    var routePage = Boeing.cdu.getPage('route');
    Boeing.cdu.displayPage(routePage);

    Boeing.cdu.setScratchpad('EDDM');
    Boeing.cdu.lsk('L1');

    Boeing.cdu.setScratchpad('EGKK');
    Boeing.cdu.lsk('R1');

    Boeing.cdu.setScratchpad('KL1278');
    Boeing.cdu.lsk('R2');

    # should select 'departure' page
    Boeing.cdu.lsk('R6');

    print("Page title is:" ~ Boeing.cdu.currentPage().title());

    # select runway

    

# perf init pages

    setprop('instrumentation/fmc/gross-weight-lbs', 60 * 1000);
    
    # CDU entry of cruise altitude
    var perfPage = Boeing.cdu.getPage('performance');
    Boeing.cdu.displayPage(perfPage);
    
    Boeing.cdu.setScratchpad('FL340');
    Boeing.cdu.lsk('R1');
    Boeing.cdu.button_exec();

    # reserves
    Boeing.cdu.setScratchpad('2.1');
    Boeing.cdu.lsk('L4');

    # cost index
    Boeing.cdu.setScratchpad('200');
    Boeing.cdu.lsk('L5');   

    # limits page
    var n1Preflight = Boeing.cdu.getPage('thrust-lim');
    Boeing.cdu.displayPage(n1Preflight);
    
    # assumed temp
    Boeing.cdu.setScratchpad('20');
    Boeing.cdu.lsk('L1');

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
