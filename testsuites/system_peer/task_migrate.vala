using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    bool schedule_task_migrate(string task)
    {
        if (task.has_prefix("migrate,"))
        {
            error("not implemented yet");
        }
        else return false;
    }

    class MigrateTasklet : Object, ITaskletSpawnable
    {
        public MigrateTasklet(int ms_wait)
        {
            this.ms_wait = ms_wait;
            // this.my_dev = my_dev;
            // this.peer_pid = peer_pid;
            // this.peer_dev = peer_dev;
        }
        private int ms_wait;
        // private string my_dev;
        // private int peer_pid;
        // private string peer_dev;

        public void * func()
        {
            tasklet.ms_wait(ms_wait);

            // error("not implemented yet");

            return null;
        }
    }
}