/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2014-2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

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

void print_all_known_paths(FakeGenericNaddr n, QspnManager c)
{
        if (! c.is_mature()) return;
        print(@"For $(n)\n");
        for (int l = 0; l < n.i_qspn_get_levels(); l++)
        for (int p = 0; p < n.i_qspn_get_gsize(l); p++)
        {
            if (n.i_qspn_get_pos(l) == p) continue;
            Gee.List<IQspnNodePath> paths;
            try {
                paths = c.get_paths_to(new HCoord(l, p));
            } catch (QspnNotMatureError e) {assert_not_reached();}
            int s = paths.size;
            if (s > 0)
            {
                print(@" to ($(l), $(p)) $(s) paths:\n");
                foreach (IQspnNodePath path in paths)
                {
                    IQspnArc arc = path.i_qspn_get_arc();
                    IQspnNaddr gw = arc.i_qspn_get_naddr();
                    print(@"  gw $(gw as FakeGenericNaddr)=");
                    Gee.List<IQspnHop> hops = path.i_qspn_get_hops();
                    string delimiter = "";
                    foreach (IQspnHop hop in hops)
                    {
                        print(@"$(delimiter)$(hop.i_qspn_get_arc_id())($(hop.i_qspn_get_naddr() as FakeGenericNaddr))");
                        delimiter = " - ";
                    }
                    print(@".\n");
                }
            }
        }
}

string[] read_file(string path)
{
    string[] ret = new string[0];
    if (FileUtils.test(path, FileTest.EXISTS))
    {
        try
        {
            string contents;
            assert(FileUtils.get_contents(path, out contents));
            ret = contents.split("\n");
        }
        catch (FileError e) {error("%s: %d: %s".printf(e.domain.to_string(), e.code, e.message));}
    }
    return ret;
}

string test_node_addr;

int main2(string[] args)
{
    test_node_addr = ""; // default
    OptionContext oc = new OptionContext("<graph_file_name>");
    OptionEntry[] entries = new OptionEntry[2];
    int index = 0;
    entries[index++] = {"testaddr", 'a', 0, OptionArg.STRING, ref test_node_addr, "Dotted form address of test node", null};
    entries[index++] = { null };
    oc.add_main_entries(entries, null);
    try {
        oc.parse(ref args);
    }
    catch (OptionError e) {
        print(@"Error parsing options: $(e.message)\n");
        return 1;
    }

    // init tasklet
    assert(Tasklet.init());
    {
        const int max_paths = 4;
        const double max_common_hops_ratio = 0.7;
        const int arc_timeout = 3000;
        HashMap<string, FakeGenericNaddr> naddresses = new HashMap<string, FakeGenericNaddr>();
        HashMap<string, QspnManager> managers = new HashMap<string, QspnManager>();
        HashMap<string, string> local_addresses = new HashMap<string, string>();

        string[] data = read_file(args[1]);
        int data_cur = 0;
        while (data[data_cur] != "topology") data_cur++;
        data_cur++;
        string s_topology = data[data_cur];
        string[] s_topology_pieces = s_topology.split(" ");
        int levels = s_topology_pieces.length;
        int[] net_topology = new int[levels];
        int j = levels - 1;
        foreach (string s_piece in s_topology_pieces) net_topology[j--] = int.parse(s_piece);

        while (true)
        {
            bool eof = false;
            while (data[data_cur] != "node")
            {
                data_cur++;
                if (data_cur >= data.length)
                {
                    eof = true;
                    break;
                }
            }
            if (eof) break;
            data_cur++;
            string s_addr = data[data_cur++];
            string s_elderships = data[data_cur++];
            string[] arcs_addr = {};
            int[] arcs_cost = {};
            int[] arcs_revcost = {};
            while (data[data_cur] != "")
            {
                string line = data[data_cur];
                string[] line_pieces = line.split(" ");
                if (line_pieces[0] == "arc")
                {
                    assert(line_pieces[1] == "to");
                    arcs_addr += line_pieces[2];
                    assert(line_pieces[3] == "cost");
                    arcs_cost += int.parse(line_pieces[4]);
                    assert(line_pieces[5] == "revcost");
                    arcs_revcost += int.parse(line_pieces[6]);
                }
                data_cur++;
            }
            // data input done
            int[] n_addr = new int[levels];
            j = levels - 1;
            foreach (string s_piece in s_addr.split(".")) n_addr[j--] = int.parse(s_piece);
            FakeGenericNaddr n = new FakeGenericNaddr(n_addr, net_topology);
            naddresses[s_addr] = n;
            // generate a random IP for this nic
            int i1 = Random.int_range(64, 127);
            int i2 = Random.int_range(0, 255);
            int i3 = Random.int_range(0, 255);
            string local_address = @"100.$(i1).$(i2).$(i3)";
            local_addresses[s_addr] = local_address;
            var arclist = new ArrayList<IQspnArc>();
            for (int i = 0; i < arcs_addr.length; i++)
            {
                string s0_addr = arcs_addr[i];
                QspnManager c0 = managers[s0_addr];
                FakeGenericNaddr n0 = naddresses[s0_addr];
                string local_addr0 = local_addresses[s0_addr];
                var arc = new FakeArc(c0, n0, new FakeCost(arcs_cost[i]), local_addr0, local_address);
                arclist.add(arc);
            }
            int[] n_elderships = new int[levels];
            j = levels - 1;
            foreach (string s_piece in s_elderships.split(" ")) n_elderships[j--] = int.parse(s_piece);
            var fp = new FakeFingerprint(Random.int_range(0, 1000000), n_elderships);
            var stub_f = new FakeStubFactory();
            var threshold_c = new FakeThresholdCalculator();
            QspnManager c = new QspnManager(n, max_paths, max_common_hops_ratio, arc_timeout, arclist, fp, threshold_c, stub_f);
            stub_f.my_mgr = c;
            managers[s_addr] = c;
            for (int i = 0; i < arcs_addr.length; i++)
            {
                string s0_addr = arcs_addr[i];
                QspnManager c0 = managers[s0_addr];
                string local_addr0 = local_addresses[s0_addr];
                var arc = new FakeArc(c, n, new FakeCost(arcs_revcost[i]), local_address, local_addr0);
                c0.arc_add(arc);
            }
            while (true)
            {
                ms_wait(300);
                if (c.is_mature()) break;
            }
            ms_wait(20*managers.size);
        }
        // test a node
        if (test_node_addr == "")
        {
            int rnd_node_num = Random.int_range(0, managers.size);
            Iterator<string> it_addr = managers.keys.iterator();
            while ((rnd_node_num--) > 0) it_addr.next();
            test_node_addr = it_addr.@get();
        }
        FakeGenericNaddr n_test_node = naddresses[test_node_addr];
        QspnManager c_test_node = managers[test_node_addr];
        print_all_known_paths(n_test_node, c_test_node);
    }
    assert(Tasklet.kill());
    return 0;
}

void main()
{
    Tasklet.init();
    int max_paths = 5;
    double max_common_hops_ratio = 0.5;
    int arc_timeout = 3000;
    IQspnThresholdCalculator threshold_calculator = new FakeThresholdCalculator();
    QspnManager.init();

    FakeGenericNaddr n0 = new FakeGenericNaddr({0,1,1,0}, {2,2,2,2});
    string na0 = "169.254.35.127";
    Gee.List<IQspnArc> a0 = new ArrayList<IQspnArc>();
    IQspnFingerprint fp0 = new FakeFingerprint(346523, {0,0,0,0});
    IQspnStubFactory sf0 = new FakeStubFactory();
    QspnManager q0 = new QspnManager(n0, max_paths, max_common_hops_ratio,
            arc_timeout, a0, fp0, threshold_calculator, sf0);
    ((FakeStubFactory)sf0).my_mgr = q0;
    mature_report(q0, "q0 is mature.\n");

    ms_wait(500);

    FakeGenericNaddr n1 = new FakeGenericNaddr({1,1,1,0}, {2,2,2,2});
    string na1 = "169.254.203.4";
    Gee.List<IQspnArc> a1 = new ArrayList<IQspnArc>();
    a1.add(new FakeArc(q0, n0, new FakeCost(300), na0, na1));
    IQspnFingerprint fp1 = new FakeFingerprint(658236, {1,0,0,0});
    IQspnStubFactory sf1 = new FakeStubFactory();
    QspnManager q1 = new QspnManager(n1, max_paths, max_common_hops_ratio,
            arc_timeout, a1, fp1, threshold_calculator, sf1);
    ((FakeStubFactory)sf1).my_mgr = q1;
    mature_report(q1, "q1 is mature.\n");

    ms_wait(1200);
    q0.arc_add(new FakeArc(q1, n1, new FakeCost(500), na1, na0));

    ms_wait(500);
    print_all_known_paths(n0,q0);
    print_all_known_paths(n1,q1);

    FakeGenericNaddr n2 = new FakeGenericNaddr({1,0,1,0}, {2,2,2,2});
    string na2 = "169.254.24.45";
    Gee.List<IQspnArc> a2 = new ArrayList<IQspnArc>();
    a2.add(new FakeArc(q0, n0, new FakeCost(500), na0, na2));
    IQspnFingerprint fp2 = new FakeFingerprint(384579345, {0,1,0,0});
    IQspnStubFactory sf2 = new FakeStubFactory();
    QspnManager q2 = new QspnManager(n2, max_paths, max_common_hops_ratio,
            arc_timeout, a2, fp2, threshold_calculator, sf2);
    ((FakeStubFactory)sf2).my_mgr = q2;
    mature_report(q2, "q2 is mature.\n");

    q0.arc_add(new FakeArc(q2, n2, new FakeCost(1500), na2, na0));

    ms_wait(2000);
    print_all_known_paths(n0,q0);
    print_all_known_paths(n1,q1);
    print_all_known_paths(n2,q2);

    q1.arc_add(new FakeArc(q2, n2, new FakeCost(1500), na2, na1));
    q2.arc_add(new FakeArc(q1, n1, new FakeCost(1500), na1, na2));

    ms_wait(2000);
    print_all_known_paths(n0,q0);
    print_all_known_paths(n1,q1);
    print_all_known_paths(n2,q2);

    q0.stop_operations();
    q1.stop_operations();
    q2.stop_operations();

    Tasklet.kill();
}

void mature_report(QspnManager q, string msg)
{
    if (q.is_mature())
    {
        print(msg);
    }
    else
    {
        ulong h = 0;
        h = q.qspn_mature.connect(() => {
            print(msg);
            if (h != 0) q.disconnect(h);
        });
    }
}

