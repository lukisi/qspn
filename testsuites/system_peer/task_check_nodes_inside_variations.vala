using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_check_nodes_inside_variations(string task)
    {
        if (task.has_prefix("check_nodes_inside_variations,"))
        {
            string remain = task.substring("check_nodes_inside_variations,".length);
            string[] args = remain.split(",");
            if (args.length != 1) error("bad args num in task 'check_nodes_inside_variations'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'check_nodes_inside_variations'");
            print(@"INFO: in $(ms_wait) ms will do check nodes_inside_variations for pid #$(pid).\n");
            CheckNodesInsideVariationsTasklet s = new CheckNodesInsideVariationsTasklet(
                (int)ms_wait);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class CheckNodesInsideVariationsTasklet : Object, ITaskletSpawnable
    {
        public CheckNodesInsideVariationsTasklet(
            int ms_wait)
        {
            this.ms_wait = ms_wait;
        }
        private int ms_wait;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            if (pid == 4)
            {
                print(@"Doing check nodes_inside_variations for node 4 Identity #1.\n");
                // Search for events that have "Qspn:1:Signal:path_changed:wl0_2+0_cost_".
                // We should find 11 of them: ending with "_nodesinside_2", 3, 4, ... 9, 10, 12, 14.
                ArrayList<string> matches = new ArrayList<string>();
                foreach (string event in tester_events)
                    if ("Qspn:1:Signal:path_changed:wl0_2+0_cost_" in event)
                    matches.add(event + "_");
                assert(matches.size == 11);
                assert("_nodesinside_2_" in matches[0]);
                assert("_nodesinside_3_" in matches[1]);
                assert("_nodesinside_4_" in matches[2]);
                assert("_nodesinside_5_" in matches[3]);
                assert("_nodesinside_6_" in matches[4]);
                assert("_nodesinside_7_" in matches[5]);
                assert("_nodesinside_8_" in matches[6]);
                assert("_nodesinside_9_" in matches[7]);
                assert("_nodesinside_10_" in matches[8]);
                assert("_nodesinside_12_" in matches[9]);
                assert("_nodesinside_14_" in matches[10]);
            }
            else if (pid == 5)
            {
                print(@"Doing check nodes_inside_variations for node 5 Identity #1.\n");
                // Search for events that have "Signal:path_added" and "_2+1_cost".
                // We should find 2 of them.
                int count = 0;
                foreach (string event in tester_events)
                    if (("Signal:path_added" in event) && ("_2+1_cost" in event))
                    count++;
                assert(count == 2);
            }
            else if (pid == 6)
            {
                print(@"Doing check nodes_inside_variations for node 6 Identity #1.\n");
                // Search for events that have "Signal:path_added" and "_2+1_cost".
                // We should find 1 of them.
                int count = 0;
                foreach (string event in tester_events)
                    if (("Signal:path_added" in event) && ("_2+1_cost" in event))
                    count++;
                assert(count == 1);
            }

            return null;
        }
    }
}