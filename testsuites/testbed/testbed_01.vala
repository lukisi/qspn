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
        // TODO  id0.qspn_manager.arc_removed.connect(something);
        // TODO  id0.qspn_manager.changed_fp.connect(something);
        id0.qspn_manager.changed_nodes_inside.connect(id0_changed_nodes_inside);
        // TODO  id0.qspn_manager.destination_added.connect(something);
        // TODO  id0.qspn_manager.destination_removed.connect(something);
        // TODO  id0.qspn_manager.gnode_splitted.connect(something);
        // TODO  id0.qspn_manager.path_added.connect(something);
        // TODO  id0.qspn_manager.path_changed.connect(something);
        // TODO  id0.qspn_manager.path_removed.connect(something);
        // TODO  id0.qspn_manager.presence_notified.connect(something);
        id0.qspn_manager.qspn_bootstrap_complete.connect(id0_qspn_bootstrap_complete);
        // TODO  id0.qspn_manager.remove_identity.connect(something);

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
            // check behaviour of changed_nodes_inside
            test_id0_changed_nodes_inside = 1;
            test_id0_changed_nodes_inside_qspnmgr = id0.qspn_manager;
            id0.qspn_manager.make_connectivity(
                1,
                4,
                update_naddr, id0.my_fp);
            assert(test_id0_changed_nodes_inside == -1);
        }
        // In less than 0.2 seconds we must call RPC send_etp.
        IQspnEtpMessage id0_send_etp;
        bool id0_send_is_full;
        ArrayList<NodeID> destid_set;
        id0.stub_factory.expect_send_etp(200, out id0_send_etp, out id0_send_is_full, out destid_set);
        assert(! id0_send_is_full);
        assert(destid_set.is_empty);
        {
            /*
             * If we do just:
                Json.Node n = Json.gobject_serialize(id0_send_etp);
               then we get a strange "Critical message" of "json_node_get_node_type: assertion 'JSON_NODE_IS_VALID (node)' failed"
               when we do a certain sequence of operations with the Json.Reader.
               That's not the case when we pass through the following:
             */
            Json.Node n0 = Json.gobject_serialize(id0_send_etp);
            Json.Generator g0 = new Json.Generator();
            g0.root = n0;
            g0.pretty = false;
            string s0 = g0.to_data(null);
            Json.Parser p0 = new Json.Parser();
            try {
                assert(p0.load_from_data(s0));
            } catch (Error e) {assert_not_reached();}
            Json.Node n = p0.get_root();


            Json.Reader r_buf = new Json.Reader(n);
            assert(r_buf.is_object());
            assert(r_buf.read_member("node-address"));
            {
                assert(r_buf.is_object());
                assert(r_buf.read_member("value"));
                {
                    assert(r_buf.is_object());
                    assert(r_buf.read_member("pos"));
                    {
                        assert(r_buf.is_array());
                        assert(r_buf.count_elements() == 4);
                        assert(r_buf.read_element(0));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 2);
                        }
                        r_buf.end_element();
                        assert(r_buf.read_element(1));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 1);
                        }
                        r_buf.end_element();
                        assert(r_buf.read_element(2));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 0);
                        }
                        r_buf.end_element();
                        assert(r_buf.read_element(3));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 1);
                        }
                        r_buf.end_element();
                    }
                    r_buf.end_member();
                }
                r_buf.end_member();
            }
            r_buf.end_member();
            assert(r_buf.read_member("fingerprints"));
            {

                assert(r_buf.is_array());
                assert(r_buf.count_elements() == 5);
                assert(r_buf.read_element(0));
                {
                    assert(r_buf.is_object());
                    assert(r_buf.read_member("value"));
                    {
                        assert(r_buf.is_object());
                        assert(r_buf.read_member("id"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 97272);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("level"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 0);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 4);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 1);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(1));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(2));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(3));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships-seed"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 0);
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_member();
                }
                r_buf.end_element();
                assert(r_buf.read_element(1));
                {
                    assert(r_buf.is_object());
                    assert(r_buf.read_member("value"));
                    {
                        assert(r_buf.is_object());
                        assert(r_buf.read_member("id"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 97272);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("level"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 1);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 3);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(1));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(2));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships-seed"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 1);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 1);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_member();
                }
                r_buf.end_element();
                assert(r_buf.read_element(2));
                {
                    assert(r_buf.is_object());
                    assert(r_buf.read_member("value"));
                    {
                        assert(r_buf.is_object());
                        assert(r_buf.read_member("id"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 97272);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("level"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 2);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 2);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(1));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships-seed"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 2);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(1));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 1);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_member();
                }
                r_buf.end_element();
                assert(r_buf.read_element(3));
                {
                    assert(r_buf.is_object());
                    assert(r_buf.read_member("value"));
                    {
                        assert(r_buf.is_object());
                        assert(r_buf.read_member("id"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 97272);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("level"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 3);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 1);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships-seed"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 3);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(1));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(2));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 1);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_member();
                }
                r_buf.end_element();
                assert(r_buf.read_element(4));
                {
                    assert(r_buf.is_object());
                    assert(r_buf.read_member("value"));
                    {
                        assert(r_buf.is_object());
                        assert(r_buf.read_member("id"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 97272);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("level"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 4);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 0);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("elderships-seed"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 4);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(1));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(2));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(3));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 1);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_member();
                }
                r_buf.end_element();
            }
            r_buf.end_member();
            assert(r_buf.read_member("nodes-inside"));
            {
                assert(r_buf.is_array());
                assert(r_buf.count_elements() == 5);
                assert(r_buf.read_element(0));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 0);
                }
                r_buf.end_element();
                assert(r_buf.read_element(1));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 0);
                }
                r_buf.end_element();
                assert(r_buf.read_element(2));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 0);
                }
                r_buf.end_element();
                assert(r_buf.read_element(3));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 0);
                }
                r_buf.end_element();
                assert(r_buf.read_element(4));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 0);
                }
                r_buf.end_element();
            }
            r_buf.end_member();
        }

        tasklet.ms_wait(100);

        // Identity #1: construct Qspn.enter_net.
        /*
           previous_identity=0.
           my_naddr=2:1:1:2 elderships=0:0:0:1 fp0=97272 nodeid=2135518399.
           guest_gnode_level=0, host_gnode_level=1.
           internal_arcs #: 0.
           external_arcs #: 1.
            #0:
              dev=eth1
              peer_mac=00:16:3E:EC:A3:E1
              source-dest=2135518399-1536684510
         */
        IdentityData id1 = new IdentityData(2135518399);
        id1.local_identity_index = 1;
        id1.stub_factory = new QspnStubFactory(id1);
        compute_naddr("2.1.1.2", _gsizes, out id1.my_naddr);
        compute_fp0(97272, "0.0.0.1", out id1.my_fp);
        ArrayList<IQspnArc> internal_arc_set = new ArrayList<IQspnArc>();
        ArrayList<IQspnArc> internal_arc_prev_arc_set = new ArrayList<IQspnArc>();
        ArrayList<IQspnNaddr> internal_arc_peer_naddr_set = new ArrayList<IQspnNaddr>();
        ArrayList<IQspnArc> external_arc_set = new ArrayList<IQspnArc>();
        external_arc_set.add(new QspnArc(id1.nodeid, new NodeID(1536684510), new Cost(10796), "00:16:3E:EC:A3:E1"));
        id1.qspn_manager = new QspnManager.enter_net(
            id1.my_naddr,
            internal_arc_set,
            internal_arc_prev_arc_set,
            internal_arc_peer_naddr_set,
            external_arc_set,
            id1.my_fp,
            id1.stub_factory,
            0,
            1,
            id0.qspn_manager);
        // soon after creation, connect to signals.
        // TODO  id1.qspn_manager.arc_removed.connect(something);
        // TODO  id1.qspn_manager.changed_fp.connect(something);
        // TODO  id1.qspn_manager.changed_nodes_inside.connect(something);
        // TODO  id1.qspn_manager.destination_added.connect(something);
        // TODO  id1.qspn_manager.destination_removed.connect(something);
        // TODO  id1.qspn_manager.gnode_splitted.connect(something);
        // TODO  id1.qspn_manager.path_added.connect(something);
        // TODO  id1.qspn_manager.path_changed.connect(something);
        // TODO  id1.qspn_manager.path_removed.connect(something);
        // TODO  id1.qspn_manager.presence_notified.connect(something);
        // TODO  id1.qspn_manager.qspn_bootstrap_complete.connect(something);
        // TODO  id1.qspn_manager.remove_identity.connect(something);

        // TODO
    }

    bool check_id0_qspn_bootstrap_complete;
    void id0_qspn_bootstrap_complete()
    {
        check_id0_qspn_bootstrap_complete = true;
        debug(@"$(get_time_now()) id0_qspn_bootstrap_complete()");
    }

    int test_id0_changed_nodes_inside = -1;
    int test_id0_changed_nodes_inside_step = -1;
    weak QspnManager? test_id0_changed_nodes_inside_qspnmgr = null;
    void id0_changed_nodes_inside(int l)
    {
        if (test_id0_changed_nodes_inside == 1)
        {
            if (test_id0_changed_nodes_inside_step == -1)
            {
                assert(l == 1);
                try {
                    int nodes_inside_l = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside_l == 0);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 1;
            }
            else if (test_id0_changed_nodes_inside_step == 1)
            {
                assert(l == 2);
                try {
                    int nodes_inside_l = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside_l == 0);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 2;
            }
            else if (test_id0_changed_nodes_inside_step == 2)
            {
                assert(l == 3);
                try {
                    int nodes_inside_l = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside_l == 0);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 3;
            }
            else if (test_id0_changed_nodes_inside_step == 3)
            {
                assert(l == 4);
                try {
                    int nodes_inside_l = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside_l == 0);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = -1;
                test_id0_changed_nodes_inside = -1;
                test_id0_changed_nodes_inside_qspnmgr = null;
            }
        }
        // else if (test_id0_changed_nodes_inside == 2)
    }
}