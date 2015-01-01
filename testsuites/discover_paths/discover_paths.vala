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
    // init tasklet
    assert(Tasklet.init());
    {
        const int max_paths = 4;
        const double max_common_hops_ratio = 0.7;
        HashMap<string, FakeGenericNaddr> naddresses = new HashMap<string, FakeGenericNaddr>();
        HashMap<string, QspnManager> managers = new HashMap<string, QspnManager>();
        HashMap<string, string> local_addresses = new HashMap<string, string>();
        HashMap<string, FakeNodeID> node_ids = new HashMap<string, FakeNodeID>();

        const int[] net_topology = {3, 3, 3};
        int levels = net_topology.length;

        {
            string s_addr = "2.1.0";
            string s_elderships = "0 0 0";
            string[] arcs_addr = {};
            int[] arcs_cost = {};
            int[] arcs_revcost = {};
            int[] n_addr = new int[levels];
            int j = levels - 1;
            foreach (string s_piece in s_addr.split(".")) n_addr[j--] = int.parse(s_piece);
            FakeGenericNaddr n = new FakeGenericNaddr(n_addr, net_topology);
            naddresses[s_addr] = n;
            // generate a random IP for this nic
            int i1 = Random.int_range(64, 127);
            int i2 = Random.int_range(0, 255);
            int i3 = Random.int_range(0, 255);
            string local_address = @"100.$(i1).$(i2).$(i3)";
            local_addresses[s_addr] = local_address;
            var node_id = new FakeNodeID();
            node_ids[s_addr] = node_id;
            var arclist = new ArrayList<IQspnArc>();
            for (int i = 0; i < arcs_addr.length; i++)
            {
                string s0_addr = arcs_addr[i];
                QspnManager c0 = managers[s0_addr];
                FakeGenericNaddr n0 = naddresses[s0_addr];
                string local_addr0 = local_addresses[s0_addr];
                FakeNodeID n0_id = node_ids[s0_addr];
                var arc = new FakeArc(c0, n0, new FakeREM(arcs_cost[i]), n0_id, local_addr0, local_address);
                arclist.add(arc);
            }
            int[] n_elderships = new int[levels];
            j = levels - 1;
            foreach (string s_piece in s_elderships.split(" ")) n_elderships[j--] = int.parse(s_piece);
            var fp = new FakeFingerprint(Random.int_range(0, 1000000), n_elderships);
            var fmgr = new FakeREM.FakeFingerprintManager();
            var tostub = new FakeArcToStub();
            var factory = new FakeEtpFactory();
            QspnManager c = new QspnManager(n, max_paths, max_common_hops_ratio, arclist, fp, tostub, fmgr, factory);
            tostub.my_mgr = c;
            managers[s_addr] = c;
            for (int i = 0; i < arcs_addr.length; i++)
            {
                string s0_addr = arcs_addr[i];
                QspnManager c0 = managers[s0_addr];
                string local_addr0 = local_addresses[s0_addr];
                var arc = new FakeArc(c, n, new FakeREM(arcs_revcost[i]), node_id, local_address, local_addr0);
                c0.arc_add(arc);
            }
            while (true)
            {
                ms_wait(300);
                if (c.is_mature()) break;
            }
        }
    }
    assert(Tasklet.kill());
    return 0;
}

