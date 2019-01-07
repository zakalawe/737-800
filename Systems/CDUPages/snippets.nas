# currently not used Nasal code


# remove DMEs paired to VORs, ILSs
    _removeDuplicateNavaids: func {
        var allNavs = me._navaids;
        foreach (var n; allNavs) {
            var colo = (n.type == 'fix') ? nil : n.colocated_dme;
            if (colo != nil) {
                me._removeNavaid(colo.guid);
            }
        }
    },

    _removeNavaid: func(guid) {
        var sz = size(me._navaids);
        for (var i=0; i < sz; i +=1) {
            var nav = me._navaids[i];
            if (nav.guid == guid) {
                if (i == 0) {
                    me._navaids = me._navaids[1:];
                } elsif (i == (sz - 1)) {
                    me._navaids = me._navaids[:-2]
                } else {
                    # middle of the array
                    me._navaids = me._navaids[:i-1] ~ me._navaids[i+1:];
                }
                
                return 1;
            }
        }

        return 0;
    }

    