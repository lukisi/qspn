using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    void per_identity_qspn_qspn_bootstrap_complete(IdentityData id)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:qspn_bootstrap_complete");
        print(@"Qspn: Identity #$(id.local_identity_index): bootstrap completed.\n");
    }

    void per_identity_qspn_destination_added(IdentityData id, HCoord h)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:destination_added");
        print(@"Qspn: Identity #$(id.local_identity_index): destination added.\n");
    }

    void per_identity_qspn_destination_removed(IdentityData id, HCoord h)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:destination_removed");
        print(@"Qspn: Identity #$(id.local_identity_index): destination removed.\n");
    }

    void per_identity_qspn_path_added(IdentityData id, IQspnNodePath p)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:path_added");
        print(@"Qspn: Identity #$(id.local_identity_index): path added.\n");
    }

    void per_identity_qspn_path_changed(IdentityData id, IQspnNodePath p)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:path_changed");
        print(@"Qspn: Identity #$(id.local_identity_index): path changed.\n");
    }

    void per_identity_qspn_path_removed(IdentityData id, IQspnNodePath p)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:path_removed");
        print(@"Qspn: Identity #$(id.local_identity_index): path removed.\n");
    }

    void per_identity_qspn_changed_fp(IdentityData id, int l)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:changed_fp($(l))");
        print(@"Qspn: Identity #$(id.local_identity_index): fingerprint changed at level $(l).\n");
    }

    void per_identity_qspn_changed_nodes_inside(IdentityData id, int l)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:changed_nodes_inside($(l))");
        print(@"Qspn: Identity #$(id.local_identity_index): nodes inside changed at level $(l).\n");
    }

    void per_identity_qspn_presence_notified(IdentityData id)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:presence_notified");
        print(@"Qspn: Identity #$(id.local_identity_index): presence notified.\n");
    }

    void per_identity_qspn_remove_identity(IdentityData id)
    {
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:remove_identity");
        print(@"Qspn: Identity #$(id.local_identity_index): removed identity.\n");
    }

    void per_identity_qspn_arc_removed(IdentityData id, IQspnArc arc, bool bad_link)
    {
        string s_bad_link = bad_link ? "bad link" : "not bad link";
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:arc_removed($(s_bad_link))");
        print(@"Qspn: Identity #$(id.local_identity_index): arc removed, $(s_bad_link).\n");
    }

    void per_identity_qspn_gnode_splitted(IdentityData id, IQspnArc a, HCoord d, IQspnFingerprint fp)
    {
        IdentityArc ia = ((QspnArc)a).ia;
        NodeID peer_nodeid = ia.peer_nodeid;
        tester_events.add(@"Qspn:$(id.local_identity_index):Signal:gnode_splitted($(peer_nodeid.id))");
        print(@"Qspn: Identity #$(id.local_identity_index): gnode splitted for peer_nodeid $(peer_nodeid.id).\n");
    }
}

