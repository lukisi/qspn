using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_check_signal_gnode_split(string task)
    {
        if (task.has_prefix("check_signal_gnode_split,"))
        {
            string remain = task.substring("check_signal_gnode_split,".length);
            string[] args = remain.split(",");
            if (args.length != 3) error("bad args num in task 'check_signal_gnode_split'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'check_signal_gnode_split'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'check_signal_gnode_split'");
            bool expected = args[2] != "0";
            string part = expected ? "DID" : "DID NOT";
            print(@"INFO: in $(ms_wait) ms will check that my identity #$(my_id) $(part) signal a gnode_splitted.\n");
            CheckSignalSplitTasklet s = new CheckSignalSplitTasklet(
                (int)ms_wait,
                (int)my_id,
                expected);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class CheckSignalSplitTasklet : Object, ITaskletSpawnable
    {
        public CheckSignalSplitTasklet(
            int ms_wait,
            int my_id,
            bool expected)
        {
            this.ms_wait = ms_wait;
            this.my_id = my_id;
            this.expected = expected;
        }
        private int ms_wait;
        private int my_id;
        private bool expected;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // find my_id
            NodeID my_nodeid = fake_random_nodeid(pid, my_id);
            var my_identity_data = find_local_identity(my_nodeid);
            assert(my_identity_data != null);
            // make sure bootstrap is complete
            if (! my_identity_data.qspn_mgr.is_bootstrap_complete())
            {
                error(@"Check split failed: not boostrap complete.");
            }

            string needle = @"Qspn:$(my_id):Signal:gnode_splitted(";
            bool found = false;
            foreach (string event in tester_events)
                if (needle in event)
                found = true;
            if (found != expected)
            {
                string part = expected ? "DID" : "DID NOT";
                error(@"Check split failed: was expected that my identity #$(my_id) $(part) signal a gnode_splitted.");
            }

            return null;
        }
    }
}