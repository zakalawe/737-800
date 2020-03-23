var cmcMenu = CDU.Page.new(cdu);
cmcMenu.baseTitle = "      CMC MENU";
cmcMenu.addAction(CDU.Action.new('EICAS MAINT PAGES', 'L3', func {cdu.displayPageByTag("eicas-mnt");} ));
cmcMenu.fixedSeparator = [5, 5];
cdu.addPage(cmcMenu, "cmc-menu");

var eicasMnt = CDU.Page.new(cdu);
eicasMnt.baseTitle = " EICAS MAINT PAGES";
eicasMnt.addAction(CDU.Action.new('73 PERFORMANCE', 'L5', func {setprop("instrumentation/eicas/display","MNT_PERF");} ));
eicasMnt.fixedSeparator = [5, 5];
eicasMnt.addAction(CDU.Action.new('RETURN', 'L6', func {cdu.displayPageByTag("cmc-menu");} ));
cdu.addPage(eicasMnt, "eicas-mnt");


var maintenance = CDU.Page.new(cdu);
maintenance.baseTitle = "      MAINT PAGES";
maintenance.fixedSeparator = [5, 5];
maintenance.addAction(CDU.Action.new('TEST1', 'L6', func {
     boeing737.fmc.execTest1();
} ));
cdu.addPage(maintenance, "maintenance");
