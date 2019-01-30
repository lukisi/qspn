using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_addtag(string task)
    {
        if (task.has_prefix("addtag,"))
        {
            string remain = task.substring("addtag,".length);
            string[] args = remain.split(",");
            if (args.length != 2) error("bad args num in task 'addtag'");
            int64 ms_wait;
            if (! int64.try_parse(args[0], out ms_wait)) error("bad args ms_wait in task 'addtag'");
            string label = args[1];
            print(@"INFO: in $(ms_wait) ms will add tag '$(label)' to event list.\n");
            AddTagTasklet s = new AddTagTasklet((int)(ms_wait), label);
            tasklet.spawn(s);
            return true;
        }
        else return false;
    }

    class AddTagTasklet : Object, ITaskletSpawnable
    {
        public AddTagTasklet(int ms_wait, string label)
        {
            this.ms_wait = ms_wait;
            this.label = label;
        }
        private int ms_wait;
        private string label;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            print(@"Tag: $(label)\n");
            tester_events.add(@"Tester:Tag:$(label)");

            return null;
        }
    }
}