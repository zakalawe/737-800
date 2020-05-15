

reload_FMC = func 
{    
    debug.dump('reloading FMC');
    setprop('/nasal/modules/b737_fmc/reload', 1);
};

#-- load fmc as reloadable module
#

# Module name (=namespace name): 
# - check 737-ng-set-common.xml <nasal> section, 
# - do NOT use any namespace already in use 
# - "b737_fmc" seems ok, check prop tree /nasal/modules/b737_fmc/reload 

var fmc_module = modules.Module.new("b737_fmc"); 

fmc_module.setDebug(1); 
# 0=(mostly) silent; 
# 1=print setlistener and maketimer calls to console;
# 2=print also each listener hit, be very careful with this! 

fmc_module.setFilePath(getprop("/sim/aircraft-dir")~"/Nasal");
fmc_module.setMainFile("fmc.nas");
fmc_module.load();

# var abspath = resolvepath("Nasal/fmcTests.nas");
# io.load_nasal(abspath, 'fmc_test_NS');

# globals['fmc_test_NS'].init(fmc);

#addcommand('fmc-reload', reload_FMC);

