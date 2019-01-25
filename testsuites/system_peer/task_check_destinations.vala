using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_check_destnum(string task)
    {
        if (task.has_prefix("check_destnum,"))
        {
            string remain = task.substring("check_destnum,".length);
            string[] args = remain.split(",");
            if (args.length != 4) error("bad args num in task 'check_destnum'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'check_destnum'");
            int64 my_id;
            if (! int64.try_parse(args[1], out my_id)) error("bad args my_id in task 'check_destnum'");
            int64 expected;
            if (! int64.try_parse(args[2], out expected)) error("bad args expected in task 'check_destnum'");
            string label = args[3];
            print(@"INFO: in $(ms_wait) ms will check destinations known to my identity #$(my_id) are $(expected).\n");
            CheckDestNumTasklet s = new CheckDestNumTasklet(
                (int)ms_wait,
                (int)my_id,
                (int)expected,
                label);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class CheckDestNumTasklet : Object, ITaskletSpawnable
    {
        public CheckDestNumTasklet(
            int ms_wait,
            int my_id,
            int expected,
            string label)
        {
            this.ms_wait = ms_wait;
            this.my_id = my_id;
            this.expected = expected;
            this.label = label;
        }
        private int ms_wait;
        private int my_id;
        private int expected;
        private string label;

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
                warning(@"Check '$(label)' failed: not boostrap complete.");
                failed_checks_labels.add(label);
            }
            // count known destinations
            int count = 0;
            try {
                for (int l = 0; l < levels; l++)
                    count += my_identity_data.qspn_mgr.get_known_destinations(l).size;
            } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
            if (count != expected)
            {
                warning(@"Check '$(label)' failed: known destinations are $(count), expected were $(expected).");
                failed_checks_labels.add(label);
            }
            print(@"Tick: my identity #$(my_id) has $(count) known destinations.\n");

            return null;
        }
    }
}