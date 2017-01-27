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

namespace Testbed02
{
    const int64 alfa_fp0 = 97272;
    const int64 beta_fp0 = 599487;
    const int beta0_id = 1536684510;
    const int alfa1_id = 2135518399;
    const int64 beta0_alfa1_cost = 11059;

    QspnArc arc_id0_alfa1;
    Cost arc_id0_alfa1_cost;
    IdentityData id0;

    void testbed_02()
    {
        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // TODO Pass tasklet system to the RPC library (ntkdrpc) ??
        //  init_tasklet_system(tasklet);

        // static Qspn.init.
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());

        ArrayList<int> _gsizes;
        int levels;
        compute_topology("4.2.2.2", out _gsizes, out levels);

        // Identity #0: construct Qspn.create_net.
        //   my_naddr=2:1:1:0 elderships=0:0:0:0 fp0=599487 nodeid=1536684510.
        id0 = new IdentityData(beta0_id);
        id0.local_identity_index = 0;
        id0.stub_factory = new QspnStubFactory(id0);
        compute_naddr("2.1.1.0", _gsizes, out id0.my_naddr);
        compute_fp0_first_node(beta_fp0, levels, out id0.my_fp);
        id0.qspn_manager = new QspnManager.create_net(
            id0.my_naddr,
            id0.my_fp,
            id0.stub_factory);
        // soon after creation, connect to signals.
        // TODO  id0.qspn_manager.arc_removed.connect(something);
        // TODO  id0.qspn_manager.changed_fp.connect(something);
        // TODO  id0.qspn_manager.changed_nodes_inside.connect(id0_changed_nodes_inside);
        // TODO  id0.qspn_manager.destination_added.connect(something);
        // TODO  id0.qspn_manager.destination_removed.connect(something);
        // TODO  id0.qspn_manager.gnode_splitted.connect(something);
        // TODO  id0.qspn_manager.path_added.connect(something);
        // TODO  id0.qspn_manager.path_changed.connect(something);
        // TODO  id0.qspn_manager.path_removed.connect(something);
        // TODO  id0.qspn_manager.presence_notified.connect(something);
        id0.qspn_manager.qspn_bootstrap_complete.connect(id0_qspn_bootstrap_complete);
        // TODO  id0.qspn_manager.remove_identity.connect(something);

        test_id0_qspn_bootstrap_complete = 1;
        // In less than 0.1 seconds we must get signal Qspn.qspn_bootstrap_complete.
        tasklet.ms_wait(100);
        assert(test_id0_qspn_bootstrap_complete == -1);

        // After .1 sec id0 receives call to get_full_etp from alfa1, which is now 2:1:1:2.
        tasklet.ms_wait(100);
        Id0GetFullEtpTasklet ts1 = new Id0GetFullEtpTasklet();
        compute_naddr("2.1.1.2", _gsizes, out ts1.requesting_address);
        ts1.rpc_caller = new FakeCallerInfo();
        // The request is coming from a QspnArc that will be added later on.
        arc_id0_alfa1_cost = new Cost(beta0_alfa1_cost);
        arc_id0_alfa1 = new QspnArc(id0.nodeid, new NodeID(alfa1_id), arc_id0_alfa1_cost, "00:16:3E:FD:E2:AA");
        ts1.rpc_caller.valid_set = new ArrayList<QspnArc>.wrap({arc_id0_alfa1});
        // So we must exec this call on a tasklet.
        ITaskletHandle h_ts1 = tasklet.spawn(ts1, true);
        tasklet.ms_wait(1);

        // call arc_add
        tasklet.ms_wait(1000);
        id0.qspn_manager.arc_add(arc_id0_alfa1);
        // expect in less than .1 seconds call to get_full_etp from id0 to alfa1.
        //   requesting_address=2:1:1:0.
        IQspnAddress id0_requesting_address;
        IChannel id0_expected_answer;
        ArrayList<NodeID> id0_destid_set;
        id0.stub_factory.expect_get_full_etp(100, out id0_requesting_address, out id0_expected_answer, out id0_destid_set);
        assert(id0_destid_set.size == 1);
        assert(id0_destid_set[0].id == alfa1_id);
        assert(naddr_repr((Naddr)id0_requesting_address) == "2:1:1:0");
        // simulate the response: throw QspnBootstrapInProgressError.
        id0_expected_answer.send_async("QspnBootstrapInProgressError");

        // Wait for the tasklet to verify return value of get_full_etp from alfa1 to id0.
        h_ts1.join();

        // After .1 sec id0 receives call to get_full_etp from alfa1, which is now 2:1:1:1.
        //  Verify that we return NetsukukuQspnEtpMessage:
        /*
           {"node-address":{"typename":"ProofOfConceptNaddr","value":{"pos":[0,1,1,2],"sizes":[2,2,2,4]}},
            "fingerprints":[
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":0,"elderships":[0,0,0,0],"elderships-seed":[]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":1,"elderships":[0,0,0],"elderships-seed":[0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":2,"elderships":[0,0],"elderships-seed":[0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":3,"elderships":[0],"elderships-seed":[0,0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":4,"elderships":[],"elderships-seed":[0,0,0,0]}}],
            "nodes-inside":[1,1,1,1,1],
            "hops":[],
            "p-list":[]}.
         */
        tasklet.ms_wait(100);
        Naddr alfa1_requesting_address;
        compute_naddr("2.1.1.1", _gsizes, out alfa1_requesting_address);
        FakeCallerInfo alfa1_rpc_caller = new FakeCallerInfo();
        alfa1_rpc_caller.valid_set = new ArrayList<QspnArc>.wrap({arc_id0_alfa1});
        try {
            IQspnEtpMessage resp = id0.qspn_manager.get_full_etp(alfa1_requesting_address, alfa1_rpc_caller);
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
                //
            }
            r_buf.end_member();
            assert(r_buf.read_member("fingerprints"));
            {
                //
            }
            r_buf.end_member();
            assert(r_buf.read_member("nodes-inside"));
            {
                //
            }
            r_buf.end_member();
        } catch (QspnNotAcceptedError e) {
            assert_not_reached();
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();
        }
    }

    class Id0GetFullEtpTasklet : Object, ITaskletSpawnable
    {
        public Naddr requesting_address;
        public FakeCallerInfo rpc_caller;
        public void * func()
        {
            //  Verify that we return NetsukukuQspnEtpMessage:
            /*
           {"node-address":{"typename":"ProofOfConceptNaddr","value":{"pos":[0,1,1,2],"sizes":[2,2,2,4]}},
            "fingerprints":[
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":0,"elderships":[0,0,0,0],"elderships-seed":[]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":1,"elderships":[0,0,0],"elderships-seed":[0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":2,"elderships":[0,0],"elderships-seed":[0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":3,"elderships":[0],"elderships-seed":[0,0,0]}},
                {"typename":"ProofOfConceptFingerprint","value":{"id":599487,"level":4,"elderships":[],"elderships-seed":[0,0,0,0]}}],
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
                    //
                }
                r_buf.end_member();
                assert(r_buf.read_member("fingerprints"));
                {
                    //
                }
                r_buf.end_member();
                assert(r_buf.read_member("nodes-inside"));
                {
                    //
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
                assert(fp.id == beta_fp0);
                assert(fp_elderships == "0:0:0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(1);
                nodes_inside = id0.qspn_manager.get_nodes_inside(1);
                fp_elderships = fp_elderships_repr(fp);
                string fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
                assert(fp_elderships == "0:0:0");
                assert(fp_elderships_seed == "0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(2);
                nodes_inside = id0.qspn_manager.get_nodes_inside(2);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
                assert(fp_elderships == "0:0");
                assert(fp_elderships_seed == "0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(3);
                nodes_inside = id0.qspn_manager.get_nodes_inside(3);
                fp_elderships = fp_elderships_repr(fp);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
                assert(fp_elderships == "0");
                assert(fp_elderships_seed == "0:0:0");
                assert(nodes_inside == 1);

                fp = (Fingerprint)id0.qspn_manager.get_fingerprint(4);
                nodes_inside = id0.qspn_manager.get_nodes_inside(4);
                fp_elderships_seed = fp_elderships_seed_repr(fp);
                assert(fp.id == beta_fp0);
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
}