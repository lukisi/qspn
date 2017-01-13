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

        // static Qspn.init.
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());

        ArrayList<int> _gsizes;
        int levels;
        compute_topology("4.2.2.2", out _gsizes, out levels);

        // Identity #0: construct Qspn.create_net.
        //   my_naddr=1:0:1:0 elderships=0:0:0:0 fp0=97272 nodeid=1215615347.
        IdentityData id0 = new IdentityData(1215615347);
        id0.local_identity_index = 0;
        id0.stub_factory = new QspnStubFactory(id0);
        compute_naddr("1.0.1.0", _gsizes, out id0.my_naddr);
        compute_fp0_first_node(97272, levels, out id0.my_fp);
        id0.qspn_manager = new QspnManager.create_net(
            id0.my_naddr,
            id0.my_fp,
            id0.stub_factory);
        // soon after creation, connect to signals.
        // TODO  id0.qspn_manager.arc_removed.connect(id0.arc_removed);
        // TODO  id0.qspn_manager.changed_fp.connect(id0.changed_fp);
        // TODO  id0.qspn_manager.changed_nodes_inside.connect(id0.changed_nodes_inside);
        // TODO  id0.qspn_manager.destination_added.connect(id0.destination_added);
        // TODO  id0.qspn_manager.destination_removed.connect(id0.destination_removed);
        // TODO  id0.qspn_manager.gnode_splitted.connect(id0.gnode_splitted);
        // TODO  id0.qspn_manager.path_added.connect(id0.path_added);
        // TODO  id0.qspn_manager.path_changed.connect(id0.path_changed);
        // TODO  id0.qspn_manager.path_removed.connect(id0.path_removed);
        // TODO  id0.qspn_manager.presence_notified.connect(id0.presence_notified);
        id0.qspn_manager.qspn_bootstrap_complete.connect(id0_qspn_bootstrap_complete);
        // TODO  id0.qspn_manager.remove_identity.connect(id0.remove_identity);

        check_id0_qspn_bootstrap_complete = false;
        // In less than 0.1 seconds we must get signal Qspn.qspn_bootstrap_complete.
        tasklet.ms_wait(100);
        assert(check_id0_qspn_bootstrap_complete);
        try {
            Fingerprint fp = (Fingerprint)id0.qspn_manager.get_fingerprint(1);
            int nodes_inside = id0.qspn_manager.get_nodes_inside(1);
            string fp_elderships = fp_elderships_repr(fp);
            assert(fp.id == 97272);
            assert(fp_elderships == "0:0:0");
            assert(nodes_inside == 1);

            fp = (Fingerprint)id0.qspn_manager.get_fingerprint(2);
            nodes_inside = id0.qspn_manager.get_nodes_inside(2);
            fp_elderships = fp_elderships_repr(fp);
            assert(fp.id == 97272);
            assert(fp_elderships == "0:0");
            assert(nodes_inside == 1);

            fp = (Fingerprint)id0.qspn_manager.get_fingerprint(3);
            nodes_inside = id0.qspn_manager.get_nodes_inside(3);
            fp_elderships = fp_elderships_repr(fp);
            assert(fp.id == 97272);
            assert(fp_elderships == "0");
            assert(nodes_inside == 1);

            fp = (Fingerprint)id0.qspn_manager.get_fingerprint(4);
            nodes_inside = id0.qspn_manager.get_nodes_inside(4);
            fp_elderships = fp_elderships_repr(fp);
            assert(fp.id == 97272);
            assert(fp_elderships == "");
            assert(nodes_inside == 1);
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();
        }

        tasklet.ms_wait(100);

        // Identity #0: call make_connectivity.
        //   from_level=1 to_level=4 changing at level 0 pos=2 eldership=1.
        {
            int ch_level = 0;
            int ch_pos = 2;
            int ch_eldership = 1;
            int64 fp_id = id0.my_fp.id;

            QspnManager.ChangeNaddrDelegate update_naddr = (_a) => {
                Naddr a = (Naddr)_a;
                ArrayList<int> _naddr_temp = new ArrayList<int>();
                _naddr_temp.add_all(a.pos);
                _naddr_temp[ch_level] = ch_pos;
                return new Naddr(_naddr_temp.to_array(), _gsizes.to_array());
            };

            ArrayList<int> _elderships_temp = new ArrayList<int>();
            _elderships_temp.add_all(id0.my_fp.elderships);
            _elderships_temp[ch_level] = ch_eldership;

            id0.my_naddr = (Naddr)update_naddr(id0.my_naddr);
            id0.my_fp = new Fingerprint(_elderships_temp.to_array(), fp_id);
            id0.qspn_manager.make_connectivity(
                1,
                4,
                update_naddr, id0.my_fp);
        }
        // In less than 0.2 seconds we must send an ETP.
        IQspnEtpMessage id0_send_etp;
        bool id0_send_is_full;
        ArrayList<NodeID> destid_set;
        id0.stub_factory.expect_send_etp(200, out id0_send_etp, out id0_send_is_full, out destid_set);
        assert(! id0_send_is_full);
        assert(destid_set.is_empty);
        {
            Json.Node n = Json.gobject_serialize(id0_send_etp);
            Json.Reader r_buf = new Json.Reader(n);
            assert(r_buf.is_object());
            assert(r_buf.read_member("node-address"));
            r_buf.end_member();
            assert(r_buf.read_member("fingerprints"));
            r_buf.end_member();
            assert(r_buf.read_member("nodes-inside"));
            r_buf.end_member();
        }

        tasklet.ms_wait(100);

        // TODO
    }

    bool check_id0_qspn_bootstrap_complete;
    void id0_qspn_bootstrap_complete()
    {
        check_id0_qspn_bootstrap_complete = true;
        debug(@"$(get_time_now()) id0_qspn_bootstrap_complete()");
    }
}