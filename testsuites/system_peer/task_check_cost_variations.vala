using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_check_cost_variations(string task)
    {
        if (task.has_prefix("check_cost_variations,"))
        {
            string remain = task.substring("check_cost_variations,".length);
            string[] args = remain.split(",");
            if (args.length != 1) error("bad args num in task 'check_cost_variations'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'check_cost_variations'");
            print(@"INFO: in $(ms_wait) ms will do check cost_variations for pid #$(pid).\n");
            CheckCostVariationsTasklet s = new CheckCostVariationsTasklet(
                (int)ms_wait);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class CheckCostVariationsTasklet : Object, ITaskletSpawnable
    {
        public CheckCostVariationsTasklet(
            int ms_wait)
        {
            this.ms_wait = ms_wait;
        }
        private int ms_wait;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            print(@"Doing check cost_variations for node $(pid) Identity #1.\n");
            // Search for events that have ":path_changed:" and then "_0+0_cost_".
            int count = 0;
            foreach (string event in tester_events)
                if (("Qspn:1:Signal:path_changed:" in event) && ("_0+0_cost" in event))
                count++;

            if (pid == 8)
            {
                // We should find count == 6.
                assert(count == 6);
            }
            else if (pid == 7)
            {
                // We should find count > 0.
                assert(count > 0);
            }
            else if (pid == 6)
            {
                // We should find count > 0 and count < 6.
                assert(count > 0);
                assert(count < 6);
            }
            else if (pid == 2)
            {
                // We should find count == 0.
                assert(count == 0);
            }

            return null;
        }
    }
}