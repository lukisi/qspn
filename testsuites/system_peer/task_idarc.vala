using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_add_idarc(string task)
    {
        if (task.has_prefix("add_idarc,"))
        {
            string remain = task.substring("add_idarc,".length);
            string[] args = remain.split(",");
            if (args.length != 4) error("bad args num in task 'add_idarc'");
            int64 s_wait;
            if (! int64.try_parse(args[0], out s_wait)) error("bad args s_wait in task 'add_idarc'");
            int64 arc_index;
            if (! int64.try_parse(args[0], out arc_index)) error("bad args arc_index in task 'add_idarc'");
            int64 my_id_index;
            if (! int64.try_parse(args[0], out my_id_index)) error("bad args my_id_index in task 'add_idarc'");
            int64 peer_id_index;
            if (! int64.try_parse(args[0], out peer_id_index)) error("bad args peer_id_index in task 'add_idarc'");
            print(@"INFO: in $(s_wait) seconds will add id_arc on arc #$(arc_index) from my id #$(my_id_index) to peer id #$(peer_id_index).\n");
            AddIdArcTasklet s = new AddIdArcTasklet((int)(s_wait*1000), (int)arc_index, (int)my_id_index, (int)peer_id_index);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class AddIdArcTasklet : Object, ITaskletSpawnable
    {
        public AddIdArcTasklet(int ms_wait, int arc_index, int my_id_index, int peer_id_index)
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

/*
            // id #my_id_index
            NodeID my_nodeid = fake_random_nodeid(pid, my_id_index);
            IdentityData? identity_data = find_local_identity(nodeid_index);
            assert(identity_data != null);
            PseudoArc pseudoarc = arc_list[arc_index];
            NodeID peer_nodeid = fake_random_nodeid(pseudoarc.peer_pid, peer_id_index);
            string id_peer_mac = fake_random_mac(

            IdentityArc ia = new IdentityArc(identity_data, pseudoarc, peer_nodeid, string id_peer_mac, string id_peer_linklocal);
            identity_data.identity_arcs.add(ia);
            IQspnArc arc = new QspnArc(NodeID sourceid, NodeID destid, IdentityArc ia);
            identity_data.qspn_mgr.arc_add(arc);
*/

            return null;
        }
    }

    bool schedule_task_change_idarc(string task)
    {
        if (task.has_prefix("change_idarc,"))
        {
            error("not implemented yet");
        }
        else return false;
    }

    bool schedule_task_remove_idarc(string task)
    {
        if (task.has_prefix("remove_idarc,"))
        {
            error("not implemented yet");
        }
        else return false;
    }
}