using Tasklets;
using Gee;
using zcd;
using Netsukuku;

namespace Netsukuku
{
    public void    log_debug(string msg)   {print(msg+"\n");}
    public void    log_trace(string msg)   {print(msg+"\n");}
    public void  log_verbose(string msg)   {print(msg+"\n");}
    public void     log_info(string msg)   {print(msg+"\n");}
    public void   log_notice(string msg)   {print(msg+"\n");}
    public void     log_warn(string msg)   {print(msg+"\n");}
    public void    log_error(string msg)   {print(msg+"\n");}
    public void log_critical(string msg)   {print(msg+"\n");}
}

void print_known_paths(FakeGenericNaddr n, QspnManager c)
{
        debug(@"For $(n)");
        for (int l = 0; l < n.i_qspn_get_levels(); l++)
        for (int p = 0; p < n.i_qspn_get_gsize(l); p++)
        {
            if (n.i_qspn_get_pos(l) == p) continue;
            int s = c.get_paths_to(new HCoord(l, p)).size;
            if (s > 0) debug(@" to ($(l), $(p)) $(s) paths");
        }
}

int main()
{
    return 0;
}
