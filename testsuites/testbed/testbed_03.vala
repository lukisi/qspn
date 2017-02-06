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

namespace Testbed03
{
    // impersonate delta
    const int64 delta_fp0 = 154713;
    const int64 mu_fp0 = 823055;
    const int delta0_id = 1003440501;
    const int mu1_id = 868709693;
    const int64 delta0_mu1_cost = 11777;
    const int delta1_id = 330512932;
    const int mu2_id = 1389185884;
    const int64 delta1_mu2_cost = 11309;
    const int gamma0_id = 713199376;
    const int64 delta1_gamma0_cost = 10101;

    QspnArc arc_id0_mu1;
    Cost arc_id0_mu1_cost;
    IdentityData id0;

    QspnArc arc_id1_mu2;
    Cost arc_id1_mu2_cost;
    QspnArc arc_id1_gamma0;
    Cost arc_id1_gamma0_cost;
    IdentityData id1;

    ArrayList<int> _gsizes;
    int levels;

    void testbed_03()
    {
        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // static Qspn.init.
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());

        compute_topology("4.2.2.2", out _gsizes, out levels);

        // Identity #0: construct Qspn.create_net.
        //   my_naddr=3:1:0:1 elderships=0:0:0:0 fp0=154713 nodeid=1003440501.
        id0 = new IdentityData(delta0_id);
        id0.local_identity_index = 0;
        id0.stub_factory = new QspnStubFactory(id0);
        compute_naddr("3.1.0.1", _gsizes, out id0.my_naddr);
        compute_fp0_first_node(delta_fp0, levels, out id0.my_fp);
        id0.qspn_manager = new QspnManager.create_net(
            id0.my_naddr,
            id0.my_fp,
            id0.stub_factory);
        // soon after creation, connect to signals.
        // TODO  id0.qspn_manager.arc_removed.connect(id0_arc_removed);
        // TODO  id0.qspn_manager.changed_fp.connect(id0_changed_fp);
        id0.qspn_manager.changed_nodes_inside.connect(id0_changed_nodes_inside);
        id0.qspn_manager.destination_added.connect(id0_destination_added);
        // TODO  id0.qspn_manager.destination_removed.connect(id0_destination_removed);
        // TODO  id0.qspn_manager.gnode_splitted.connect(id0_gnode_splitted);
        id0.qspn_manager.path_added.connect(id0_path_added);
        // TODO  id0.qspn_manager.path_changed.connect(id0_path_changed);
        // TODO  id0.qspn_manager.path_removed.connect(id0_path_removed);
        // TODO  id0.qspn_manager.presence_notified.connect(id0_presence_notified);
        id0.qspn_manager.qspn_bootstrap_complete.connect(id0_qspn_bootstrap_complete);
        // TODO  id0.qspn_manager.remove_identity.connect(id0_remove_identity);

        test_id0_qspn_bootstrap_complete = 1;
        // In less than 0.1 seconds we must get signal Qspn.qspn_bootstrap_complete.
        tasklet.ms_wait(100);
        assert(test_id0_qspn_bootstrap_complete == -1);

        // After .1 sec id0 receives call to get_full_etp from mu1, which is now 3:1:0:2.
        tasklet.ms_wait(100);
        Id0GetFullEtpTasklet ts1 = new Id0GetFullEtpTasklet();
        compute_naddr("3.1.0.2", _gsizes, out ts1.requesting_address);
        ts1.rpc_caller = new FakeCallerInfo();
        // The request is coming from a QspnArc that will be added later on.
        arc_id0_mu1_cost = new Cost(delta0_mu1_cost);
        arc_id0_mu1 = new QspnArc(id0.nodeid, new NodeID(mu1_id), arc_id0_mu1_cost, "00:16:3E:2D:8D:DE");
        ts1.rpc_caller.valid_set = new ArrayList<QspnArc>.wrap({arc_id0_mu1});
        // So we must exec this call on a tasklet.
        ITaskletHandle h_ts1 = tasklet.spawn(ts1, true);
        tasklet.ms_wait(1);

        // call arc_add
        tasklet.ms_wait(1000);
        id0.qspn_manager.arc_add(arc_id0_mu1);
        // expect in less than .1 seconds call to get_full_etp from id0 to mu1.
        //   requesting_address=3:1:0:1.
        {
            IQspnAddress id0_requesting_address;
            IChannel id0_expected_answer;
            ArrayList<NodeID> id0_destid_set;
            id0.stub_factory.expect_get_full_etp(100, out id0_requesting_address, out id0_expected_answer, out id0_destid_set);
            assert(id0_destid_set.size == 1);
            assert(id0_destid_set[0].id == mu1_id);
            assert(naddr_repr((Naddr)id0_requesting_address) == "3:1:0:1");
            // simulate the response: throw QspnBootstrapInProgressError.
            id0_expected_answer.send_async("QspnBootstrapInProgressError");
        }

        // Wait for the tasklet to verify return value of get_full_etp from mu1 to id0.
        h_ts1.join();

        // After .1 sec id0 receives call to get_full_etp from mu1, which is now 3:1:0:0.
        //  Verify that we return NetsukukuQspnEtpMessage:
        /*
           {"node-address":{"typename":"ProofOfConceptNaddr","value":{"pos":[1,0,1,3],"sizes":[2,2,2,4]}},
            "fingerprints":[
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":0,"elderships":[0,0,0,0],"elderships-seed":[]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":1,"elderships":[0,0,0],"elderships-seed":[0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":2,"elderships":[0,0],"elderships-seed":[0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":3,"elderships":[0],"elderships-seed":[0,0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":4,"elderships":[],"elderships-seed":[0,0,0,0]}}],
            "nodes-inside":[1,1,1,1,1],
            "hops":[],
            "p-list":[]}.
         */
        tasklet.ms_wait(100);
        {
            Naddr mu1_requesting_address;
            compute_naddr("3.1.0.0", _gsizes, out mu1_requesting_address);
            FakeCallerInfo mu1_rpc_caller = new FakeCallerInfo();
            mu1_rpc_caller.valid_set = new ArrayList<QspnArc>.wrap({arc_id0_mu1});
            try {
                IQspnEtpMessage resp = id0.qspn_manager.get_full_etp(mu1_requesting_address, mu1_rpc_caller);
                string s0 = json_string_from_object(resp, false);
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
                                assert(r_buf.get_int_value() == 0);
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
                                assert(r_buf.get_int_value() == 3);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                        assert(r_buf.get_int_value() == 1);
                    }
                    r_buf.end_element();
                    assert(r_buf.read_element(4));
                    {
                        assert(r_buf.is_value());
                        assert(r_buf.get_int_value() == 1);
                    }
                    r_buf.end_element();
                }
                r_buf.end_member();
            } catch (QspnNotAcceptedError e) {
                assert_not_reached();
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        // After short, we receive an ETP from mu1.
        tasklet.ms_wait(10);
        {
            // build an EtpMessage
            string s_etpmessage = """{""" +
                """"node-address":{"typename":"TestbedNaddr","value":{"pos":[0,0,1,3],"sizes":[2,2,2,4]}},""" +
                """"fingerprints":[""" +
                    """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(mu_fp0)" +
                            ""","level":0,"elderships":[2,0,0,0],"elderships-seed":[]}},""" +
                    """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(delta_fp0)" +
                            ""","level":1,"elderships":[0,0,0],"elderships-seed":[0]}},""" +
                    """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(delta_fp0)" +
                            ""","level":2,"elderships":[0,0],"elderships-seed":[0,0]}},""" +
                    """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(delta_fp0)" +
                            ""","level":3,"elderships":[0],"elderships-seed":[0,0,0]}},""" +
                    """{"typename":"TestbedFingerprint","value":{"id":""" + @"$(delta_fp0)" +
                            ""","level":4,"elderships":[],"elderships-seed":[0,0,0,0]}}],""" +
                """"nodes-inside":[1,2,2,2,2],""" +
                """"hops":[],""" +
                """"p-list":[""" +
                    """{"typename":"NetsukukuQspnEtpPath","value":{""" +
                        """"hops":[{"typename":"NetsukukuHCoord","value":{"pos":1}}],""" +
                        """"arcs":[1842243646],""" +
                        """"cost":{"typename":"TestbedCost","value":{"usec-rtt":10891}},""" +
                        """"fingerprint":{"typename":"TestbedFingerprint","value":{"id":""" + @"$(delta_fp0)" +
                                             ""","level":0,"elderships":[0,0,0,0],"elderships-seed":[]}},""" +
                        """"nodes-inside":1,""" +
                        """"ignore-outside":[false,true,true,true]}}]}""";
            Type type_etpmessage = name_to_type("NetsukukuQspnEtpMessage");
            IQspnEtpMessage mu1_etp = (IQspnEtpMessage)json_object_from_string(s_etpmessage, type_etpmessage);
            bool mu1_is_full = true;
            FakeCallerInfo mu1_rpc_caller = new FakeCallerInfo();
            mu1_rpc_caller.valid_set = new ArrayList<QspnArc>.wrap({arc_id0_mu1});
            // Prepare to expect some signals.
            test_id0_destination_added = 1;
            test_id0_path_added = 1;
            test_id0_changed_nodes_inside = 1;
            test_id0_changed_nodes_inside_qspnmgr = id0.qspn_manager;
            try {
                id0.qspn_manager.send_etp(mu1_etp, mu1_is_full, mu1_rpc_caller);
            } catch (QspnNotAcceptedError e) {assert_not_reached();}
        }
        // Expect some signals in less than .1 sec.
        tasklet.ms_wait(100);
        assert(test_id0_destination_added == -1);
        assert(test_id0_path_added == -1);
        assert(test_id0_changed_nodes_inside == -1);

        // No news for some time, then we prepare to enter a new network as a gnode
        //  of level 1. id1 and mu2 will bootstrap in a new network through the
        //  arc id1_gamma0.
        tasklet.ms_wait(1000);
        {
            // Our current address is 3:1:0:1. The first part will become 2:1:2.
            int guest_gnode_level = 1;
            int host_gnode_level = 2;
            ArrayList<int> _guest_gnode_naddr = new ArrayList<int>.wrap({2, 1, 2});

            // We have internal arc id0_mu1 that will define new arc id1_mu2. Compute m2_naddr.
            Naddr mu1_naddr = (Naddr)id0.qspn_manager.get_naddr_for_arc(arc_id0_mu1);
            ArrayList<int> _mu2_naddr = new ArrayList<int>();
            _mu2_naddr.add_all(mu1_naddr.pos.slice(0, guest_gnode_level));
            _mu2_naddr.add_all(_guest_gnode_naddr);
            Naddr mu2_naddr = new Naddr(_mu2_naddr.to_array(), _gsizes.to_array());

            // Identity #1: construct Qspn.enter_net.
            /*
               previous_identity=0.
               my_naddr=2:1:2:1 elderships=0:0:1:0 fp0=154713 nodeid=330512932.
               guest_gnode_level=1, host_gnode_level=2.
               internal_arcs #: 1.
                #0:
                  dev=eth1
                  peer_mac=00:16:3E:2D:8D:DE
                  source-dest=330512932-1389185884
                  peer_naddr=2:1:2:0
                  previous arc source-dest=1003440501-868709693
                  cost=11309 usec
               external_arcs #: 1.
                #0:
                  dev=eth1
                  peer_mac=00:16:3E:5B:78:D5
                  source-dest=330512932-713199376
                  cost=10101 usec
             */
            id1 = new IdentityData(delta1_id);
            id1.local_identity_index = 1;
            id1.stub_factory = new QspnStubFactory(id1);
            ArrayList<int> _id1_naddr = new ArrayList<int>();
            _id1_naddr.add_all(id0.my_naddr.pos.slice(0, guest_gnode_level));
            _id1_naddr.add_all(_guest_gnode_naddr);
            id1.my_naddr = new Naddr(_id1_naddr.to_array(), _gsizes.to_array());
            compute_fp0(delta_fp0, "0.0.1.0", out id1.my_fp);

            arc_id1_mu2_cost = new Cost(delta1_mu2_cost);
            arc_id1_mu2 = new QspnArc(id1.nodeid, new NodeID(mu2_id), arc_id1_mu2_cost, "00:16:3E:2D:8D:DE");

            arc_id1_gamma0_cost = new Cost(delta1_gamma0_cost);
            arc_id1_gamma0 = new QspnArc(id1.nodeid, new NodeID(gamma0_id), arc_id1_gamma0_cost, "00:16:3E:5B:78:D5");

            id1.qspn_manager = new QspnManager.enter_net(
                id1.my_naddr,
                new ArrayList<IQspnArc>.wrap({arc_id1_mu2}),  /*internal_arc_set*/
                new ArrayList<IQspnArc>.wrap({arc_id0_mu1}),  /*internal_arc_prev_arc_set*/
                new ArrayList<IQspnNaddr>.wrap({mu2_naddr}),  /*internal_arc_peer_naddr_set*/
                new ArrayList<IQspnArc>.wrap({arc_id1_gamma0}),  /*external_arc_set*/
                id1.my_fp,
                id1.stub_factory,
                guest_gnode_level, host_gnode_level, id0.qspn_manager);
            // soon after creation, connect to signals.
            // TODO  id1.qspn_manager.arc_removed.connect(id1_arc_removed);
            // TODO  id1.qspn_manager.changed_fp.connect(id1_changed_fp);
            // TODO  id1.qspn_manager.changed_nodes_inside.connect(id1_changed_nodes_inside);
            // TODO  id1.qspn_manager.destination_added.connect(id1_destination_added);
            // TODO  id1.qspn_manager.destination_removed.connect(id1_destination_removed);
            // TODO  id1.qspn_manager.gnode_splitted.connect(id1_gnode_splitted);
            // TODO  id1.qspn_manager.path_added.connect(id1_path_added);
            // TODO  id1.qspn_manager.path_changed.connect(id1_path_changed);
            // TODO  id1.qspn_manager.path_removed.connect(id1_path_removed);
            // TODO  id1.qspn_manager.presence_notified.connect(id1_presence_notified);
            // TODO  id1.qspn_manager.qspn_bootstrap_complete.connect(id1_qspn_bootstrap_complete);
            // TODO  id1.qspn_manager.remove_identity.connect(id1_remove_identity);

            // Then id0 becomes a connectivity.
            // Identity #0: call make_connectivity.
            //   from_level=2 to_level=4 changing at level 1 pos=2 eldership=1.
            {
                int ch_level = 1;
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
                test_id0_changed_nodes_inside = 2;
                test_id0_changed_nodes_inside_qspnmgr = id0.qspn_manager;
                id0.qspn_manager.make_connectivity(
                    2,
                    4,
                    update_naddr, id0.my_fp);
                assert(test_id0_changed_nodes_inside == -1);
            }

            // TODO to be more robust, the testbed should check the following 2 events in 2 tasklets and then join.
            //  At the moment though we can expect that the first event is the call to get_full_etp
            //  from id1 to gamma0; the second is the call to send_etp from id0 to nobody.

            // Expect in less than .1 seconds call to get_full_etp from id1 to gamma0.
            //   requesting_address=2:1:2:1.
            IQspnAddress id1_requesting_address;
            IChannel id1_expected_answer;
            ArrayList<NodeID> id1_destid_set;
            id1.stub_factory.expect_get_full_etp(100, out id1_requesting_address, out id1_expected_answer, out id1_destid_set);
            assert(id1_destid_set.size == 1);
            assert(id1_destid_set[0].id == gamma0_id);
            assert(naddr_repr((Naddr)id1_requesting_address) == "2:1:2:1");
            // Answer will come after a while.

            // Expect in less than .1 seconds call to send_etp from id0 to nobody. This is because
            //  when the node (identity) executes make_connectivity, after a few millisec (in a tasklet)
            //  it will publish its new data to the nodes (if any) outside the g-node that is becoming of
            //  connectivity.
            IQspnEtpMessage id0_send_etp;
            bool id0_send_is_full;
            ArrayList<NodeID> id0_destid_set;
            id0.stub_factory.expect_send_etp(100, out id0_send_etp, out id0_send_is_full, out id0_destid_set);
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
                // This ETP declares that it is coming from 3:1:2:1. Since it doesn't have to come back
                //  inside this g-node of level 1, which previously had address 3:1:0, we have a "hops"
                //  list that already includes HCoord (1,0).
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
                                assert(r_buf.get_int_value() == 2);
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
                                assert(r_buf.get_int_value() == 3);
                            }
                            r_buf.end_element();
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_member();
                }
                r_buf.end_member();
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
                            assert(r_buf.read_member("lvl"));
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 1);
                            }
                            r_buf.end_member();
                            // pos = 0 might be included or not in json, because it is default value for int.
                            if (r_buf.read_member("pos"))
                            {
                                assert(r_buf.is_value());
                                assert(r_buf.get_int_value() == 0);
                            }
                            r_buf.end_member();
                        }
                        r_buf.end_member();
                    }
                    r_buf.end_element();
                }
                r_buf.end_member();
            }
        }

        PthTaskletImplementer.kill();
    }

    class Id0GetFullEtpTasklet : Object, ITaskletSpawnable
    {
        public Naddr requesting_address;
        public FakeCallerInfo rpc_caller;
        public void * func()
        {
            //  Verify that we return NetsukukuQspnEtpMessage:
            /*
             {"node-address":{"typename":"ProofOfConceptNaddr","value":{"pos":[1,0,1,3],"sizes":[2,2,2,4]}},
            "fingerprints":[
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":0,"elderships":[0,0,0,0],"elderships-seed":[]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":1,"elderships":[0,0,0],"elderships-seed":[0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":2,"elderships":[0,0],"elderships-seed":[0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":3,"elderships":[0],"elderships-seed":[0,0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":154713,"level":4,"elderships":[],"elderships-seed":[0,0,0,0]}}],
            "nodes-inside":[1,1,1,1,1],
            "hops":[],
            "p-list":[]}.
             */
            try {
                IQspnEtpMessage resp = id0.qspn_manager.get_full_etp(requesting_address, rpc_caller);
                string s0 = json_string_from_object(resp, false);
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
                                assert(r_buf.get_int_value() == 0);
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
                                assert(r_buf.get_int_value() == 3);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                                assert(r_buf.get_int_value() == delta_fp0);
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
                        assert(r_buf.get_int_value() == 1);
                    }
                    r_buf.end_element();
                    assert(r_buf.read_element(4));
                    {
                        assert(r_buf.is_value());
                        assert(r_buf.get_int_value() == 1);
                    }
                    r_buf.end_element();
                }
                r_buf.end_member();
            } catch (QspnNotAcceptedError e) {
                assert_not_reached();
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
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
                assert(fp.id == delta_fp0);
                assert(fp_elderships == "0:0:0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(1);
                nodes_inside = id0.qspn_manager.get_nodes_inside(1);
                fp_elderships = fp_elderships_repr(fp);
                string fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == delta_fp0);
                assert(fp_elderships == "0:0:0");
                assert(fp_elderships_seed == "0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(2);
                nodes_inside = id0.qspn_manager.get_nodes_inside(2);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == delta_fp0);
                assert(fp_elderships == "0:0");
                assert(fp_elderships_seed == "0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(3);
                nodes_inside = id0.qspn_manager.get_nodes_inside(3);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == delta_fp0);
                assert(fp_elderships == "0");
                assert(fp_elderships_seed == "0:0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(4);
                nodes_inside = id0.qspn_manager.get_nodes_inside(4);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == delta_fp0);
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

    int test_id0_destination_added = -1;
    void id0_destination_added(HCoord h)
    {
        if (test_id0_destination_added == 1)
        {
            assert(h.lvl == 0);
            assert(h.pos == 0);
            test_id0_destination_added = -1;
        }
        // else if (test_id0_destination_added == 2)
        else
        {
            warning("unpredicted signal id0_destination_added");
        }
    }

    int test_id0_path_added = -1;
    void id0_path_added(IQspnNodePath p)
    {
        if (test_id0_path_added == 1)
        {
            assert(p.i_qspn_get_arc().i_qspn_equals(arc_id0_mu1));
            assert(p.i_qspn_get_cost().i_qspn_compare_to(arc_id0_mu1_cost) == 0);
            assert(p.i_qspn_get_nodes_inside() == 1);
            Gee.List<IQspnHop> hops = p.i_qspn_get_hops();
            assert(hops.size == 1);
            IQspnHop hop = hops[0];
            HCoord h_hop = hop.i_qspn_get_hcoord();
            assert(h_hop.lvl == 0);
            assert(h_hop.pos == 0);
            test_id0_path_added = -1;
        }
        // else if (test_id0_path_added == 2)
        else
        {
            warning("unpredicted signal id0_path_added");
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
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 2);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 1;
            }
            else if (test_id0_changed_nodes_inside_step == 1)
            {
                assert(l == 2);
                try {
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 2);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 2;
            }
            else if (test_id0_changed_nodes_inside_step == 2)
            {
                assert(l == 3);
                try {
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 2);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 3;
            }
            else if (test_id0_changed_nodes_inside_step == 3)
            {
                assert(l == 4);
                try {
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 2);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = -1;
                test_id0_changed_nodes_inside = -1;
                test_id0_changed_nodes_inside_qspnmgr = null;
            }
        }
        else if (test_id0_changed_nodes_inside == 2)
        {
            if (test_id0_changed_nodes_inside_step == -1)
            {
                assert(l == 1);
                try {
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 1;
            }
            else if (test_id0_changed_nodes_inside_step == 1)
            {
                assert(l == 2);
                try {
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 2;
            }
            else if (test_id0_changed_nodes_inside_step == 2)
            {
                assert(l == 3);
                try {
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = 3;
            }
            else if (test_id0_changed_nodes_inside_step == 3)
            {
                assert(l == 4);
                try {
                    int nodes_inside = test_id0_changed_nodes_inside_qspnmgr.get_nodes_inside(l);
                    assert(nodes_inside == 1);
                } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                test_id0_changed_nodes_inside_step = -1;
                test_id0_changed_nodes_inside = -1;
                test_id0_changed_nodes_inside_qspnmgr = null;
            }
        }
        //else if (test_id0_changed_nodes_inside == 3)
        else
        {
            warning("unpredicted signal id0_changed_nodes_inside");
        }
    }
}