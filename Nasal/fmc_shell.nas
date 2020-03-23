



reload_FMC = func 
{    
    debug.dump('reloading FMC');
    
    fmc = nil;
    FMC = nil; # clear out the existing one
    
    # clear out the FMC namespace as well
    globals['fmc_test_NS'] = { };

    # resolve the path in FG_ROOT, and --fg-aircraft dir, etc
    var abspath = resolvepath("Nasal/fmc.nas");
    io.load_nasal(abspath, 'boeing737');

    fmc = FMC.new();

# add test methods
    var abspath = resolvepath("Nasal/fmcTests.nas");
    # load pages code into a seperate namespace which we defined above
    # also means we can clean out that namespace later
    io.load_nasal(abspath, 'fmc_test_NS');
    globals['fmc_test_NS'].init(fmc);
};

var abspath = resolvepath("Nasal/fmcTests.nas");
io.load_nasal(abspath, 'fmc_test_NS');

globals['fmc_test_NS'].init(fmc);

addcommand('fmc-reload', reload_FMC);

