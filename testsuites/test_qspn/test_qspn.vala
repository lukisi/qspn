using Tasklets;
using Gee;
using zcd;
using Netsukuku;

namespace Netsukuku
{
    public void    log_debug(string msg)   {print(msg+"\n");}
    public void    log_trace(string msg)   {print(msg+"\n");}
    public void  log_verbose(string msg)   {print(msg+"\n");}
    public void     log_info(string msg)   {print(msg+"\n");}
    public void   log_notice(string msg)   {print(msg+"\n");}
    public void     log_warn(string msg)   {print(msg+"\n");}
    public void    log_error(string msg)   {print(msg+"\n");}
    public void log_critical(string msg)   {print(msg+"\n");}
}

void print_known_paths(FakeGenericNaddr n, QspnManager c)
{
        print(@"For $(n)\n");
        for (int l = 0; l < n.i_qspn_get_levels(); l++)
        for (int p = 0; p < n.i_qspn_get_gsize(l); p++)
        {
            if (n.i_qspn_get_pos(l) == p) continue;
            int s = c.get_paths_to(new HCoord(l, p)).size;
            if (s > 0) print(@" to ($(l), $(p)) $(s) paths\n");
        }
}

int main()
{
    // init tasklet
    assert(Tasklet.init());
    {
        const int max_paths = 2;
        const double max_common_hops_ratio = 0.7;
        const int[] net_topology = {256, 16, 16, 16};
        const int[] n1_addr = { 1,  0,  0,  0};
        const int[] n2_addr = { 1, 10,  0,  0};
        const int[] n3_addr = { 1, 10,  0,  1};
        const int[] n4_addr = { 2, 10,  0,  0};
        const int[] n5_addr = { 1,  0,  3,  0};
        const int[] n6_addr = { 0,  0,  1,  5};
        string n1_nic1_addr = "100.10.0.1";
        string n2_nic1_addr = "100.10.0.2";
        string n3_nic1_addr = "100.10.0.3";
        string n4_nic1_addr = "100.10.0.4";
        string n5_nic1_addr = "100.10.0.5";
        string n6_nic1_addr = "100.10.0.6";

        // create module qspn c1
        FakeGenericNaddr n1 = new FakeGenericNaddr(n1_addr, net_topology);
        var n1_id = new FakeNodeID();
        var arclist = new ArrayList<IQspnArc>();
        var f1 = new FakeFingerprint(34346, {0, 0, 0, 0});
        var fmgr = new FakeREM.FakeFingerprintManager();
        var tostub = new FakeArcToStub();
        var c1 = new QspnManager(n1, max_paths, max_common_hops_ratio, arclist, f1, tostub, fmgr, new FakeEtpFactory());
        tostub.my_mgr = c1;
        assert(c1.is_mature());
        ms_wait(300);

        // create module qspn c2 with an arc towards c1
        FakeGenericNaddr n2 = new FakeGenericNaddr(n2_addr, net_topology);
        var n2_id = new FakeNodeID();
        var arc2to1 = new FakeArc(c1, n1, new FakeREM(2000), n1_id, n1_nic1_addr, n2_nic1_addr);
        arclist = new ArrayList<IQspnArc>();
        arclist.add(arc2to1);
        var f2 = new FakeFingerprint(3467, {0, 1, 0, 0});
        fmgr = new FakeREM.FakeFingerprintManager();
        tostub = new FakeArcToStub();
        var c2 = new QspnManager(n2, max_paths, max_common_hops_ratio, arclist, f2, tostub, fmgr, new FakeEtpFactory());
        tostub.my_mgr = c2;

        // add an arc to c1 towards c2
        var arc1to2 = new FakeArc(c2, n2, new FakeREM(2100), n2_id, n2_nic1_addr, n1_nic1_addr);
        c1.arc_add(arc1to2);
        ms_wait(300);
        assert(c2.is_mature());

        // Some asserts
        try {
            FakeFingerprint c1network;
            FakeFingerprint c2network;
            int c1tot;
            int c2tot;
            c1network = (FakeFingerprint)c1.get_fingerprint(4);
            c2network = (FakeFingerprint)c2.get_fingerprint(4);
            c1tot = c1.get_nodes_inside(4);
            c2tot = c2.get_nodes_inside(4);
            assert(c1network.i_qspn_equals(c2network));
            assert(c1tot == 2);
            assert(c2tot == 2);
            assert(c2.get_paths_to(new HCoord(3, 1)).is_empty);
            bool n2_has_path_towards_n1 = false;
            foreach (IQspnNodePath np in c2.get_paths_to(n2.i_qspn_get_coord_by_address(n1)))
            {
                n2_has_path_towards_n1 = true;
                FakeREM cost = (FakeREM)(np.i_qspn_get_cost());
                assert(cost.usec_rtt == 2000);
            }
            assert(n2_has_path_towards_n1);
            assert(c1.get_paths_to(new HCoord(3, 1)).is_empty);
            bool n1_has_path_towards_n2 = false;
            foreach (IQspnNodePath np in c1.get_paths_to(n1.i_qspn_get_coord_by_address(n2)))
            {
                n1_has_path_towards_n2 = true;
                FakeREM cost = (FakeREM)(np.i_qspn_get_cost());
                assert(cost.usec_rtt == 2100);
            }
            assert(n1_has_path_towards_n2);
        } catch (QspnNotMatureError e) {assert_not_reached();}

        // create module qspn c3 with an arc towards c1 and one towards c2
        FakeGenericNaddr n3 = new FakeGenericNaddr(n3_addr, net_topology);
        var n3_id = new FakeNodeID();
        var arc3to1 = new FakeArc(c1, n1, new FakeREM(1900), n1_id, n1_nic1_addr, n3_nic1_addr);
        var arc3to2 = new FakeArc(c2, n2, new FakeREM(1800), n2_id, n2_nic1_addr, n3_nic1_addr);
        arclist = new ArrayList<IQspnArc>();
        arclist.add(arc3to1);
        arclist.add(arc3to2);
        var f3 = new FakeFingerprint(457437, {0, 0, 0, 1});
        fmgr = new FakeREM.FakeFingerprintManager();
        tostub = new FakeArcToStub();
        var c3 = new QspnManager(n3, max_paths, max_common_hops_ratio, arclist, f3, tostub, fmgr, new FakeEtpFactory());
        tostub.my_mgr = c3;

        // add an arc to c1 towards c3
        var arc1to3 = new FakeArc(c3, n3, new FakeREM(1900), n3_id, n3_nic1_addr, n1_nic1_addr);
        c1.arc_add(arc1to3);
        // add an arc to c2 towards c3
        var arc2to3 = new FakeArc(c3, n3, new FakeREM(1800), n3_id, n3_nic1_addr, n2_nic1_addr);
        c2.arc_add(arc2to3);
        // wait
        ms_wait(300);
        assert(c3.is_mature());

        // Some asserts
        try {
            FakeFingerprint c3network;
            FakeFingerprint c1network;
            int c3g4tot;
            int c3g3tot;
            int c2g3tot;
            int c3h30tot;
            c3network = (FakeFingerprint)c3.get_fingerprint(4);
            c1network = (FakeFingerprint)c1.get_fingerprint(4);
            c3g4tot = c3.get_nodes_inside(4);
            c3g3tot = c3.get_nodes_inside(3);
            c2g3tot = c2.get_nodes_inside(3);
            c3h30tot = c3.get_paths_to(new HCoord(3,0))[0].i_qspn_get_nodes_inside();
            //debug(@"Node 3 $(n3) says that network id is $(c3network.id)");
            //debug(@"Node 3 $(n3) says that network has $(c3g4tot) nodes");
            //debug(@"Node 3 $(n3) says that gnode [1] has $(c3g3tot) nodes");
            //debug(@"Node 2 $(n2) says that gnode [0] has $(c2g3tot) nodes");
            //debug(@"Node 3 $(n3) says that gnode [0] has $(c3h30tot) nodes");
            assert(c3network.i_qspn_equals(c1network));
            assert(c3g4tot == 3);
            assert(c3g3tot == 1);
            assert(c2g3tot == c3h30tot);
        } catch (QspnNotMatureError e) {assert_not_reached();}

        // create module qspn c4 with an arc towards c2
        FakeGenericNaddr n4 = new FakeGenericNaddr(n4_addr, net_topology);
        var n4_id = new FakeNodeID();
        var arc4to2 = new FakeArc(c2, n2, new FakeREM(2000), n2_id, n2_nic1_addr, n4_nic1_addr);
        arclist = new ArrayList<IQspnArc>();
        arclist.add(arc4to2);
        var f4 = new FakeFingerprint(45778, {1, 1, 0, 0});
        fmgr = new FakeREM.FakeFingerprintManager();
        tostub = new FakeArcToStub();
        var c4 = new QspnManager(n4, max_paths, max_common_hops_ratio, arclist, f4, tostub, fmgr, new FakeEtpFactory());
        tostub.my_mgr = c4;

        // add an arc to c2 towards c4
        var arc2to4 = new FakeArc(c4, n4, new FakeREM(2100), n4_id, n4_nic1_addr, n2_nic1_addr);
        c2.arc_add(arc2to4);
        ms_wait(300);
        assert(c4.is_mature());

        // create module qspn c5 with an arc towards c4
        FakeGenericNaddr n5 = new FakeGenericNaddr(n5_addr, net_topology);
        var n5_id = new FakeNodeID();
        var arc5to4 = new FakeArc(c4, n4, new FakeREM(2000), n4_id, n4_nic1_addr, n5_nic1_addr);
        arclist = new ArrayList<IQspnArc>();
        arclist.add(arc5to4);
        var f5 = new FakeFingerprint(485345, {0, 0, 1, 0});
        fmgr = new FakeREM.FakeFingerprintManager();
        tostub = new FakeArcToStub();
        var c5 = new QspnManager(n5, max_paths, max_common_hops_ratio, arclist, f5, tostub, fmgr, new FakeEtpFactory());
        tostub.my_mgr = c5;

        // add an arc to c4 towards c5
        var arc4to5 = new FakeArc(c5, n5, new FakeREM(2100), n5_id, n5_nic1_addr, n4_nic1_addr);
        c4.arc_add(arc4to5);
        ms_wait(300);
        assert(c5.is_mature());

        // create module qspn c6 with an arc towards c3 and one towards c5
        FakeGenericNaddr n6 = new FakeGenericNaddr(n6_addr, net_topology);
        var n6_id = new FakeNodeID();
        var arc6to3 = new FakeArc(c3, n3, new FakeREM(1900), n3_id, n3_nic1_addr, n6_nic1_addr);
        var arc6to5 = new FakeArc(c5, n5, new FakeREM(1800), n5_id, n5_nic1_addr, n6_nic1_addr);
        arclist = new ArrayList<IQspnArc>();
        arclist.add(arc6to3);
        arclist.add(arc6to5);
        var f6 = new FakeFingerprint(457620, {0, 0, 0, 2});
        fmgr = new FakeREM.FakeFingerprintManager();
        tostub = new FakeArcToStub();
        var c6 = new QspnManager(n6, max_paths, max_common_hops_ratio, arclist, f6, tostub, fmgr, new FakeEtpFactory());
        tostub.my_mgr = c6;

        // add an arc to c3 towards c6
        var arc3to6 = new FakeArc(c6, n6, new FakeREM(1900), n6_id, n6_nic1_addr, n3_nic1_addr);
        c3.arc_add(arc3to6);
        // add an arc to c5 towards c6
        var arc5to6 = new FakeArc(c6, n6, new FakeREM(1800), n6_id, n6_nic1_addr, n5_nic1_addr);
        c5.arc_add(arc5to6);
        // wait
        ms_wait(300);
        assert(c6.is_mature());

        print_known_paths(n2, c2);
        print_known_paths(n4, c4);

        // Some asserts
        try {
            FakeFingerprint c6network;
            FakeFingerprint c1network;
            int c6g4tot;
            int c6g3tot;
            int c2g3tot;
            int c6h30tot;
            c6network = (FakeFingerprint)c6.get_fingerprint(4);
            c1network = (FakeFingerprint)c1.get_fingerprint(4);
            c6g4tot = c6.get_nodes_inside(4);
            c6g3tot = c6.get_nodes_inside(3);
            c2g3tot = c2.get_nodes_inside(3);
            c6h30tot = c6.get_paths_to(new HCoord(3,0))[0].i_qspn_get_nodes_inside();
            debug(@"Node 6 $(n6) says that network id is $(c6network.id)");
            debug(@"Node 6 $(n6) says that network has $(c6g4tot) nodes");
            debug(@"Node 6 $(n6) says that gnode [5] has $(c6g3tot) nodes");
            debug(@"Node 2 $(n2) says that gnode [0] has $(c2g3tot) nodes");
            debug(@"Node 6 $(n6) says that gnode [0] has $(c6h30tot) nodes");
            assert(c6network.i_qspn_equals(c1network));
            //assert(c3g4tot == 3);
            //assert(c3g3tot == 1);
            //assert(c2g3tot == c3h30tot);
        } catch (QspnNotMatureError e) {assert_not_reached();}

        debug("stopping 1");
        c1.stop_operations();
        debug("stopping 2");
        c2.stop_operations();
        debug("stopping 3");
        c3.stop_operations();
        debug("stopping 4");
        c4.stop_operations();
        debug("stopping 5");
        c5.stop_operations();
        debug("stopping 6");
        c6.stop_operations();
    }
    assert(Tasklet.kill());
    return 0;
}

