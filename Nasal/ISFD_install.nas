var _list = setlistener("sim/signals/fdm-initialized", func() {
	var ourISFD = isfd.ISFD.new();
	print('Created ISFD instance');
	# ourISFD.display(ISFDScreen); add to object - not working?

	removelistener(_list); # run ONCE
});

