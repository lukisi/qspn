using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_add_identity(string task)
    {
        if (task.has_prefix("add_identity,"))
        {
            string remain = task.substring("add_identity,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'add_identity'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'add_identity'");
            int64 my_old_id;
            if (! int64.try_parse(args[1], out my_old_id)) error("bad args my_old_id in task 'add_identity'");

            ArrayList<int> arc_list_arc_num = new ArrayList<int>();
            ArrayList<int> arc_list_peer_id_num = new ArrayList<int>();
            {
                string[] parts = args[2].split(";");
                for (int i = 0; i < parts.length; i++)
                {
                    string[] parts2 = parts[i].split("+");
                    if (parts2.length != 2) error("bad parts element in arc_list in task 'add_identity'");
                    {
                        int64 element;
                        if (! int64.try_parse(parts2[0], out element)) error("bad parts element in arc_list in task 'add_identity'");
                        arc_list_arc_num.add((int)element);
                    }
                    {
                        int64 element;
                        if (! int64.try_parse(parts2[1], out element)) error("bad parts element in arc_list in task 'add_identity'");
                        arc_list_peer_id_num.add((int)element);
                    }
                }
            }

            print(@"INFO: in $(ms_wait) ms will add identity from parent identity #$(my_old_id) with arcs '$(args[2])'.\n");
            AddIdentityTasklet s = new AddIdentityTasklet(
                (int)(ms_wait),
                (int)my_old_id,
                arc_list_arc_num,
                arc_list_peer_id_num);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class AddIdentityTasklet : Object, ITaskletSpawnable
    {
        public AddIdentityTasklet(
            int ms_wait,
            int my_old_id,
            ArrayList<int> arc_list_arc_num,
            ArrayList<int> arc_list_peer_id_num)
        {
            this.ms_wait = ms_wait;
            this.my_old_id = my_old_id;
            this.arc_list_arc_num = arc_list_arc_num;
            this.arc_list_peer_id_num = arc_list_peer_id_num;
        }
        private int ms_wait;
        private int my_old_id;
        private ArrayList<int> arc_list_arc_num;
        private ArrayList<int> arc_list_peer_id_num;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // another id
            NodeID another_nodeid = fake_random_nodeid(pid, next_local_identity_index);
            string another_identity_name = @"$(pid)_$(next_local_identity_index)";
            print(@"INFO: nodeid for $(another_identity_name) is $(another_nodeid.id).\n");
            var another_identity_data = create_local_identity(another_nodeid);
            next_local_identity_index++;

            // find old_id
            NodeID old_nodeid = fake_random_nodeid(pid, my_old_id);
            var old_identity_data = find_local_identity(old_nodeid);
            assert(old_identity_data != null);
            another_identity_data.connectivity_from_level = old_identity_data.connectivity_from_level;
            another_identity_data.connectivity_to_level = old_identity_data.connectivity_to_level;
            another_identity_data.copy_of_identity = old_identity_data;

            for (int i = 0; i < arc_list_arc_num.size; i++)
            {
                // Pseudo arc
                PseudoArc pseudoarc = arc_list[arc_list_arc_num[i]];
                // peer nodeid
                NodeID peer_nodeid = fake_random_nodeid(pseudoarc.peer_pid, arc_list_peer_id_num[i]);

                IdentityArc ia = new IdentityArc(another_identity_data, pseudoarc, peer_nodeid);
                another_identity_data.identity_arcs.add(ia);
            }

            return null;
        }
    }

    bool schedule_task_add_identityarc(string task)
    {
        if (task.has_prefix("add_identityarc,"))
        {
            string remain = task.substring("add_identityarc,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'add_identityarc'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'add_identityarc'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'add_identityarc'");

            int arc_num;
            int peer_id;
            string[] parts2 = args[2].split("+");
            if (parts2.length != 2) error("bad parts element in arc_num+peer_id in task 'add_identityarc'");
            {
                int64 element;
                if (! int64.try_parse(parts2[0], out element)) error("bad parts element in arc_num+peer_id in task 'add_identityarc'");
                arc_num = (int)element;
            }
            {
                int64 element;
                if (! int64.try_parse(parts2[1], out element)) error("bad parts element in arc_num+peer_id in task 'add_identityarc'");
                peer_id = (int)element;
            }

            print(@"INFO: in $(ms_wait) ms will add identityarc '$(args[2])' to my identity #$(my_id).\n");
            AddIdentityArcTasklet s = new AddIdentityArcTasklet(
                (int)(ms_wait),
                (int)my_id,
                arc_num,
                peer_id);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class AddIdentityArcTasklet : Object, ITaskletSpawnable
    {
        public AddIdentityArcTasklet(
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

            IdentityArc ia = new IdentityArc(my_identity_data, pseudoarc, peer_nodeid);
            my_identity_data.identity_arcs.add(ia);

            return null;
        }
    }

    bool old_schedule_task_add_idarc(string task)
    {
        if (task.has_prefix("add_idarc,"))
        {
            string remain = task.substring("add_idarc,".length);
            string[] args = remain.split(",");
            if (args.length != 4) error("bad args num in task 'add_idarc'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'add_idarc'");
            int64 arc_index;
            if (! int64.try_parse(args[1], out arc_index)) error("bad args arc_index in task 'add_idarc'");
            int64 my_id_index;
            if (! int64.try_parse(args[2], out my_id_index)) error("bad args my_id_index in task 'add_idarc'");
            int64 peer_id_index;
            if (! int64.try_parse(args[3], out peer_id_index)) error("bad args peer_id_index in task 'add_idarc'");
            print(@"INFO: in $(ms_wait) ms will add id_arc on arc #$(arc_index) from my id #$(my_id_index) to peer id #$(peer_id_index).\n");
            OldAddIdArcTasklet s = new OldAddIdArcTasklet((int)(ms_wait), (int)arc_index, (int)my_id_index, (int)peer_id_index);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class OldAddIdArcTasklet : Object, ITaskletSpawnable
    {
        public OldAddIdArcTasklet(int ms_wait, int arc_index, int my_id_index, int peer_id_index)
        {
            this.ms_wait = ms_wait;
            this.arc_index = arc_index;
            this.my_id_index = my_id_index;
            this.peer_id_index = peer_id_index;
        }
        private int ms_wait;
        private int arc_index;
        private int my_id_index;
        private int peer_id_index;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // arc #arc_index
            PseudoArc pseudoarc = arc_list[arc_index];
            // id #my_id_index
            NodeID my_nodeid = fake_random_nodeid(pid, my_id_index);
            IdentityData? identity_data = find_local_identity(my_nodeid);
            assert(identity_data != null);
            // peer id #peer_id_index
            NodeID peer_nodeid = fake_random_nodeid(pseudoarc.peer_pid, peer_id_index);

            IdentityArc ia = new IdentityArc(identity_data, pseudoarc, peer_nodeid);
            identity_data.identity_arcs.add(ia);
            IQspnArc arc = new QspnArc(ia);
            identity_data.qspn_mgr.arc_add(arc);

            return null;
        }
    }

    bool old_schedule_task_change_idarc(string task)
    {
        if (task.has_prefix("change_idarc,"))
        {
            error("not implemented yet");
        }
        else return false;
    }

    bool old_schedule_task_remove_idarc(string task)
    {
        if (task.has_prefix("remove_idarc,"))
        {
            error("not implemented yet");
        }
        else return false;
    }
}