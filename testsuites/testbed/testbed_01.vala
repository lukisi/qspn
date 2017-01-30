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
using TaskletSystem;
using Testbed;

namespace Testbed01
{
    const int64 alfa_fp0 = 97272;
    const int64 beta_fp0 = 599487;
    const int alfa0_id = 1215615347;
    const int beta0_id = 1536684510;
    const int alfa1_id = 2135518399;
    const int64 alfa1_beta0_cost = 10796;

    QspnArc arc_id1_beta0;
    Cost arc_id1_beta0_cost;
    IdentityData id0;
    IdentityData id1;

    void testbed_01()
    {
        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // static Qspn.init.
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());

        ArrayList<int> _gsizes;
        int levels;
        compute_topology("4.2.2.2", out _gsizes, out levels);

        // Identity #0: construct Qspn.create_net.
        //   my_naddr=1:0:1:0 elderships=0:0:0:0 fp0=97272 nodeid=1215615347.
        id0 = new IdentityData(alfa0_id);
        id0.local_identity_index = 0;
        id0.stub_factory = new QspnStubFactory(id0);
        compute_naddr("1.0.1.0", _gsizes, out id0.my_naddr);
        compute_fp0_first_node(alfa_fp0, levels, out id0.my_fp);
        id0.qspn_manager = new QspnManager.create_net(
            id0.my_naddr,
            id0.my_fp,
            id0.stub_factory);
        // soon after creation, connect to signals.
        // NOT NEEDED  id0.qspn_manager.arc_removed.connect(something);
        // NOT NEEDED  id0.qspn_manager.changed_fp.connect(something);
        id0.qspn_manager.changed_nodes_inside.connect(id0_changed_nodes_inside);
        // NOT NEEDED  id0.qspn_manager.destination_added.connect(something);
        // NOT NEEDED  id0.qspn_manager.destination_removed.connect(something);
        // NOT NEEDED  id0.qspn_manager.gnode_splitted.connect(something);
        // NOT NEEDED  id0.qspn_manager.path_added.connect(something);
        // NOT NEEDED  id0.qspn_manager.path_changed.connect(something);
        // NOT NEEDED  id0.qspn_manager.path_removed.connect(something);
        // NOT NEEDED  id0.qspn_manager.presence_notified.connect(something);
        id0.qspn_manager.qspn_bootstrap_complete.connect(id0_qspn_bootstrap_complete);
        // NOT NEEDED  id0.qspn_manager.remove_identity.connect(something);

        test_id0_qspn_bootstrap_complete = 1;
        // In less than 0.1 seconds we must get signal Qspn.qspn_bootstrap_complete.
        tasklet.ms_wait(100);
        assert(test_id0_qspn_bootstrap_complete == -1);

        tasklet.ms_wait(100);

        // We enter a network. It implies a new identity id1 that duplicates id0.
        //  First id1 is constructed with enter_net, then id0 calls make_connectivity.
        id1 = new IdentityData(alfa1_id);
        id1.local_identity_index = 1;
        id1.stub_factory = new QspnStubFactory(id1);
        // Immediately after id1.stub_factory is initialized, we can spawn a tasklet to wait for
        //  a RPC call.
        FollowId0Tasklet ts0 = new FollowId0Tasklet();
        ITaskletHandle h_ts0 = tasklet.spawn(ts0, true);
        FollowId1Tasklet ts1 = new FollowId1Tasklet();
        ITaskletHandle h_ts1 = tasklet.spawn(ts1, true);
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
              cost=10796 usec
         */
        compute_naddr("2.1.1.2", _gsizes, out id1.my_naddr);
        compute_fp0(alfa_fp0, "0.0.0.1", out id1.my_fp);
        ArrayList<IQspnArc> internal_arc_set = new ArrayList<IQspnArc>();
        ArrayList<IQspnArc> internal_arc_prev_arc_set = new ArrayList<IQspnArc>();
        ArrayList<IQspnNaddr> internal_arc_peer_naddr_set = new ArrayList<IQspnNaddr>();
        ArrayList<IQspnArc> external_arc_set = new ArrayList<IQspnArc>();
        arc_id1_beta0_cost = new Cost(alfa1_beta0_cost);
        arc_id1_beta0 = new QspnArc(id1.nodeid, new NodeID(beta0_id), arc_id1_beta0_cost, "00:16:3E:EC:A3:E1");
        external_arc_set.add(arc_id1_beta0);
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
        // NOT NEEDED  id1.qspn_manager.arc_removed.connect(something);
        id1.qspn_manager.changed_fp.connect(id1_changed_fp);
        id1.qspn_manager.changed_nodes_inside.connect(id1_changed_nodes_inside);
        id1.qspn_manager.destination_added.connect(id1_destination_added);
        id1.qspn_manager.destination_removed.connect(id1_destination_removed);
        // NOT NEEDED  id1.qspn_manager.gnode_splitted.connect(something);
        id1.qspn_manager.path_added.connect(id1_path_added);
        // NOT NEEDED  id1.qspn_manager.path_changed.connect(something);
        id1.qspn_manager.path_removed.connect(id1_path_removed);
        id1.qspn_manager.presence_notified.connect(id1_presence_notified);
        id1.qspn_manager.qspn_bootstrap_complete.connect(id1_qspn_bootstrap_complete);
        // NOT NEEDED  id1.qspn_manager.remove_identity.connect(something);

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

        // Now we have 2 paths to follow. Within a certain interval we should see a
        //  call to RPC send_etp from id0 and a call to RPC get_full_etp from id1.
        // That's why we spawned 2 tasklets before. Now we wait (join) for them to finish.
        h_ts0.join();
        h_ts1.join();
        IChannel id1_expected_answer = ts1.id1_expected_answer;

        tasklet.ms_wait(10);
        // Identity #1: call make_real.
        //   At level 0 with pos 1 and eldership 2.
        //   Will have naddr 2:1:1:1 and elderships 0:0:0:2 and fp0 97272.
        {
            int ch_level = 0;
            int ch_pos = 1;
            int ch_eldership = 2;
            int64 fp_id = id1.my_fp.id;

            QspnManager.ChangeNaddrDelegate update_naddr = (_a) => {
                Naddr a = (Naddr)_a;
                ArrayList<int> _naddr_temp = new ArrayList<int>();
                _naddr_temp.add_all(a.pos);
                _naddr_temp[ch_level] = ch_pos;
                return new Naddr(_naddr_temp.to_array(), _gsizes.to_array());
            };

            ArrayList<int> _elderships_temp = new ArrayList<int>();
            _elderships_temp.add_all(id1.my_fp.elderships);
            _elderships_temp[ch_level] = ch_eldership;

            id1.my_naddr = (Naddr)update_naddr(id1.my_naddr);
            id1.my_fp = new Fingerprint(_elderships_temp.to_array(), fp_id);
            id1.qspn_manager.make_real(
                update_naddr, id1.my_fp);
        }

        tasklet.ms_wait(300);
        // Identity #0: disable and dismiss.
        id0.qspn_manager.stop_operations();
        id0.qspn_manager = null;

        // After 1 sec. id1 receives RPC call to get_full_etp. And will immediately throw QspnBootstrapInProgressError.
        /*
               requesting_address=2:1:1:0.
               Caller is TcpclientCallerInfo
               my_address = 169.254.62.237
               peer_address = 169.254.134.220
               sourceid = 1536684510
         */
        tasklet.ms_wait(1000);
        Naddr requesting_address;
        compute_naddr("2.1.1.0", _gsizes, out requesting_address);
        FakeCallerInfo rpc_caller = new FakeCallerInfo();
        rpc_caller.valid_set = new ArrayList<QspnArc>.wrap({arc_id1_beta0});
        try {
            id1.qspn_manager.get_full_etp(requesting_address, rpc_caller);
            assert_not_reached();
        } catch (QspnNotAcceptedError e) {
            assert_not_reached();
        } catch (QspnBootstrapInProgressError e) {
            // it should go here
        }

        // after .5 seconds id1 get answer from id1_expected_answer
        tasklet.ms_wait(500);
        // build an EtpMessage
        string s_etpmessage = """{""" +
            """"node-address":{"typename":"TestbedNaddr","value":{"pos":[0,1,1,2],"sizes":[2,2,2,4]}},""" +
            """"fingerprints":[""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":0,"elderships":[0,0,0,0],"elderships-seed":[]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":1,"elderships":[0,0,0],"elderships-seed":[0]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":2,"elderships":[0,0],"elderships-seed":[0,0]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":3,"elderships":[0],"elderships-seed":[0,0,0]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":4,"elderships":[],"elderships-seed":[0,0,0,0]}}],""" +
            """"nodes-inside":[1,1,1,1,1],""" +
            """"hops":[],""" +
            """"p-list":[]}""";
        Type type_etpmessage = name_to_type("NetsukukuQspnEtpMessage");
        IQspnEtpMessage id1_resp = (IQspnEtpMessage)json_object_from_string(s_etpmessage, type_etpmessage);
        // simulate the response
        id1_expected_answer.send_async("OK");
        id1_expected_answer.send_async(id1_resp);
        // Immediately (send_async will not wait) prepare to verify signals produced by ETP processing.
        test_id1_destination_added = 1;
        test_id1_path_added = 1;
        test_id1_changed_fp = 1;
        test_id1_changed_fp_qspnmgr = id1.qspn_manager;
        test_id1_changed_nodes_inside = 1;
        test_id1_changed_nodes_inside_qspnmgr = id1.qspn_manager;
        test_id1_qspn_bootstrap_complete = 1;
        // While we wait for those signals, also expect (in less than 0.5 seconds) a call to RPC get_full_etp from id1 to beta0
        //  (Yes, the QspnManager will ask another time to the same arc.)
        IQspnAddress id1_requesting_address_2;
        IChannel id1_expected_answer_2;
        ArrayList<NodeID> id1_destid_set_2;
        id1.stub_factory.expect_get_full_etp(500, out id1_requesting_address_2, out id1_expected_answer_2, out id1_destid_set_2);
        assert(test_id1_destination_added == -1);
        assert(test_id1_path_added == -1);
        assert(test_id1_changed_fp == -1);
        assert(test_id1_changed_nodes_inside == -1);
        assert(test_id1_qspn_bootstrap_complete == -1);
        assert(id1_destid_set_2.size == 1);
        assert(id1_destid_set_2[0].id == beta0_id);
        assert(naddr_repr((Naddr)id1_requesting_address_2) == "2:1:1:1");
        // after .05 seconds id1 get the second answer from id1_expected_answer_2
        tasklet.ms_wait(50);
        // build an EtpMessage
        string s_etpmessage_2 = """{""" +
            """"node-address":{"typename":"TestbedNaddr","value":{"pos":[0,1,1,2],"sizes":[2,2,2,4]}},""" +
            """"fingerprints":[""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":0,"elderships":[0,0,0,0],"elderships-seed":[]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":1,"elderships":[0,0,0],"elderships-seed":[0]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":2,"elderships":[0,0],"elderships-seed":[0,0]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":3,"elderships":[0],"elderships-seed":[0,0,0]}},""" +
                """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(beta_fp0)" +
                        ""","level":4,"elderships":[],"elderships-seed":[0,0,0,0]}}],""" +
            """"nodes-inside":[1,1,1,1,1],""" +
            """"hops":[],""" +
            """"p-list":[]}""";
        Type type_etpmessage_2 = name_to_type("NetsukukuQspnEtpMessage");
        IQspnEtpMessage id1_resp_2 = (IQspnEtpMessage)json_object_from_string(s_etpmessage_2, type_etpmessage_2);
        // simulate the response
        id1_expected_answer_2.send_async("OK");
        id1_expected_answer_2.send_async(id1_resp_2);

        // Expect (in less than 0.1 seconds) to see a RPC call to send_etp from id1 to set [beta0].
        IQspnEtpMessage id1_send_etp;
        bool id1_send_is_full;
        ArrayList<NodeID> id1_destid_set;
        id1.stub_factory.expect_send_etp(100, out id1_send_etp, out id1_send_is_full, out id1_destid_set);
        assert(id1_destid_set.size == 1);
        assert(id1_destid_set[0].id == beta0_id);
        {
            /*
             * If we do just:
                Json.Node n = Json.gobject_serialize(id1_send_etp);
               then we get a strange "Critical message" of "json_node_get_node_type: assertion 'JSON_NODE_IS_VALID (node)' failed"
               when we do a certain sequence of operations with the Json.Reader.
               That's not the case when we pass through the following:
             */
            string s0 = json_string_from_object(id1_send_etp, false);
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
                            assert(r_buf.get_int_value() == 1);
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
                            assert(r_buf.get_int_value() == 1);
                        }
                        r_buf.end_element();
                        assert(r_buf.read_element(3));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 2);
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
                            assert(r_buf.get_int_value() == alfa_fp0);
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
                                assert(r_buf.get_int_value() == 2);
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
                            assert(r_buf.get_int_value() == beta_fp0);
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
                                assert(r_buf.get_int_value() == 0);
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
                            assert(r_buf.get_int_value() == beta_fp0);
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
                                assert(r_buf.get_int_value() == 0);
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
                            assert(r_buf.get_int_value() == beta_fp0);
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
                                assert(r_buf.get_int_value() == 0);
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
                            assert(r_buf.get_int_value() == beta_fp0);
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
                                assert(r_buf.get_int_value() == 0);
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
                    assert(r_buf.get_int_value() == 1);
                }
                r_buf.end_element();
                assert(r_buf.read_element(1));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 2);
                }
                r_buf.end_element();
                assert(r_buf.read_element(2));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 2);
                }
                r_buf.end_element();
                assert(r_buf.read_element(3));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 2);
                }
                r_buf.end_element();
                assert(r_buf.read_element(4));
                {
                    assert(r_buf.is_value());
                    assert(r_buf.get_int_value() == 2);
                }
                r_buf.end_element();
            }
            r_buf.end_member();
            assert(r_buf.read_member("hops"));
            {
                assert(r_buf.is_array());
                assert(r_buf.count_elements() == 0);
            }
            r_buf.end_member();
            assert(r_buf.read_member("p-list"));
            {
                assert(r_buf.is_array());
                assert(r_buf.count_elements() == 1);
                assert(r_buf.read_element(0));
                {
                    assert(r_buf.is_object());
                    assert(r_buf.read_member("value"));
                    {
                        assert(r_buf.is_object());
                        assert(r_buf.read_member("hops"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 1);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_object());
                                assert(r_buf.read_member("value"));
                                {
                                    assert(r_buf.is_object());
                                    // This is HCoord (0,0). Thus it might be serialized without any member.
                                }
                                r_buf.end_member();
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("arcs"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 1);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                r_buf.get_int_value(); // an int.
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("cost"));
                        {
                            assert(r_buf.is_object());
                            assert(r_buf.read_member("value"));
                            {
                                assert(r_buf.is_object());
                                assert(r_buf.read_member("usec-rtt"));
                                {
                                    assert(r_buf.is_value());
                                    assert(r_buf.get_int_value() == alfa1_beta0_cost);
                                }
                                r_buf.end_member();
                            }
                            r_buf.end_member();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("fingerprint"));
                        {
                            assert(r_buf.is_object());
                            assert(r_buf.read_member("value"));
                            {
                                assert(r_buf.is_object());
                                // ...
                            }
                            r_buf.end_member();
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("nodes-inside"));
                        {
                            assert(r_buf.is_value());
                            assert(r_buf.get_int_value() == 1);
                        }
                        r_buf.end_member();
                        assert(r_buf.read_member("ignore-outside"));
                        {
                            assert(r_buf.is_array());
                            assert(r_buf.count_elements() == 4);
                            assert(r_buf.read_element(0));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_boolean_value() == false);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(1));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_boolean_value() == true);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(2));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_boolean_value() == true);
                            }
                            r_buf.end_element();
                            assert(r_buf.read_element(3));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_boolean_value() == true);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_element();
                }
                r_buf.end_element();
            }
            r_buf.end_member();
        }

        // Verify that after some time id1 signals its 'presence_notified'.
        test_id1_presence_notified = 1;
        int iterations_before_id1_presence_notified = 0;
        while (test_id1_presence_notified != -1)
        {
            iterations_before_id1_presence_notified++;
            assert(iterations_before_id1_presence_notified < 10);
            tasklet.ms_wait(200);
        }

        // After some time, remove arc.
        tasklet.ms_wait(1600);
        // Prepare to verify signals produced by arc removal.
        // Expect signals `path_removed`, `destination_removed`, `changed_nodes_inside`, `changed_fp`.
        test_id1_path_removed = 1;
        test_id1_destination_removed = 1;
        test_id1_changed_fp = 2;
        test_id1_changed_fp_qspnmgr = id1.qspn_manager;
        test_id1_changed_nodes_inside = 2;
        test_id1_changed_nodes_inside_qspnmgr = id1.qspn_manager;
        id1.qspn_manager.arc_remove(arc_id1_beta0);
        tasklet.ms_wait(10);
        assert(test_id1_path_removed == -1);
        assert(test_id1_destination_removed == -1);
        assert(test_id1_changed_fp == -1);
        assert(test_id1_changed_nodes_inside == -1);

        tasklet.ms_wait(200);
        // Identity #1: disable and dismiss.
        id1.qspn_manager.stop_operations();
        id1.qspn_manager = null;

        PthTaskletImplementer.kill();
    }

    class FollowId0Tasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            // In less than 0.2 seconds we must call RPC send_etp to nobody.
            IQspnEtpMessage id0_send_etp;
            bool id0_send_is_full;
            ArrayList<NodeID> id0_destid_set;
            id0.stub_factory.expect_send_etp(200, out id0_send_etp, out id0_send_is_full, out id0_destid_set);
            assert(! id0_send_is_full);
            assert(id0_destid_set.is_empty);
            {
                /*
                 * If we do just:
                    Json.Node n = Json.gobject_serialize(id0_send_etp);
                   then we get a strange "Critical message" of "json_node_get_node_type: assertion 'JSON_NODE_IS_VALID (node)' failed"
                   when we do a certain sequence of operations with the Json.Reader.
                   That's not the case when we pass through the following:
                 */
                string s0 = json_string_from_object(id0_send_etp, false);
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
                                assert(r_buf.get_int_value() == alfa_fp0);
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
                                assert(r_buf.get_int_value() == alfa_fp0);
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
                                assert(r_buf.get_int_value() == alfa_fp0);
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
                                assert(r_buf.get_int_value() == alfa_fp0);
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
                                assert(r_buf.get_int_value() == alfa_fp0);
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
            return null;
        }
    }

    class FollowId1Tasklet : Object, ITaskletSpawnable
    {
        public IChannel? id1_expected_answer=null;  

        public void * func()
        {
            // In less than 0.1 seconds we must call RPC get_full_etp to beta0.
            IQspnAddress id1_requesting_address;
            IChannel _id1_expected_answer;
            ArrayList<NodeID> id1_destid_set;
            id1.stub_factory.expect_get_full_etp(100, out id1_requesting_address, out _id1_expected_answer, out id1_destid_set);
            assert(id1_destid_set.size == 1);
            assert(id1_destid_set[0].id == beta0_id);
            assert(naddr_repr((Naddr)id1_requesting_address) == "2:1:1:2");
            id1_expected_answer = _id1_expected_answer;
            return null;
        }
    }

    int test_id0_qspn_bootstrap_complete = -1;
    void id0_qspn_bootstrap_complete()
    {
        if (test_id0_qspn_bootstrap_complete == 1)
        {
            try {
                Fingerprint fp = (Fingerprint)id0.qspn_manager.get_fingerprint(0);
                int nodes_inside = id0.qspn_manager.get_nodes_inside(0);
                string fp_elderships = fp_elderships_repr(fp);
                assert(fp.id == alfa_fp0);
                assert(fp_elderships == "0:0:0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(1);
                nodes_inside = id0.qspn_manager.get_nodes_inside(1);
                fp_elderships = fp_elderships_repr(fp);
                string fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == alfa_fp0);
                assert(fp_elderships == "0:0:0");
                assert(fp_elderships_seed == "0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(2);
                nodes_inside = id0.qspn_manager.get_nodes_inside(2);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == alfa_fp0);
                assert(fp_elderships == "0:0");
                assert(fp_elderships_seed == "0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(3);
                nodes_inside = id0.qspn_manager.get_nodes_inside(3);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == alfa_fp0);
                assert(fp_elderships == "0");
                assert(fp_elderships_seed == "0:0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(4);
                nodes_inside = id0.qspn_manager.get_nodes_inside(4);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == alfa_fp0);
                assert(fp_elderships_seed == "0:0:0:0");
                assert(nodes_inside == 1);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
            test_id0_qspn_bootstrap_complete = -1;
        }
        // else if (test_id0_qspn_bootstrap_complete == 2)
        else
        {
            warning("unpredicted signal id0_qspn_bootstrap_complete");
        }
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
        else
        {
            warning("unpredicted signal id0_changed_nodes_inside");
        }
    }

    int test_id1_destination_added = -1;
    void id1_destination_added(HCoord h)
    {
        if (test_id1_destination_added == 1)
        {
            assert(h.lvl == 0);
            assert(h.pos == 0);
            test_id1_destination_added = -1;
        }
        // else if (test_id1_destination_added == 2)
        else
        {
            warning("unpredicted signal id1_destination_added");
        }
    }

    int test_id1_path_added = -1;
    void id1_path_added(IQspnNodePath p)
    {
        if (test_id1_path_added == 1)
        {
            assert(p.i_qspn_get_arc().i_qspn_equals(arc_id1_beta0));
            assert(p.i_qspn_get_cost().i_qspn_compare_to(arc_id1_beta0_cost) == 0);
            assert(p.i_qspn_get_nodes_inside() == 1);
            Gee.List<IQspnHop> hops = p.i_qspn_get_hops();
            assert(hops.size == 1);
            IQspnHop hop = hops[0];
            HCoord h_hop = hop.i_qspn_get_hcoord();
            assert(h_hop.lvl == 0);
            assert(h_hop.pos == 0);
            test_id1_path_added = -1;
        }
        // else if (test_id1_path_added == 2)
        else
        {
            warning("unpredicted signal id1_path_added");
        }
    }

    int test_id1_changed_fp = -1;
    int test_id1_changed_fp_step = -1;
    weak QspnManager? test_id1_changed_fp_qspnmgr = null;
    void id1_changed_fp(int l)
    {
        if (test_id1_changed_fp == 1)
        {
            if (test_id1_changed_fp_step == -1)
            {
                assert(l == 1);
                try {
                    test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_fp_step = 1;
            }
            else if (test_id1_changed_fp_step == 1)
            {
                assert(l == 2);
                try {
                    test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_fp_step = 2;
            }
            else if (test_id1_changed_fp_step == 2)
            {
                assert(l == 3);
                try {
                    test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_fp_step = 3;
            }
            else if (test_id1_changed_fp_step == 3)
            {
                assert(l == 4);
                try {
                    test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_fp = -1;
                test_id1_changed_fp_step = -1;
                test_id1_changed_fp_qspnmgr = null;
            }
        }
        else if (test_id1_changed_fp == 2)
        {
            if (test_id1_changed_fp_step == -1)
            {
                assert(l == 1);
                try {
                    Fingerprint fp = (Fingerprint)test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    string fp_elderships = fp_elderships_repr(fp);
                    string fp_elderships_seed = fp_elderships_seed_repr(fp);
                    assert(fp_elderships == "0:0:0");
                    assert(fp_elderships_seed == "2");
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_fp_step = 1;
            }
            else if (test_id1_changed_fp_step == 1)
            {
                assert(l == 2);
                try {
                    Fingerprint fp = (Fingerprint)test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    string fp_elderships = fp_elderships_repr(fp);
                    string fp_elderships_seed = fp_elderships_seed_repr(fp);
                    assert(fp_elderships == "0:0");
                    assert(fp_elderships_seed == "2:0");
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_fp_step = 2;
            }
            else if (test_id1_changed_fp_step == 2)
            {
                assert(l == 3);
                try {
                    Fingerprint fp = (Fingerprint)test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    string fp_elderships = fp_elderships_repr(fp);
                    string fp_elderships_seed = fp_elderships_seed_repr(fp);
                    assert(fp_elderships == "0");
                    assert(fp_elderships_seed == "2:0:0");
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_fp_step = 3;
            }
            else if (test_id1_changed_fp_step == 3)
            {
                assert(l == 4);
                try {
                    Fingerprint fp = (Fingerprint)test_id1_changed_fp_qspnmgr.get_fingerprint(l);
                    string fp_elderships = fp_elderships_repr(fp);
                    string fp_elderships_seed = fp_elderships_seed_repr(fp);
                    assert(fp_elderships == "");
                    assert(fp_elderships_seed == "2:0:0:0");
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_fp = -1;
                test_id1_changed_fp_step = -1;
                test_id1_changed_fp_qspnmgr = null;
            }
        }
        // else if (test_id1_changed_fp == 3)
        else
        {
            warning("unpredicted signal id1_changed_fp");
        }
    }

    int test_id1_changed_nodes_inside = -1;
    int test_id1_changed_nodes_inside_step = -1;
    weak QspnManager? test_id1_changed_nodes_inside_qspnmgr = null;
    void id1_changed_nodes_inside(int l)
    {
        if (test_id1_changed_nodes_inside == 1)
        {
            if (test_id1_changed_nodes_inside_step == -1)
            {
                assert(l == 1);
                try {
                    test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_nodes_inside_step = 1;
            }
            else if (test_id1_changed_nodes_inside_step == 1)
            {
                assert(l == 2);
                try {
                    test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_nodes_inside_step = 2;
            }
            else if (test_id1_changed_nodes_inside_step == 2)
            {
                assert(l == 3);
                try {
                    test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_nodes_inside_step = 3;
            }
            else if (test_id1_changed_nodes_inside_step == 3)
            {
                assert(l == 4);
                try {
                    test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert_not_reached();
                } catch (QspnBootstrapInProgressError e) {/*reached*/}
                test_id1_changed_nodes_inside = -1;
                test_id1_changed_nodes_inside_step = -1;
                test_id1_changed_nodes_inside_qspnmgr = null;
            }
        }
        else if (test_id1_changed_nodes_inside == 2)
        {
            if (test_id1_changed_nodes_inside_step == -1)
            {
                assert(l == 1);
                try {
                    int nodes_inside = test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_nodes_inside_step = 1;
            }
            else if (test_id1_changed_nodes_inside_step == 1)
            {
                assert(l == 2);
                try {
                    int nodes_inside = test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_nodes_inside_step = 2;
            }
            else if (test_id1_changed_nodes_inside_step == 2)
            {
                assert(l == 3);
                try {
                    int nodes_inside = test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_nodes_inside_step = 3;
            }
            else if (test_id1_changed_nodes_inside_step == 3)
            {
                assert(l == 4);
                try {
                    int nodes_inside = test_id1_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id1_changed_nodes_inside = -1;
                test_id1_changed_nodes_inside_step = -1;
                test_id1_changed_nodes_inside_qspnmgr = null;
            }
        }
        // else if (test_id1_changed_nodes_inside == 3)
        else
        {
            warning("unpredicted signal id1_changed_nodes_inside");
        }
    }

    int test_id1_qspn_bootstrap_complete = -1;
    void id1_qspn_bootstrap_complete()
    {
        if (test_id1_qspn_bootstrap_complete == 1)
        {
            try {
                Fingerprint fp = (Fingerprint)id1.qspn_manager.get_fingerprint(0);
                int nodes_inside = id1.qspn_manager.get_nodes_inside(0);
                string fp_elderships = fp_elderships_repr(fp);
                assert(fp.id == alfa_fp0);
                assert(fp_elderships == "0:0:0:2");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id1.qspn_manager.get_fingerprint(1);
                nodes_inside = id1.qspn_manager.get_nodes_inside(1);
                fp_elderships = fp_elderships_repr(fp);
                string fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
                assert(fp_elderships == "0:0:0");
                assert(fp_elderships_seed == "0");
                assert(nodes_inside == 2);

                fp = (Fingerprint)id1.qspn_manager.get_fingerprint(2);
                nodes_inside = id1.qspn_manager.get_nodes_inside(2);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
                assert(fp_elderships == "0:0");
                assert(fp_elderships_seed == "0:0");
                assert(nodes_inside == 2);

                fp = (Fingerprint)id1.qspn_manager.get_fingerprint(3);
                nodes_inside = id1.qspn_manager.get_nodes_inside(3);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
                assert(fp_elderships == "0");
                assert(fp_elderships_seed == "0:0:0");
                assert(nodes_inside == 2);

                fp = (Fingerprint)id1.qspn_manager.get_fingerprint(4);
                nodes_inside = id1.qspn_manager.get_nodes_inside(4);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
                assert(fp_elderships_seed == "0:0:0:0");
                assert(nodes_inside == 2);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
            test_id1_qspn_bootstrap_complete = -1;
        }
        // else if (test_id1_qspn_bootstrap_complete == 2)
        else
        {
            warning("unpredicted signal id1_qspn_bootstrap_complete");
        }
    }

    int test_id1_presence_notified = -1;
    void id1_presence_notified()
    {
        if (test_id1_presence_notified == 1)
        {
            // Just the signal is expected.
            test_id1_presence_notified = -1;
        }
        // else if (test_id1_presence_notified == 2)
        else
        {
            warning("unpredicted signal id1_presence_notified");
        }
    }

    int test_id1_path_removed = -1;
    void id1_path_removed(IQspnNodePath p)
    {
        if (test_id1_path_removed == 1)
        {
            assert(p.i_qspn_get_arc().i_qspn_equals(arc_id1_beta0));
            assert(p.i_qspn_get_cost().i_qspn_compare_to(arc_id1_beta0_cost) == 0);
            assert(p.i_qspn_get_nodes_inside() == 1);
            Gee.List<IQspnHop> hops = p.i_qspn_get_hops();
            assert(hops.size == 1);
            IQspnHop hop = hops[0];
            HCoord h_hop = hop.i_qspn_get_hcoord();
            assert(h_hop.lvl == 0);
            assert(h_hop.pos == 0);
            test_id1_path_removed = -1;
        }
        // else if (test_id1_path_removed == 2)
        else
        {
            warning("unpredicted signal id1_path_removed");
        }
    }

    int test_id1_destination_removed = -1;
    void id1_destination_removed(HCoord h)
    {
        if (test_id1_destination_removed == 1)
        {
            assert(h.lvl == 0);
            assert(h.pos == 0);
            test_id1_destination_removed = -1;
        }
        // else if (test_id1_destination_removed == 2)
        else
        {
            warning("unpredicted signal id1_destination_removed");
        }
    }
}