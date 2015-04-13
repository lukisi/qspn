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
        print(@"For $(n)\n");
        for (int l = 0; l < n.i_qspn_get_levels(); l++)
        for (int p = 0; p < n.i_qspn_get_gsize(l); p++)
        {
            if (n.i_qspn_get_pos(l) == p) continue;
            Gee.List<IQspnNodePath> paths = c.get_paths_to(new HCoord(l, p));
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
                        print(@"$(delimiter)$(hop.i_qspn_get_naddr() as FakeGenericNaddr)");
                        delimiter = " - ";
                    }
                    print(@"·\n");
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

int main(string[] args)
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

