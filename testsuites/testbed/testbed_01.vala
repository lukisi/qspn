/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using Netsukuku;
using Netsukuku.Qspn;

namespace Testbed
{
    void testbed_01()
    {
        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // TODO Pass tasklet system to the RPC library (ntkdrpc) ??

        //static Qspn.init.
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());

        ArrayList<int> _gsizes;
        int levels;
        compute_topology("4.2.2.2", out _gsizes, out levels);

        //Identity #0: construct Qspn.create_net.
        //   my_naddr=1:0:1:0 elderships=0:0:0:0 fp0=97272 nodeid=1215615347.
        IdentityData id0 = new IdentityData(1215615347);
        id0.local_identity_index = 0;
        compute_naddr("1.0.1.0", _gsizes, out id0.my_naddr);
        compute_fp0_first_node(97272, levels, out id0.my_fp);
        id0.qspn_manager = new QspnManager.create_net(
            id0.my_naddr,
            id0.my_fp,
            new QspnStubFactory(id0));
        // soon after creation, connect to signals.
        id0.qspn_manager.arc_removed.connect(id0.arc_removed);
        id0.qspn_manager.changed_fp.connect(id0.changed_fp);
        id0.qspn_manager.changed_nodes_inside.connect(id0.changed_nodes_inside);
        id0.qspn_manager.destination_added.connect(id0.destination_added);
        id0.qspn_manager.destination_removed.connect(id0.destination_removed);
        id0.qspn_manager.gnode_splitted.connect(id0.gnode_splitted);
        id0.qspn_manager.path_added.connect(id0.path_added);
        id0.qspn_manager.path_changed.connect(id0.path_changed);
        id0.qspn_manager.path_removed.connect(id0.path_removed);
        id0.qspn_manager.presence_notified.connect(id0.presence_notified);
        id0.qspn_manager.qspn_bootstrap_complete.connect(id0.qspn_bootstrap_complete);
        id0.qspn_manager.remove_identity.connect(id0.remove_identity);

        // TODO
    }
}