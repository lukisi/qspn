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
            }
            else if (pid == 5)
            {
                print(@"Doing check nodes_inside_variations for node 5 Identity #1.\n");
            }
            else if (pid == 6)
            {
                print(@"Doing check nodes_inside_variations for node 6 Identity #1.\n");
            }

            return null;
        }
    }
}