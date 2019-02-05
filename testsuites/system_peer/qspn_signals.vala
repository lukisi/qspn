using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    void per_identity_qspn_qspn_bootstrap_complete(IdentityData id)
    {
        try {
            bool is_main = id.main_id;
            ArrayList<int> known_dests = new ArrayList<int>();
            ArrayList<int> nodes_inside = new ArrayList<int>();
            ArrayList<int> fingerprints = new ArrayList<int>();
            for (int l = 0; l <= levels; l++)
            {
                Fingerprint f = (Fingerprint)id.qspn_mgr.get_fingerprint(l);
                fingerprints.add((int)f.id);
                nodes_inside.add(id.qspn_mgr.get_nodes_inside(l));
            }
            known_dests.add(0);
            for (int l = 0; l < levels; l++)
            {
                known_dests.add(id.qspn_mgr.get_known_destinations(l).size);
            }
            print(@"Qspn: Identity #$(id.local_identity_index): bootstrap completed.\n");
            if (is_main) print("      This is main identity right now.\n");
            else         print("      This is NOT main identity.\n");
            for (int l = 0; l <= levels; l++)
            {
                print(@"      My g-node of level $(l):\n");
                print(@"         has fingerprint $(fingerprints[l]);\n");
                print(@"         has $(known_dests[l]) children (except myself);\n");
                print(@"         contains circa $(nodes_inside[l]) nodes.\n");
            }
            string descr = "";
            if (is_main) descr = @"$(descr)Main:";
            else         descr = @"$(descr)Connectivity:";
            for (int l = 0; l <= levels; l++)
            {
                descr = @"$(descr)$(fingerprints[l])+$(known_dests[l])+$(nodes_inside[l])";
                if (l < levels) descr = @"$(descr)_";
            }
            tester_events.add(@"Qspn:$(id.local_identity_index):Signal:qspn_bootstrap_complete:$(descr)");
        } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
    }

    void per_identity_qspn_destination_added(IdentityData id, HCoord h)
    {
        print(@"Qspn: Identity #$(id.local_identity_index): destination added.\n");
        print(@"      Destination is ($(h.lvl), $(h.pos)).\n");
        string descr = @"$(h.lvl)+$(h.pos)";
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:destination_added:$(descr)");
    }

    void per_identity_qspn_destination_removed(IdentityData id, HCoord h)
    {
        print(@"Qspn: Identity #$(id.local_identity_index): destination removed.\n");
        print(@"      Destination is ($(h.lvl), $(h.pos)).\n");
        string descr = @"$(h.lvl)+$(h.pos)";
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:destination_removed:$(descr)");
    }

    void per_identity_qspn_path_added(IdentityData id, IQspnNodePath p)
    {
        HCoord dest = p.i_qspn_get_hops().last().i_qspn_get_hcoord();
        PseudoArc arc = ((QspnArc)p.i_qspn_get_arc()).arc;
        PseudoNetworkInterface my_nic = arc.my_nic;
        string start_from_dev = my_nic.dev;
        string steps = ""; string next = "";
        foreach (IQspnHop hop in p.i_qspn_get_hops())
        {
            HCoord step = hop.i_qspn_get_hcoord();
            steps = @"$(steps)$(next)($(step.lvl), $(step.pos))";
            next = " - ";
        }
        IQspnCost _c = p.i_qspn_get_cost();
        string cost;
        if (_c is Cost) {cost = @"RTT = $(((Cost)_c).usec_rtt) usec";}
        else {cost = "unknown";}
        print(@"Qspn: Identity #$(id.local_identity_index): [$(printabletime())] path added.\n");
        print(@"      Destination is ($(dest.lvl), $(dest.pos)), starting with my NIC '$(start_from_dev)'.\n");
        print(@"      Steps are $(steps); cost is $(cost).\n");
        string descr = @"$(start_from_dev)";
        foreach (IQspnHop hop in p.i_qspn_get_hops())
        {
            HCoord step = hop.i_qspn_get_hcoord();
            descr = @"$(descr)_$(step.lvl)+$(step.pos)";
        }
        assert(_c is Cost);
        string cost_rtt_usec = @"$(((Cost)_c).usec_rtt)";
        descr = @"$(descr)_$(cost_rtt_usec)";
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:path_added:$(descr)");
    }

    void per_identity_qspn_path_changed(IdentityData id, IQspnNodePath p)
    {
        HCoord dest = p.i_qspn_get_hops().last().i_qspn_get_hcoord();
        PseudoArc arc = ((QspnArc)p.i_qspn_get_arc()).arc;
        PseudoNetworkInterface my_nic = arc.my_nic;
        string start_from_dev = my_nic.dev;
        string steps = ""; string next = "";
        foreach (IQspnHop hop in p.i_qspn_get_hops())
        {
            HCoord step = hop.i_qspn_get_hcoord();
            steps = @"$(steps)$(next)($(step.lvl), $(step.pos))";
            next = " - ";
        }
        IQspnCost _c = p.i_qspn_get_cost();
        string cost;
        if (_c is Cost) {cost = @"RTT = $(((Cost)_c).usec_rtt) usec";}
        else {cost = "unknown";}
        print(@"Qspn: Identity #$(id.local_identity_index): [$(printabletime())] path changed.\n");
        print(@"      Destination is ($(dest.lvl), $(dest.pos)), starting with my NIC '$(start_from_dev)'.\n");
        print(@"      Steps are $(steps); cost is $(cost).\n");
        string descr = @"$(start_from_dev)";
        foreach (IQspnHop hop in p.i_qspn_get_hops())
        {
            HCoord step = hop.i_qspn_get_hcoord();
            descr = @"$(descr)_$(step.lvl)+$(step.pos)";
        }
        assert(_c is Cost);
        string cost_rtt_usec = @"$(((Cost)_c).usec_rtt)";
        descr = @"$(descr)_$(cost_rtt_usec)";
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:path_changed:$(descr)");
    }

    void per_identity_qspn_path_removed(IdentityData id, IQspnNodePath p)
    {
        HCoord dest = p.i_qspn_get_hops().last().i_qspn_get_hcoord();
        PseudoArc arc = ((QspnArc)p.i_qspn_get_arc()).arc;
        PseudoNetworkInterface my_nic = arc.my_nic;
        string start_from_dev = my_nic.dev;
        string steps = ""; string next = "";
        foreach (IQspnHop hop in p.i_qspn_get_hops())
        {
            HCoord step = hop.i_qspn_get_hcoord();
            steps = @"$(steps)$(next)($(step.lvl), $(step.pos))";
            next = " - ";
        }
        IQspnCost _c = p.i_qspn_get_cost();
        string cost;
        if (_c is Cost) {cost = @"RTT = $(((Cost)_c).usec_rtt) usec";}
        else {cost = "unknown";}
        print(@"Qspn: Identity #$(id.local_identity_index): [$(printabletime())] path removed.\n");
        print(@"      Destination is ($(dest.lvl), $(dest.pos)), starting with my NIC '$(start_from_dev)'.\n");
        print(@"      Steps are $(steps); cost is $(cost).\n");
        string descr = @"$(start_from_dev)";
        foreach (IQspnHop hop in p.i_qspn_get_hops())
        {
            HCoord step = hop.i_qspn_get_hcoord();
            descr = @"$(descr)_$(step.lvl)+$(step.pos)";
        }
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:path_removed:$(descr)");
    }

    void per_identity_qspn_changed_fp(IdentityData id, int l)
    {
        print(@"Qspn: Identity #$(id.local_identity_index): fingerprint changed at level $(l).\n");
        bool is_main = id.main_id;
        if (is_main) print("      This is main identity right now.\n");
        else         print("      This is NOT main identity.\n");
        string descr = "";
        if (is_main) descr = @"$(descr)Main:";
        else         descr = @"$(descr)Connectivity:";
        try {
            Fingerprint f = (Fingerprint)id.qspn_mgr.get_fingerprint(l);
            int fingerprints = (int)f.id;
            int nodes_inside = id.qspn_mgr.get_nodes_inside(l);
            int known_dests = id.qspn_mgr.get_known_destinations(l-1).size;
            print(@"      Fingerprint $(fingerprints);\n");
            print(@"      Has $(known_dests) children (except myself);\n");
            print(@"      Contains circa $(nodes_inside) nodes.\n");
            descr = @"$(descr)$(fingerprints)+$(known_dests)+$(nodes_inside)";
        } catch (QspnBootstrapInProgressError e) {
            print(@"      It is still bootstraping at level $(l).\n");
            descr = @"$(descr)Bootstrap";
        }
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:changed_fp($(l)):$(descr)");
    }

    void per_identity_qspn_changed_nodes_inside(IdentityData id, int l)
    {
        print(@"Qspn: Identity #$(id.local_identity_index): nodes inside changed at level $(l).\n");
        bool is_main = id.main_id;
        if (is_main) print("      This is main identity right now.\n");
        else         print("      This is NOT main identity.\n");
        string descr = "";
        if (is_main) descr = @"$(descr)Main:";
        else         descr = @"$(descr)Connectivity:";
        try {
            int nodes_inside = id.qspn_mgr.get_nodes_inside(l);
            int known_dests = id.qspn_mgr.get_known_destinations(l-1).size;
            print(@"      Has $(known_dests) children (except myself);\n");
            print(@"      Contains circa $(nodes_inside) nodes.\n");
            descr = @"$(descr)$(known_dests)+$(nodes_inside)";
        } catch (QspnBootstrapInProgressError e) {
            print(@"      It is still bootstraping at level $(l).\n");
            descr = @"$(descr)Bootstrap";
        }
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:changed_nodes_inside($(l)):$(descr)");
    }

    void per_identity_qspn_presence_notified(IdentityData id)
    {
        print(@"Qspn: Identity #$(id.local_identity_index): presence notified.\n");
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:presence_notified");
    }

    void per_identity_qspn_remove_identity(IdentityData id)
    {
        print(@"Qspn: Identity #$(id.local_identity_index): removed identity.\n");
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:remove_identity");
    }

    void per_identity_qspn_arc_removed(IdentityData id, IQspnArc arc, bool bad_link)
    {
        string s_bad_link = bad_link ? "bad link" : "not bad link";
        print(@"Qspn: Identity #$(id.local_identity_index): arc removed, $(s_bad_link).\n");
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:arc_removed($(s_bad_link))");
    }

    void per_identity_qspn_gnode_splitted(IdentityData id, IQspnArc a, HCoord d, IQspnFingerprint fp)
    {
        IdentityArc ia = ((QspnArc)a).ia;
        NodeID peer_nodeid = ia.peer_nodeid;
        print(@"Qspn: Identity #$(id.local_identity_index): gnode splitted for peer_nodeid $(peer_nodeid.id).\n");
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:gnode_splitted($(peer_nodeid.id))");
    }
}