 var initRef = CDU.Page.new(cdu);
 initRef.baseTitle = "    INIT/REF INDEX";
 initRef.addAction(CDU.Action.new('IDENT', 'L1', func {cdu.displayPageByTag("ident");} ));
 initRef.addAction(CDU.Action.new('POS', 'L2', func {cdu.displayPageByTag("pos-init");} ));
 initRef.addAction(CDU.Action.new('PERF', 'L3', func {cdu.displayPageByTag("performance");} ));
 initRef.addAction(CDU.Action.new('THRUST LIM', 'L4', func {cdu.displayPageByTag("thrust-lim");} ));
 initRef.addAction(CDU.Action.new('TAKEOFF', 'L5', func {cdu.displayPageByTag("takeoff");} ));
 initRef.addAction(CDU.Action.new('APPROACH', 'L6', func {cdu.displayPageByTag("approach");} ));
  
 initRef.addAction(CDU.Action.new('NAV DATA', 'R1', func {cdu.displayPageByTag("nav-data");} ));
 initRef.addAction(CDU.Action.new('MAINT', 'R6', func {cdu.displayPageByTag("maintenance");} ));
 cdu.addPage(initRef, "index");
  
 var ident1 = CDU.Page.new(cdu, '      IDENT');
 ident1.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");} ));
 ident1.addAction(CDU.Action.new('POS INIT', 'R6', func {cdu.displayPageByTag("pos-init");} ));
  
 ident1.addField(CDU.StaticField.new('L1', '~MODEL', getprop('instrumentation/fmc/settings/aircraft-model')));
 ident1.addField(CDU.StaticField.new('R1', '~ENGINES', getprop('instrumentation/fmc/settings/engine-model')));
  
 cdu.addPage(ident1, "ident");
  
 var menuPage = CDU.Page.new(cdu, '          MENU');
 menuPage.addAction(CDU.Action.new('FMC', 'L1', func {cdu.displayPageByTag("index");} ));
 menuPage.addAction(CDU.Action.new('CMC', 'L6', func {cdu.displayPageByTag("cmc-menu");} ));
 cdu.addPage(menuPage, "menu");