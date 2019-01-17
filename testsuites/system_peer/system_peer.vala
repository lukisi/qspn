using Netsukuku.Qspn;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace SystemPeer
{
    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;
    [CCode (array_length = false, array_null_terminated = true)]
    string[] _tasks;
    int pid;

    ITasklet tasklet;
    HashMap<int,IdentityData> local_identities;
    SkeletonFactory skeleton_factory;
    StubFactory stub_factory;
    HashMap<string,PseudoNetworkInterface> pseudonic_map;
    ArrayList<PseudoArc> arc_list;

    IdentityData create_local_identity(NodeID node_id)
    {
        if (local_identities == null) local_identities = new HashMap<int,IdentityData>();
        assert(! (node_id.id in local_identities.keys));
        IdentityData ret = new IdentityData(node_id);
        local_identities[node_id.id] = ret;
        return ret;
    }

    IdentityData? find_local_identity(NodeID node_id)
    {
        assert(local_identities != null);
        if (node_id.id in local_identities.keys) return local_identities[node_id.id];
        return null;
    }

    void remove_local_identity(NodeID node_id)
    {
        assert(local_identities != null);
        assert(node_id.id in local_identities.keys);
        local_identities.unset(node_id.id);
    }

    const int max_paths = 5;
    const double max_common_hops_ratio = 0.6;
    const int arc_timeout = 10000;

    int main(string[] _args)
    {
        pid = 0; // default
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[4];
        int index = 0;
        entries[index++] = {"pid", 'p', 0, OptionArg.INT, ref pid, "Fake PID (e.g. -p 1234).", null};
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = {"tasks", 't', 0, OptionArg.STRING_ARRAY, ref _tasks, "Tasks (e.g. -t addarc,2,eth0,5,eth1 means: after 2 secs add an arc from my nic eth0 to the nic eth1 of pid5). You can use it multiple times.", null};
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

        ArrayList<string> devs;
        // Names of the network interfaces to do RPC.
        devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);

        ArrayList<string> tasks = new ArrayList<string>();
        foreach (string task in _tasks) tasks.add(task);

        if (pid == 0) error("Bad usage");
        if (devs.is_empty) error("Bad usage");

        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Initialize modules that have remotable methods (serializable classes need to be registered).
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());
        //typeof(WholeNodeSourceID).class_peek();

        // Initialize pseudo-random number generators.
        string _seed = @"$(pid)";
        uint32 seed_prn = (uint32)_seed.hash();
        PRNGen.init_rngen(null, seed_prn);
        QspnManager.init_rngen(null, seed_prn);

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
            // @"fe:aa:aa:$(PRNGen.int_range(10, 99)):$(PRNGen.int_range(10, 99)):$(PRNGen.int_range(10, 99))";
            print(@"INFO: mac for $(pid),$(dev) is $(mac).\n");
            PseudoNetworkInterface pseudonic = new PseudoNetworkInterface(dev, listen_pathname, send_pathname, mac);
            pseudonic_map[dev] = pseudonic;

            // Start listen datagram on dev
            skeleton_factory.start_datagram_system_listen(listen_pathname, send_pathname, new NeighbourSrcNic(mac));
            tasklet.ms_wait(1);
            print(@"started datagram_system_listen $(listen_pathname) $(send_pathname) $(mac).\n");

            // Start listen stream on linklocal
            string linklocal = fake_random_linklocal(mac);
            // @"169.254.$(PRNGen.int_range(0, 255)).$(PRNGen.int_range(0, 255))";
            print(@"INFO: linklocal for $(mac) is $(linklocal).\n");
            pseudonic.linklocal = linklocal;
            pseudonic.st_listen_pathname = @"conn_$(linklocal)";
            skeleton_factory.start_stream_system_listen(pseudonic.st_listen_pathname);
            tasklet.ms_wait(1);
            print(@"started stream_system_listen $(pseudonic.st_listen_pathname).\n");
        }

        // first id
        NodeID first_id = fake_random_nodeid(pid, 0);
        print(@"INFO: nodeid for $(pid)_0 is $(first_id.id).\n");
        var first_identity_data = create_local_identity(first_id);

        // public Naddr(int[] pos, int[] sizes)
        Naddr my_naddr = new Naddr({0,0,0}, {2,2,2}); // TODO
        // public Fingerprint(int[] elderships, int64 id=-1)
        Fingerprint my_fp = new Fingerprint({0,0,0}); // TODO

        // First qspn manager
        QspnManager qspn_mgr = new QspnManager.create_net(
            my_naddr,
            my_fp,
            new QspnStubFactory(first_identity_data));
        first_identity_data.qspn_mgr = qspn_mgr;  // weak ref

        // immediately after creation, connect to signals.
        qspn_mgr.arc_removed.connect(first_identity_data.arc_removed);
        qspn_mgr.changed_fp.connect(first_identity_data.changed_fp);
        qspn_mgr.changed_nodes_inside.connect(first_identity_data.changed_nodes_inside);
        qspn_mgr.destination_added.connect(first_identity_data.destination_added);
        qspn_mgr.destination_removed.connect(first_identity_data.destination_removed);
        qspn_mgr.gnode_splitted.connect(first_identity_data.gnode_splitted);
        qspn_mgr.path_added.connect(first_identity_data.path_added);
        qspn_mgr.path_changed.connect(first_identity_data.path_changed);
        qspn_mgr.path_removed.connect(first_identity_data.path_removed);
        qspn_mgr.presence_notified.connect(first_identity_data.presence_notified);
        qspn_mgr.qspn_bootstrap_complete.connect(first_identity_data.qspn_bootstrap_complete);
        qspn_mgr.remove_identity.connect(first_identity_data.remove_identity);

        // First identity is immediately bootstrapped.
        while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(1);

        foreach (string task in tasks)
        {
/*
            if      (schedule_task_addarc(task)) {}
            else if (schedule_task_prepare_add_identity(task)) {}
            else if (schedule_task_add_identity(task)) {}
            else if (schedule_task_addtag(task)) {}
            else if (schedule_task_removearc(task)) {}
            else if (schedule_task_remove_identity(task)) {}
            else if (schedule_task_addinterface(task)) {}
            else if (schedule_task_removeinterface(task)) {}
            else error(@"unknown task $(task)");
*/
            error(@"unknown task $(task)");
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

        PthTaskletImplementer.kill();

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
        return @"fe:aa:aa:$(_rand.int_range(10, 99)):$(_rand.int_range(10, 99)):$(_rand.int_range(10, 99))";
    }

    string fake_random_linklocal(string mac)
    {
        uint32 seed_prn = (uint32)mac.hash();
        Rand _rand = new Rand.with_seed(seed_prn);
        return @"169.254.$(_rand.int_range(0, 255)).$(_rand.int_range(0, 255))";
    }

    NodeID fake_random_nodeid(int pid, int node_index)
    {
        string _seed = @"$(pid)_$(node_index)";
        uint32 seed_prn = (uint32)_seed.hash();
        Rand _rand = new Rand.with_seed(seed_prn);
        return new NodeID((int)(_rand.int_range(1, 99999)));
    }

    class IdentityData : Object
    {
        public IdentityData(NodeID nodeid)
        {
            this.nodeid = nodeid;
            identity_arcs = new ArrayList<IdentityArc>();
            connectivity_from_level = 0;
            connectivity_to_level = 0;
            copy_of_identity = null;
            qspn_mgr = null;
        }

        public NodeID nodeid;
        public Naddr my_naddr;
        public Fingerprint my_fp;
        public int connectivity_from_level;
        public int connectivity_to_level;
        public IdentityData? copy_of_identity;

        public weak QspnManager qspn_mgr;

        public ArrayList<IdentityArc> identity_arcs;

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
        public string id_peer_mac;
        public string id_peer_linklocal;

        public QspnArc? qspn_arc;
        public int64? network_id;
        public string? prev_peer_mac;
        public string? prev_peer_linklocal;

        public IdentityArc(IdentityData identity_data, PseudoArc arc, NodeID peer_nodeid, string id_peer_mac, string id_peer_linklocal)
        {
            this.identity_data = identity_data;
            this.arc = arc;
            this.peer_nodeid = peer_nodeid;
            this.id_peer_mac = id_peer_mac;
            this.id_peer_linklocal = id_peer_linklocal;

            qspn_arc = null;
            network_id = null;
            prev_peer_mac = null;
            prev_peer_linklocal = null;
        }
    }
}