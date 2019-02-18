using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_enter_net(string task)
    {
        if (task.has_prefix("enter_net,"))
        {
            string remain = task.substring("enter_net,".length);
            string[] args = remain.split(",");
            if (args.length != 7) error("bad args num in task 'enter_net'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'enter_net'");
            int64 my_old_id;
            if (! int64.try_parse(args[1], out my_old_id)) error("bad args my_old_id in task 'enter_net'");
            int64 my_new_id;
            if (! int64.try_parse(args[2], out my_new_id)) error("bad args my_new_id in task 'enter_net'");
            int64 guest_level;
            if (! int64.try_parse(args[3], out guest_level)) error("bad args guest_level in task 'enter_net'");
            ArrayList<int> in_g_naddr = new ArrayList<int>();
            int host_level;
            {
                string[] parts = args[4].split(":");
                host_level = levels - (parts.length - 1);
                if (host_level <= guest_level) error("bad parts num in in_g_naddr in task 'enter_net'");
                for (int i = 0; i < parts.length; i++)
                {
                    int64 element;
                    if (! int64.try_parse(parts[i], out element)) error("bad parts element in in_g_naddr in task 'enter_net'");
                    in_g_naddr.add((int)element);
                }
            }
            ArrayList<int> in_g_elderships = new ArrayList<int>();
            {
                string[] parts = args[5].split(":");
                if (host_level != levels - (parts.length - 1)) error("bad parts num in in_g_elderships in task 'enter_net'");
                for (int i = 0; i < parts.length; i++)
                {
                    int64 element;
                    if (! int64.try_parse(parts[i], out element)) error("bad parts element in in_g_elderships in task 'enter_net'");
                    in_g_elderships.add((int)element);
                }
            }
            ArrayList<int> external_arc_list_arc_num = new ArrayList<int>();
            ArrayList<int> external_arc_list_peer_id_num = new ArrayList<int>();
            {
                string[] parts = args[6].split("_");
                for (int i = 0; i < parts.length; i++)
                {
                    string[] parts2 = parts[i].split("+");
                    if (parts2.length != 2) error("bad parts element in external_arc_list in task 'enter_net'");
                    {
                        int64 element;
                        if (! int64.try_parse(parts2[0], out element)) error("bad parts element in external_arc_list in task 'enter_net'");
                        external_arc_list_arc_num.add((int)element);
                    }
                    {
                        int64 element;
                        if (! int64.try_parse(parts2[1], out element)) error("bad parts element in external_arc_list in task 'enter_net'");
                        external_arc_list_peer_id_num.add((int)element);
                    }
                }
            }
            string addrnext = "";
            string addr = "";
            foreach (int pos in in_g_naddr)
            {
                addr = @"$(addr)$(addrnext)$(pos)";
                addrnext = ":";
            }
            print(@"INFO: in $(ms_wait) msec my g-node of level $(guest_level) will enter new network as [$(addr)].\n");
            EnterNetTasklet s = new EnterNetTasklet(
                (int)(ms_wait),
                (int)my_old_id,
                (int)my_new_id,
                (int)guest_level,
                host_level,
                in_g_naddr,
                in_g_elderships,
                external_arc_list_arc_num,
                external_arc_list_peer_id_num);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class IdentityArcPair : Object
    {
        public IdentityArcPair(IdentityArc old_id_arc, IdentityArc new_id_arc)
        {
            this.old_id_arc = old_id_arc;
            this.new_id_arc = new_id_arc;
        }
        public IdentityArc old_id_arc {get; private set;}
        public IdentityArc new_id_arc {get; private set;}
    }

    class EnterNetTasklet : Object, ITaskletSpawnable
    {
        public EnterNetTasklet(
            int ms_wait,
            int my_old_id,
            int my_new_id,
            int guest_level,
            int host_level,
            ArrayList<int> in_g_naddr,
            ArrayList<int> in_g_elderships,
            ArrayList<int> external_arc_list_arc_num,
            ArrayList<int> external_arc_list_peer_id_num)
        {
            this.ms_wait = ms_wait;
            this.my_old_id = my_old_id;
            this.my_new_id = my_new_id;
            this.guest_level = guest_level;
            this.host_level = host_level;
            this.in_g_naddr = in_g_naddr;
            this.in_g_elderships = in_g_elderships;
            this.external_arc_list_arc_num = external_arc_list_arc_num;
            this.external_arc_list_peer_id_num = external_arc_list_peer_id_num;
        }
        private int ms_wait;
        private int my_old_id;
        private int my_new_id;
        private int guest_level;
        private int host_level;
        private ArrayList<int> in_g_naddr;
        private ArrayList<int> in_g_elderships;
        private ArrayList<int> external_arc_list_arc_num;
        private ArrayList<int> external_arc_list_peer_id_num;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find old_id
            NodeID old_nodeid = fake_random_nodeid(pid, my_old_id);
            IdentityData old_identity_data = find_local_identity(old_nodeid);
            assert(old_identity_data != null);

            // find new_id
            NodeID new_nodeid = fake_random_nodeid(pid, my_new_id);
            IdentityData new_identity_data = find_local_identity(new_nodeid);
            assert(new_identity_data != null);

            ArrayList<int> naddr = new ArrayList<int>();
            for (int i = 0; i < host_level-1; i++) naddr.add(old_identity_data.my_naddr.i_qspn_get_pos(i));
            for (int i = host_level-1; i < levels; i++) naddr.add(in_g_naddr[i-(host_level-1)]);
            new_identity_data.my_naddr = new Naddr(naddr.to_array(), gsizes.to_array());
            ArrayList<int> elderships = new ArrayList<int>();
            for (int i = 0; i < guest_level; i++) elderships.add(old_identity_data.my_fp.elderships[i]);
            for (int i = guest_level; i < host_level-1; i++)  elderships.add(0);
            for (int i = host_level-1; i < levels; i++) elderships.add(in_g_elderships[i-(host_level-1)]);
            new_identity_data.my_fp = new Fingerprint(elderships.to_array(), old_identity_data.my_fp.id);

            // Another qspn manager
            ArrayList<IQspnArc> internal_arc_set = new ArrayList<IQspnArc>();
            ArrayList<IQspnArc> internal_arc_prev_arc_set = new ArrayList<IQspnArc>();
            ArrayList<IQspnNaddr> internal_arc_peer_naddr_set = new ArrayList<IQspnNaddr>();
            if (guest_level > 0)
            {
                // a g-node of level 0 has no internal arcs.

                // Associate id-arcs of old and new identity.
                Gee.List<IdentityArcPair> both_arcpairs = new ArrayList<IdentityArcPair>();
                foreach (IdentityArc w0 in old_identity_data.identity_arcs)
                {
                    // find appropriate w1
                    foreach (IdentityArc w1 in new_identity_data.identity_arcs)
                    {
                        if (w1.arc != w0.arc) continue;
                        both_arcpairs.add(new IdentityArcPair(w0, w1));
                        break;
                    }
                }

                foreach (IdentityArcPair arcpair in both_arcpairs)
                {
                    IdentityArc w0 = arcpair.old_id_arc;
                    IdentityArc w1 = arcpair.new_id_arc;

                    w1.qspn_arc = new QspnArc(w1);

                    // Handle rare (but possible) situation where right in the middle of a duplication
                    //  some of the qspn-arcs of the old identity are removed for bad-link.
                    if (w0.qspn_arc != null)
                    {
                        IQspnNaddr? _w0_peer_naddr = old_identity_data.qspn_mgr.get_naddr_for_arc(w0.qspn_arc);
                        if (_w0_peer_naddr != null)
                        {
                            Naddr w0_peer_naddr = (Naddr)_w0_peer_naddr;
                            ArrayList<int> _w1_peer_naddr = new ArrayList<int>();
                            _w1_peer_naddr.add_all(w0_peer_naddr.pos.slice(0, host_level-1));
                            _w1_peer_naddr.add_all(new_identity_data.my_naddr.pos.slice(host_level-1, levels));
                            Naddr w1_peer_naddr = new Naddr(_w1_peer_naddr.to_array(), gsizes.to_array());

                            // Now add: the 3 ArrayList should have same size at the end.
                            internal_arc_set.add(w1.qspn_arc);
                            internal_arc_peer_naddr_set.add(w1_peer_naddr);
                            internal_arc_prev_arc_set.add(w0.qspn_arc);
                        }
                    }
                }
            }
            ArrayList<IQspnArc> external_arc_set = new ArrayList<IQspnArc>();
            for (int i = 0; i < external_arc_list_arc_num.size; i++)
            {
                // Pseudo arc
                PseudoArc pseudoarc = arc_list[external_arc_list_arc_num[i]];
                // peer nodeid
                NodeID peer_nodeid = fake_random_nodeid(pseudoarc.peer_pid, external_arc_list_peer_id_num[i]);

                IdentityArc? ia = new_identity_data.identity_arcs_find(pseudoarc, peer_nodeid);
                if (ia == null) error(@"not found IdentityArc for $(external_arc_list_arc_num[i])+$(external_arc_list_peer_id_num[i])");
                ia.qspn_arc = new QspnArc(ia);
                external_arc_set.add(ia.qspn_arc);
            }

            new_identity_data.qspn_mgr = new QspnManager.enter_net(
                internal_arc_set,
                internal_arc_prev_arc_set,
                internal_arc_peer_naddr_set,
                external_arc_set,
                new_identity_data.my_naddr,
                new_identity_data.my_fp,
                (_f) => {
                    assert(guest_level > 0); // a g-node of level 0 has no internal arcs.
                    Fingerprint f = (Fingerprint)_f;
                    for (int l = guest_level; l < levels; l++)
                    {
                        // f.elderships has n items, where f.level + n = levels.
                        // f.elderships[0] refers to l=f.level.
                        // f.elderships[n-1] refers to l=f.level+n-1=levels-1.
                        // so, f.elderships[i] refers to l=f.level+i.
                        int i = l - f.level;
                        if (i >= 0)
                            f.elderships[i] = new_identity_data.my_fp.elderships[l];
                        // f.elderships_seed doesn't need to change.
                    }
                    return f;
                    // Returning the same instance is ok, because the delegate is alway
                    // called like "x = update_internal_fingerprints(x)"
                }, // update_internal_fingerprints,
                new QspnStubFactory(new_identity_data.local_identity_index),
                guest_level,
                host_level,
                old_identity_data.qspn_mgr);
            string addr = ""; string addrnext = "";
            for (int i = 0; i < levels; i++)
            {
                addr = @"$(addr)$(addrnext)$(new_identity_data.my_naddr.pos[i])";
                addrnext = ":";
            }
            string s_elderships = ""; string eldershipsnext = "";
            for (int i = 0; i < levels; i++)
            {
                s_elderships = @"$(s_elderships)$(eldershipsnext)$(new_identity_data.my_fp.elderships[i])";
                eldershipsnext = ":";
            }
            tester_events.add(@"Qspn:$(new_identity_data.local_identity_index):enter_net:$(addr),$(s_elderships)");
            // immediately after creation, connect to signals.
            new_identity_data.qspn_mgr.arc_removed.connect(new_identity_data.arc_removed);
            new_identity_data.qspn_mgr.changed_fp.connect(new_identity_data.changed_fp);
            new_identity_data.qspn_mgr.changed_nodes_inside.connect(new_identity_data.changed_nodes_inside);
            new_identity_data.qspn_mgr.destination_added.connect(new_identity_data.destination_added);
            new_identity_data.qspn_mgr.destination_removed.connect(new_identity_data.destination_removed);
            new_identity_data.qspn_mgr.gnode_splitted.connect(new_identity_data.gnode_splitted);
            new_identity_data.qspn_mgr.path_added.connect(new_identity_data.path_added);
            new_identity_data.qspn_mgr.path_changed.connect(new_identity_data.path_changed);
            new_identity_data.qspn_mgr.path_removed.connect(new_identity_data.path_removed);
            new_identity_data.qspn_mgr.presence_notified.connect(new_identity_data.presence_notified);
            new_identity_data.qspn_mgr.qspn_bootstrap_complete.connect(new_identity_data.qspn_bootstrap_complete);
            new_identity_data.qspn_mgr.remove_identity.connect(new_identity_data.remove_identity);

            print(@"INFO: New identity $(new_nodeid.id) entered with address $(json_string_object(new_identity_data.my_naddr))");
            print(@" and fp $(json_string_object(new_identity_data.my_fp)).\n");

            new_identity_data = null;

            // Since this is a enter_net (not migrate) there is no need to call the method `make_connectivity`
            // of old_identity_data.qspn_mgr.
            // The instance old_identity_data.qspn_mgr should be (soon) dismissed (calling the method `destroy`) and
            // the instance old_identity_data should be removed from the set local_identities.
            // However, in the meantime, we must assure that this is not confused with the current main_id of this system.
            // Thus old_identity_data becomes of connectivity from guest_level+1 to levels
            old_identity_data.connectivity_from_level = guest_level + 1;
            old_identity_data.connectivity_to_level = levels;

            // wait to safely remove old_identity_data
            old_identity_data = null;
            tasklet.ms_wait(2000);
            old_identity_data = find_local_identity(old_nodeid);
            assert(old_identity_data != null);

            // remove old identity.
            old_identity_data.qspn_mgr.destroy();
            old_identity_data.qspn_mgr.arc_removed.disconnect(old_identity_data.arc_removed);
            old_identity_data.qspn_mgr.changed_fp.disconnect(old_identity_data.changed_fp);
            old_identity_data.qspn_mgr.changed_nodes_inside.disconnect(old_identity_data.changed_nodes_inside);
            old_identity_data.qspn_mgr.destination_added.disconnect(old_identity_data.destination_added);
            old_identity_data.qspn_mgr.destination_removed.disconnect(old_identity_data.destination_removed);
            old_identity_data.qspn_mgr.gnode_splitted.disconnect(old_identity_data.gnode_splitted);
            old_identity_data.qspn_mgr.path_added.disconnect(old_identity_data.path_added);
            old_identity_data.qspn_mgr.path_changed.disconnect(old_identity_data.path_changed);
            old_identity_data.qspn_mgr.path_removed.disconnect(old_identity_data.path_removed);
            old_identity_data.qspn_mgr.presence_notified.disconnect(old_identity_data.presence_notified);
            old_identity_data.qspn_mgr.qspn_bootstrap_complete.disconnect(old_identity_data.qspn_bootstrap_complete);
            old_identity_data.qspn_mgr.remove_identity.disconnect(old_identity_data.remove_identity);
            old_identity_data.qspn_mgr.stop_operations();

            remove_local_identity(old_identity_data.nodeid);

            return null;
        }
    }

    bool schedule_task_migrate(string task)
    {
        if (task.has_prefix("migrate,"))
        {
            error("not implemented yet");
        }
        else return false;
    }

    bool schedule_task_add_qspnarc(string task)
    {
        if (task.has_prefix("add_qspnarc,"))
        {
            string remain = task.substring("add_qspnarc,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'add_qspnarc'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'add_qspnarc'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'add_qspnarc'");

            int arc_num;
            int peer_id;
            string[] parts2 = args[2].split("+");
            if (parts2.length != 2) error("bad parts element in arc_num+peer_id in task 'add_qspnarc'");
            {
                int64 element;
                if (! int64.try_parse(parts2[0], out element)) error("bad parts element in arc_num+peer_id in task 'add_qspnarc'");
                arc_num = (int)element;
            }
            {
                int64 element;
                if (! int64.try_parse(parts2[1], out element)) error("bad parts element in arc_num+peer_id in task 'add_qspnarc'");
                peer_id = (int)element;
            }

            print(@"INFO: in $(ms_wait) ms will add qspn-arc '$(args[2])' to my identity #$(my_id).\n");
            AddQspnArcTasklet s = new AddQspnArcTasklet(
                (int)(ms_wait),
                (int)my_id,
                arc_num,
                peer_id);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class AddQspnArcTasklet : Object, ITaskletSpawnable
    {
        public AddQspnArcTasklet(
            int ms_wait,
            int my_id,
            int arc_num,
            int peer_id)
        {
            this.ms_wait = ms_wait;
            this.my_id = my_id;
            this.arc_num = arc_num;
            this.peer_id = peer_id;
        }
        private int ms_wait;
        private int my_id;
        private int arc_num;
        private int peer_id;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find my_id
            NodeID my_nodeid = fake_random_nodeid(pid, my_id);
            var my_identity_data = find_local_identity(my_nodeid);
            assert(my_identity_data != null);

            // Pseudo arc
            PseudoArc pseudoarc = arc_list[arc_num];
            // peer nodeid
            NodeID peer_nodeid = fake_random_nodeid(pseudoarc.peer_pid, peer_id);

            IdentityArc? ia = my_identity_data.identity_arcs_find(pseudoarc, peer_nodeid);
            if (ia == null) error(@"not found IdentityArc for $(arc_num)+$(peer_id)");
            ia.qspn_arc = new QspnArc(ia);
            my_identity_data.qspn_mgr.arc_add(ia.qspn_arc);

            return null;
        }
    }

    bool schedule_task_changecost_arc(string task)
    {
        if (task.has_prefix("changecost_arc,"))
        {
            string remain = task.substring("changecost_arc,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'changecost_arc'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'changecost_arc'");
            int64 arc_num;
            if (! int64.try_parse(args[1], out arc_num)) error("bad args arc_num in task 'changecost_arc'");
            int64 usec_rtt;
            if (! int64.try_parse(args[2], out usec_rtt)) error("bad args usec_rtt in task 'changecost_arc'");
            print(@"INFO: in $(ms_wait) ms will change base cost of arc #'$(arc_num)' to RTT = $(usec_rtt) usec.\n");
            ChangeCostArcTasklet s = new ChangeCostArcTasklet(
                (int)ms_wait,
                (int)arc_num,
                (int)usec_rtt);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class ChangeCostArcTasklet : Object, ITaskletSpawnable
    {
        public ChangeCostArcTasklet(
            int ms_wait,
            int arc_num,
            int usec_rtt)
        {
            this.ms_wait = ms_wait;
            this.arc_num = arc_num;
            this.usec_rtt = usec_rtt;
        }
        private int ms_wait;
        private int arc_num;
        private int usec_rtt;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // Pseudo arc
            PseudoArc arc = arc_list[arc_num];
            arc.cost = usec_rtt;

            foreach (IdentityData my_identity_data in local_identities.values)
                if (my_identity_data.qspn_mgr != null)
            {
                foreach (IdentityArc ia in my_identity_data.identity_arcs)
                    if (ia.arc == arc)
                {
                    ia.qspn_arc = new QspnArc(ia);
                    my_identity_data.qspn_mgr.arc_is_changed(ia.qspn_arc);
                }
            }

            return null;
        }
    }

    bool schedule_task_remove_qspnarc(string task)
    {
        if (task.has_prefix("remove_qspnarc,"))
        {
            string remain = task.substring("remove_qspnarc,".length);
            string[] args = remain.split(",");
            if (args.length != 4) error("bad args num in task 'remove_qspnarc'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'remove_qspnarc'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'remove_qspnarc'");
            int64 arc_num;
            if (! int64.try_parse(args[2], out arc_num)) error("bad args arc_num in task 'remove_qspnarc'");
            int64 peer_id;
            if (! int64.try_parse(args[3], out peer_id)) error("bad args peer_id in task 'remove_qspnarc'");
            print(@"INFO: in $(ms_wait) ms will remove qspn-arc '$(arc_num)+$(peer_id)' to my identity #$(my_id).\n");
            RemoveQspnArcTasklet s = new RemoveQspnArcTasklet(
                (int)ms_wait,
                (int)my_id,
                (int)arc_num,
                (int)peer_id);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class RemoveQspnArcTasklet : Object, ITaskletSpawnable
    {
        public RemoveQspnArcTasklet(
            int ms_wait,
            int my_id,
            int arc_num,
            int peer_id)
        {
            this.ms_wait = ms_wait;
            this.my_id = my_id;
            this.arc_num = arc_num;
            this.peer_id = peer_id;
        }
        private int ms_wait;
        private int my_id;
        private int arc_num;
        private int peer_id;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // Pseudo arc
            PseudoArc pseudoarc = arc_list[arc_num];
            // peer nodeid
            NodeID peer_nodeid = fake_random_nodeid(pseudoarc.peer_pid, peer_id);

            // find my_id
            NodeID my_nodeid = fake_random_nodeid(pid, my_id);
            IdentityData my_identity_data = find_local_identity(my_nodeid);
            assert(my_identity_data != null);

            IdentityArc? ia = my_identity_data.identity_arcs_find(pseudoarc, peer_nodeid);
            if (ia == null) error(@"not found IdentityArc for $(arc_num)+$(peer_id)");
            if (ia.qspn_arc != null)
            {
                my_identity_data.qspn_mgr.arc_remove(ia.qspn_arc);
                ia.qspn_arc = null;
            }

            return null;
        }
    }

    bool schedule_task_exit_network(string task)
    {
        if (task.has_prefix("exit_network,"))
        {
            string remain = task.substring("exit_network,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'exit_network'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'exit_network'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'exit_network'");
            int64 lvl;
            if (! int64.try_parse(args[2], out lvl)) error("bad args lvl in task 'exit_network'");
            print(@"INFO: in $(ms_wait) ms my id $(my_id) will exit network (for split) with my g-node of level $(lvl).\n");
            ExitNetworkTasklet s = new ExitNetworkTasklet(
                (int)ms_wait,
                (int)my_id,
                (int)lvl);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class ExitNetworkTasklet : Object, ITaskletSpawnable
    {
        public ExitNetworkTasklet(
            int ms_wait,
            int my_id,
            int lvl)
        {
            this.ms_wait = ms_wait;
            this.my_id = my_id;
            this.lvl = lvl;
        }
        private int ms_wait;
        private int my_id;
        private int lvl;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find my_id
            NodeID my_nodeid = fake_random_nodeid(pid, my_id);
            IdentityData my_identity_data = find_local_identity(my_nodeid);
            assert(my_identity_data != null);

            my_identity_data.qspn_mgr.exit_network(lvl);

            return null;
        }
    }
}