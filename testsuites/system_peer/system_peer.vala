using Netsukuku.Qspn;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace SystemPeer
{
    string json_string_object(Object obj)
    {
        Json.Node n = Json.gobject_serialize(obj);
        Json.Generator g = new Json.Generator();
        g.root = n;
        string ret = g.to_data(null);
        return ret;
    }

    string topology;
    int pid;
    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;
    [CCode (array_length = false, array_null_terminated = true)]
    string[] arcs;
    [CCode (array_length = false, array_null_terminated = true)]
    string[] _tasks;
    bool check_four_nodes;

    ITasklet tasklet;
    HashMap<int,IdentityData> local_identities;
    SkeletonFactory skeleton_factory;
    StubFactory stub_factory;
    HashMap<string,PseudoNetworkInterface> pseudonic_map;
    ArrayList<PseudoArc> arc_list;
    int next_local_identity_index = 0;
    ArrayList<int> gsizes;
    ArrayList<int> g_exp;
    int levels;
    ArrayList<string> tester_events;
    ArrayList<string> failed_checks_labels;

    IdentityData create_local_identity(NodeID nodeid, int local_identity_index)
    {
        if (local_identities == null) local_identities = new HashMap<int,IdentityData>();
        assert(! (nodeid.id in local_identities.keys));
        IdentityData ret = new IdentityData(nodeid, local_identity_index);
        local_identities[nodeid.id] = ret;
        return ret;
    }

    IdentityData? find_local_identity(NodeID nodeid)
    {
        assert(local_identities != null);
        if (nodeid.id in local_identities.keys) return local_identities[nodeid.id];
        return null;
    }

    void remove_local_identity(NodeID nodeid)
    {
        assert(local_identities != null);
        assert(nodeid.id in local_identities.keys);
        local_identities.unset(nodeid.id);
    }

    const int max_paths = 5;
    const double max_common_hops_ratio = 0.6;
    const int arc_timeout = 10000;

    int main(string[] _args)
    {
        pid = 0; // default
        topology = "1,1,1,2"; // default
        check_four_nodes = false; // default
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[7];
        int index = 0;
        entries[index++] = {"topology", '\0', 0, OptionArg.STRING, ref topology, "Topology in bits. Default: 1,1,1,2", null};
        entries[index++] = {"pid", 'p', 0, OptionArg.INT, ref pid, "Fake PID (e.g. -p 1234).", null};
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = {"arcs", 'a', 0, OptionArg.STRING_ARRAY, ref arcs, "Arc my_dev,peer_pid,peer_dev,cost (e.g. -a eth1,5678,eth0,300). You can use it multiple times.", null};
        entries[index++] = {"tasks", 't', 0, OptionArg.STRING_ARRAY, ref _tasks,
                "Task. You can use it multiple times.\n\t\t\t " +
                "E.g.: -t add_idarc,2000,1,0,1 means: after 2000 ms add an identity-arc\n\t\t\t " +
                "on arc #1 from my identity #0 to peer's identity #1.\n\t\t\t " +
                "See readme for docs on each task.", null};
        entries[index++] = {"check-four-nodes", '\0', 0, OptionArg.NONE, ref check_four_nodes, "Final check for test four_nodes.", null};
        entries[index++] = { null };
        oc.add_main_entries(entries, null);
        try {
            oc.parse(ref _args);
        }
        catch (OptionError e) {
            print(@"Error parsing options: $(e.message)\n");
            return 1;
        }

        ArrayList<string> args = new ArrayList<string>.wrap(_args);
        tester_events = new ArrayList<string>();
        failed_checks_labels = new ArrayList<string>();

        // Topoplogy of the network.
        gsizes = new ArrayList<int>();
        g_exp = new ArrayList<int>();
        string[] topology_bits_array = topology.split(",");
        foreach (string s_topology_bits in topology_bits_array)
        {
            int64 topology_bits;
            if (! int64.try_parse(s_topology_bits, out topology_bits)) error("Bad arg topology");
            int _g_exp = (int)topology_bits;

            if (_g_exp < 1 || _g_exp > 16) error(@"Bad g_exp $(_g_exp): must be between 1 and 16");
            int gsize = 1 << _g_exp;
            g_exp.add(_g_exp);
            gsizes.add(gsize);
        }
        levels = gsizes.size;

        // Names of the network interfaces to do RPC.
        ArrayList<string> devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);

        // Definitions of the node-arcs.
        ArrayList<string> pseudo_arc_mydev_list = new ArrayList<string>();
        ArrayList<int> pseudo_arc_peerpid_list = new ArrayList<int>();
        ArrayList<string> pseudo_arc_peerdev_list = new ArrayList<string>();
        ArrayList<long> pseudo_arc_cost_list = new ArrayList<long>();
        foreach (string arc in arcs)
        {
            string[] arc_items = arc.split(",");
            if (arc_items.length != 4) error("bad args num in '--arcs'");
            string arc_item_my_dev = arc_items[0];
            if (! (arc_item_my_dev in devs)) error("bad arg my_dev in '--arcs'");
            int64 _arc_item_peer_pid;
            if (! int64.try_parse(arc_items[1], out _arc_item_peer_pid)) error("bad arg peer_pid in '--arcs'");
            if ((int)_arc_item_peer_pid == pid) error("bad arg peer_pid in '--arcs'");
            string arc_item_peer_dev = arc_items[2];
            int64 _arc_item_cost;
            if (! int64.try_parse(arc_items[3], out _arc_item_cost)) error("bad arg cost in '--arcs'");
            pseudo_arc_mydev_list.add(arc_item_my_dev);
            pseudo_arc_peerpid_list.add((int)_arc_item_peer_pid);
            pseudo_arc_peerdev_list.add(arc_item_peer_dev);
            pseudo_arc_cost_list.add((long)_arc_item_cost);
        }

        ArrayList<string> tasks = new ArrayList<string>();
        foreach (string task in _tasks) tasks.add(task);

        if (pid == 0) error("Bad usage");
        if (devs.is_empty) error("Bad usage");

        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Initialize modules that have remotable methods (serializable classes need to be registered).
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());
        typeof(IdentityAwareSourceID).class_peek();
        typeof(IdentityAwareUnicastID).class_peek();
        typeof(IdentityAwareBroadcastID).class_peek();
        typeof(Naddr).class_peek();
        typeof(Fingerprint).class_peek();
        typeof(Cost).class_peek();

        // Initialize pseudo-random number generators.
        string _seed = @"$(pid)";
        uint32 seed_prn = (uint32)_seed.hash();
        PRNGen.init_rngen(null, seed_prn);
        QspnManager.init_rngen(null, seed_prn);

        // First network: the node on its own. Address of the node.
        ArrayList<int> naddr = new ArrayList<int>();
        for (int i = 0; i < levels; i++)
            naddr.add((int)PRNGen.int_range(0, gsizes[i]));

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // RPC
        skeleton_factory = new SkeletonFactory();
        stub_factory = new StubFactory();

        pseudonic_map = new HashMap<string,PseudoNetworkInterface>();
        arc_list = new ArrayList<PseudoArc>();
        foreach (string dev in devs)
        {
            assert(!(dev in pseudonic_map.keys));
            string listen_pathname = @"recv_$(pid)_$(dev)";
            string send_pathname = @"send_$(pid)_$(dev)";
            string mac = fake_random_mac(pid, dev);
            // @"fe:aa:aa:$(PRNGen.int_range(10, 100)):$(PRNGen.int_range(10, 100)):$(PRNGen.int_range(10, 100))";
            print(@"INFO: mac for $(pid),$(dev) is $(mac).\n");
            PseudoNetworkInterface pseudonic = new PseudoNetworkInterface(dev, listen_pathname, send_pathname, mac);
            pseudonic_map[dev] = pseudonic;

            // Start listen datagram on dev
            skeleton_factory.start_datagram_system_listen(listen_pathname, send_pathname, new NeighbourSrcNic(mac));
            tasklet.ms_wait(1);
            print(@"started datagram_system_listen $(listen_pathname) $(send_pathname) $(mac).\n");

            // Start listen stream on linklocal
            string linklocal = fake_random_linklocal(mac);
            // @"169.254.$(PRNGen.int_range(1, 255)).$(PRNGen.int_range(1, 255))";
            print(@"INFO: linklocal for $(mac) is $(linklocal).\n");
            pseudonic.linklocal = linklocal;
            pseudonic.st_listen_pathname = @"conn_$(linklocal)";
            skeleton_factory.start_stream_system_listen(pseudonic.st_listen_pathname);
            tasklet.ms_wait(1);
            print(@"started stream_system_listen $(pseudonic.st_listen_pathname).\n");
        }
        for (int i = 0; i < pseudo_arc_mydev_list.size; i++)
        {
            string my_dev = pseudo_arc_mydev_list[i];
            int peer_pid = pseudo_arc_peerpid_list[i];
            string peer_dev = pseudo_arc_peerdev_list[i];
            long cost = pseudo_arc_cost_list[i];
            string peer_mac = fake_random_mac(peer_pid, peer_dev);
            string peer_linklocal = fake_random_linklocal(peer_mac);
            PseudoArc pseudoarc = new PseudoArc(my_dev, peer_pid, peer_mac, peer_linklocal, cost);
            arc_list.add(pseudoarc);
            print(@"INFO: arc #$(i) from $(my_dev) to pid$(peer_pid)+$(peer_dev)=$(peer_linklocal)\n");
        }

        // first id
        NodeID first_nodeid = fake_random_nodeid(pid, next_local_identity_index);
        string first_identity_name = @"$(pid)_$(next_local_identity_index)";
        print(@"INFO: nodeid for $(first_identity_name) is $(first_nodeid.id).\n");
        IdentityData first_identity_data = create_local_identity(first_nodeid, next_local_identity_index);
        next_local_identity_index++;

        first_identity_data.my_naddr = new Naddr(naddr.to_array(), gsizes.to_array());
        ArrayList<int> elderships = new ArrayList<int>();
        for (int i = 0; i < levels; i++) elderships.add(0);
        first_identity_data.my_fp = new Fingerprint(elderships.to_array());
        print(@"INFO: $(first_identity_name) has address $(json_string_object(first_identity_data.my_naddr))");
        print(@" and fp $(json_string_object(first_identity_data.my_fp)).\n");

        // First qspn manager
        first_identity_data.qspn_mgr = new QspnManager.create_net(
            first_identity_data.my_naddr,
            first_identity_data.my_fp,
            new QspnStubFactory(first_identity_data));
        string addr = ""; string addrnext = "";
        for (int i = 0; i < levels; i++)
        {
            addr = @"$(addr)$(addrnext)$(first_identity_data.my_naddr.pos[i])";
            addrnext = ",";
        }
        tester_events.add(@"Qspn:$(first_identity_data.local_identity_index):create_net:$(addr)");
        // immediately after creation, connect to signals.
        first_identity_data.qspn_mgr.arc_removed.connect(first_identity_data.arc_removed);
        first_identity_data.qspn_mgr.changed_fp.connect(first_identity_data.changed_fp);
        first_identity_data.qspn_mgr.changed_nodes_inside.connect(first_identity_data.changed_nodes_inside);
        first_identity_data.qspn_mgr.destination_added.connect(first_identity_data.destination_added);
        first_identity_data.qspn_mgr.destination_removed.connect(first_identity_data.destination_removed);
        first_identity_data.qspn_mgr.gnode_splitted.connect(first_identity_data.gnode_splitted);
        first_identity_data.qspn_mgr.path_added.connect(first_identity_data.path_added);
        first_identity_data.qspn_mgr.path_changed.connect(first_identity_data.path_changed);
        first_identity_data.qspn_mgr.path_removed.connect(first_identity_data.path_removed);
        first_identity_data.qspn_mgr.presence_notified.connect(first_identity_data.presence_notified);
        first_identity_data.qspn_mgr.qspn_bootstrap_complete.connect(first_identity_data.qspn_bootstrap_complete);
        first_identity_data.qspn_mgr.remove_identity.connect(first_identity_data.remove_identity);

        // First identity is immediately bootstrapped.
        while (! first_identity_data.qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(1);

        first_identity_data = null;

        foreach (string task in tasks)
        {
            if      (schedule_task_add_identity(task)) {}
            else if (schedule_task_enter_net(task)) {}
            else if (schedule_task_migrate(task)) {}
            else if (schedule_task_add_identityarc(task)) {}
            else if (schedule_task_add_qspnarc(task)) {}
            else if (schedule_task_check_destnum(task)) {}
            else if (schedule_task_remove_qspn(task)) {}
            else if (schedule_task_addtag(task)) {}
            else error(@"unknown task $(task)");
        }

        // TODO

        // Temporary: register handlers for SIGINT and SIGTERM to exit
        Posix.@signal(Posix.Signal.INT, safe_exit);
        Posix.@signal(Posix.Signal.TERM, safe_exit);
        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }

        // TODO

        // Remove connectivity identities.
        ArrayList<IdentityData> local_identities_copy = new ArrayList<IdentityData>();
        local_identities_copy.add_all(local_identities.values);
        foreach (IdentityData identity_data in local_identities_copy)
        {
            if (! identity_data.main_id)
            {
                // ... send "destroy" message.
                identity_data.qspn_mgr.destroy();
                // ... disconnect signal handlers of qspn_mgr.
                identity_data.qspn_mgr.arc_removed.disconnect(identity_data.arc_removed);
                identity_data.qspn_mgr.changed_fp.disconnect(identity_data.changed_fp);
                identity_data.qspn_mgr.changed_nodes_inside.disconnect(identity_data.changed_nodes_inside);
                identity_data.qspn_mgr.destination_added.disconnect(identity_data.destination_added);
                identity_data.qspn_mgr.destination_removed.disconnect(identity_data.destination_removed);
                identity_data.qspn_mgr.gnode_splitted.disconnect(identity_data.gnode_splitted);
                identity_data.qspn_mgr.path_added.disconnect(identity_data.path_added);
                identity_data.qspn_mgr.path_changed.disconnect(identity_data.path_changed);
                identity_data.qspn_mgr.path_removed.disconnect(identity_data.path_removed);
                identity_data.qspn_mgr.presence_notified.disconnect(identity_data.presence_notified);
                identity_data.qspn_mgr.qspn_bootstrap_complete.disconnect(identity_data.qspn_bootstrap_complete);
                identity_data.qspn_mgr.remove_identity.disconnect(identity_data.remove_identity);
                identity_data.qspn_mgr.stop_operations();

                remove_local_identity(identity_data.nodeid);
            }
        }
        local_identities_copy = null;

        // For main identity...
        assert(local_identities.keys.size == 1);
        IdentityData last_identity_data = local_identities.values.to_array()[0];
        assert(last_identity_data.main_id);

        // ... send "destroy" message.
        last_identity_data.qspn_mgr.destroy();
        // ... disconnect signal handlers of qspn_mgr.
        last_identity_data.qspn_mgr.arc_removed.disconnect(last_identity_data.arc_removed);
        last_identity_data.qspn_mgr.changed_fp.disconnect(last_identity_data.changed_fp);
        last_identity_data.qspn_mgr.changed_nodes_inside.disconnect(last_identity_data.changed_nodes_inside);
        last_identity_data.qspn_mgr.destination_added.disconnect(last_identity_data.destination_added);
        last_identity_data.qspn_mgr.destination_removed.disconnect(last_identity_data.destination_removed);
        last_identity_data.qspn_mgr.gnode_splitted.disconnect(last_identity_data.gnode_splitted);
        last_identity_data.qspn_mgr.path_added.disconnect(last_identity_data.path_added);
        last_identity_data.qspn_mgr.path_changed.disconnect(last_identity_data.path_changed);
        last_identity_data.qspn_mgr.path_removed.disconnect(last_identity_data.path_removed);
        last_identity_data.qspn_mgr.presence_notified.disconnect(last_identity_data.presence_notified);
        last_identity_data.qspn_mgr.qspn_bootstrap_complete.disconnect(last_identity_data.qspn_bootstrap_complete);
        last_identity_data.qspn_mgr.remove_identity.disconnect(last_identity_data.remove_identity);
        last_identity_data.qspn_mgr.stop_operations();

        remove_local_identity(last_identity_data.nodeid);
        last_identity_data = null;

        // Call stop_rpc.
        ArrayList<string> final_devs = new ArrayList<string>();
        final_devs.add_all(pseudonic_map.keys);
        foreach (string dev in final_devs)
        {
            PseudoNetworkInterface pseudonic = pseudonic_map[dev];
            skeleton_factory.stop_stream_system_listen(pseudonic.st_listen_pathname);
            print(@"stopped stream_system_listen $(pseudonic.st_listen_pathname).\n");
            skeleton_factory.stop_datagram_system_listen(pseudonic.listen_pathname);
            print(@"stopped datagram_system_listen $(pseudonic.listen_pathname).\n");
            pseudonic_map.unset(dev);
        }
        skeleton_factory = null;

        PthTaskletImplementer.kill();

        print("Exiting. Event list:\n");
        foreach (string s in tester_events) print(@"$(s)\n");

        if (! failed_checks_labels.is_empty)
        {
            foreach (string failed_check_label in failed_checks_labels) print(@"Failed check '$(failed_check_label)'.\n");
            error("Some checks failed.");
        }

        if (check_four_nodes)
        {
            print("Doing check_four_nodes...\n");
            if (pid == 1) do_check_four_nodes_pid1();
            else if (pid == 4) do_check_four_nodes_pid4();
        }

        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }

    class PseudoNetworkInterface : Object
    {
        public PseudoNetworkInterface(string dev, string listen_pathname, string send_pathname, string mac)
        {
            this.dev = dev;
            this.listen_pathname = listen_pathname;
            this.send_pathname = send_pathname;
            this.mac = mac;
        }
        public string mac {get; private set;}
        public string send_pathname {get; private set;}
        public string listen_pathname {get; private set;}
        public string dev {get; private set;}
        public string linklocal {get; set;}
        public string st_listen_pathname {get; set;}
    }

    class PseudoArc : Object
    {
        public PseudoArc(string my_dev, int peer_pid, string peer_mac, string peer_linklocal, long cost)
        {
            assert(pseudonic_map.has_key(my_dev));
            my_nic = pseudonic_map[my_dev];
            this.peer_pid = peer_pid;
            this.peer_mac = peer_mac;
            this.peer_linklocal = peer_linklocal;
            this.cost = cost;
        }
        public PseudoNetworkInterface my_nic {get; private set;}
        public int peer_pid {get; private set;}
        public string peer_mac {get; private set;}
        public string peer_linklocal {get; private set;}
        public long cost {get; set;}
    }

    string fake_random_mac(int pid, string dev)
    {
        string _seed = @"$(pid)_$(dev)";
        uint32 seed_prn = (uint32)_seed.hash();
        Rand _rand = new Rand.with_seed(seed_prn);
        return @"fe:aa:aa:$(_rand.int_range(10, 100)):$(_rand.int_range(10, 100)):$(_rand.int_range(10, 100))";
    }

    string fake_random_linklocal(string mac)
    {
        uint32 seed_prn = (uint32)mac.hash();
        Rand _rand = new Rand.with_seed(seed_prn);
        return @"169.254.$(_rand.int_range(1, 255)).$(_rand.int_range(1, 255))";
    }

    NodeID fake_random_nodeid(int pid, int node_index)
    {
        string _seed = @"$(pid)_$(node_index)";
        uint32 seed_prn = (uint32)_seed.hash();
        Rand _rand = new Rand.with_seed(seed_prn);
        return new NodeID((int)(_rand.int_range(1, 100000)));
    }

    class IdentityData : Object
    {
        public IdentityData(NodeID nodeid, int local_identity_index)
        {
            this.local_identity_index = local_identity_index;
            this.nodeid = nodeid;
            identity_arcs = new ArrayList<IdentityArc>();
            connectivity_from_level = 0;
            connectivity_to_level = 0;
            copy_of_identity = null;
            qspn_mgr = null;
        }

        public int local_identity_index;

        public NodeID nodeid;
        public Naddr my_naddr;
        public Fingerprint my_fp;
        public int connectivity_from_level;
        public int connectivity_to_level;
        public weak IdentityData? copy_of_identity;

        public QspnManager qspn_mgr;
        public bool main_id {
            get {
                return connectivity_from_level == 0;
            }
        }

        public ArrayList<IdentityArc> identity_arcs;
        public IdentityArc? identity_arcs_find(PseudoArc arc, NodeID peer_nodeid)
        {
            assert(identity_arcs != null);
            foreach (IdentityArc ia in identity_arcs)
                if (ia.arc == arc && ia.peer_nodeid.equals(peer_nodeid))
                return ia;
            return null;
        }

        // handle signals from qspn_manager

        public void arc_removed(IQspnArc arc, bool bad_link)
        {
            per_identity_qspn_arc_removed(this, arc, bad_link);
        }

        public void changed_fp(int l)
        {
            per_identity_qspn_changed_fp(this, l);
        }

        public void changed_nodes_inside(int l)
        {
            per_identity_qspn_changed_nodes_inside(this, l);
        }

        public void destination_added(HCoord h)
        {
            per_identity_qspn_destination_added(this, h);
        }

        public void destination_removed(HCoord h)
        {
            per_identity_qspn_destination_removed(this, h);
        }

        public void gnode_splitted(IQspnArc a, HCoord d, IQspnFingerprint fp)
        {
            per_identity_qspn_gnode_splitted(this, a, d, fp);
        }

        public void path_added(IQspnNodePath p)
        {
            per_identity_qspn_path_added(this, p);
        }

        public void path_changed(IQspnNodePath p)
        {
            per_identity_qspn_path_changed(this, p);
        }

        public void path_removed(IQspnNodePath p)
        {
            per_identity_qspn_path_removed(this, p);
        }

        public void presence_notified()
        {
            per_identity_qspn_presence_notified(this);
        }

        public void qspn_bootstrap_complete()
        {
            per_identity_qspn_qspn_bootstrap_complete(this);
        }

        public void remove_identity()
        {
            per_identity_qspn_remove_identity(this);
        }
    }

    class IdentityArc : Object
    {
        public weak IdentityData identity_data;
        public PseudoArc arc;
        public NodeID peer_nodeid;

        public QspnArc? qspn_arc;

        public IdentityArc(IdentityData identity_data, PseudoArc arc, NodeID peer_nodeid)
        {
            this.identity_data = identity_data;
            this.arc = arc;
            this.peer_nodeid = peer_nodeid;

            qspn_arc = null;
        }
    }
}