/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

using Gee;
using Netsukuku;
using Netsukuku.ModRpc;

string json_string_object(Object obj)
{
    Json.Node n = Json.gobject_serialize(obj);
    Json.Generator g = new Json.Generator();
    g.root = n;
    g.pretty = true;
    string ret = g.to_data(null);
    return ret;
}

void print_object(Object obj)
{
    print(@"$(obj.get_type().name())\n");
    string t = json_string_object(obj);
    print(@"$(t)\n");
}

Object dup_object(Object obj)
{
    //print(@"dup_object...\n");
    Type type = obj.get_type();
    string t = json_string_object(obj);
    Json.Parser p = new Json.Parser();
    try {
        assert(p.load_from_data(t));
    } catch (Error e) {assert_not_reached();}
    Object ret = Json.gobject_deserialize(type, p.get_root());
    //print(@"dup_object done.\n");
    return ret;
}

class FakeArc : Object, IQspnArc
{
    public FakeGenericNaddr naddr;
    public FakeCost cost;
    public string neighbour_nic_addr;
    public string my_nic_addr;
    public QspnManager neighbour_qspnmgr;
    public FakeArc(QspnManager neighbour_qspnmgr,
                    FakeGenericNaddr naddr,
                    FakeCost cost,
                    string neighbour_nic_addr,
                    string my_nic_addr)
    {
        this.neighbour_qspnmgr = neighbour_qspnmgr;
        this.naddr = naddr;
        this.cost = cost;
        this.neighbour_nic_addr = neighbour_nic_addr;
        this.my_nic_addr = my_nic_addr;
    }

    public IQspnCost i_qspn_get_cost()
    {
        return cost;
    }

    public IQspnNaddr i_qspn_get_naddr()
    {
        return naddr;
    }

    public bool i_qspn_equals(IQspnArc other)
    {
        return this==other;
    }

    public bool i_qspn_comes_from(zcd.ModRpc.CallerInfo rpc_caller)
    {
        if (rpc_caller is zcd.ModRpc.TcpCallerInfo)
            return neighbour_nic_addr == ((zcd.ModRpc.TcpCallerInfo)rpc_caller).peer_address;
        else if (rpc_caller is Netsukuku.ModRpc.BroadcastCallerInfo)
            return neighbour_nic_addr == ((Netsukuku.ModRpc.BroadcastCallerInfo)rpc_caller).peer_address;
        else if (rpc_caller is Netsukuku.ModRpc.UnicastCallerInfo)
            return neighbour_nic_addr == ((Netsukuku.ModRpc.UnicastCallerInfo)rpc_caller).peer_address;
        else
            assert_not_reached();
    }
}

class FakeBroadcastClient : FakeAddressManagerStub
{
    private ArrayList<FakeArc> target_arcs;
    private BroadcastID bcid;
    public FakeBroadcastClient(Gee.Collection<FakeArc> target_arcs, BroadcastID bcid)
    {
        this.target_arcs = new ArrayList<FakeArc>();
        this.target_arcs.add_all(target_arcs);
        this.bcid = bcid;
    }

    public override void send_etp
    (IQspnEtpMessage _etp, bool is_full)
    throws Netsukuku.QspnNotAcceptedError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        //print("broadcast send_etp\n");
        tasklet.ms_wait(20);
        IQspnEtpMessage etp = (IQspnEtpMessage)dup_object(_etp);
        //print("now etp =\n");
        //print_object(etp);
        foreach (FakeArc target_arc in target_arcs)
        {
            // we must dup for each target arc (obviously)
            etp = (IQspnEtpMessage)dup_object(_etp);
            QspnManager target_mgr = target_arc.neighbour_qspnmgr;
            string my_ip = target_arc.my_nic_addr;
            var caller = new Netsukuku.ModRpc.BroadcastCallerInfo
                         ("eth0", my_ip, bcid);
            SendEtpTasklet ts = new SendEtpTasklet();
            ts.target_mgr = target_mgr;
            ts.etp = etp;
            ts.is_full = is_full;
            ts.caller = caller;
            tasklet.spawn(ts);
        }
    }
    private class SendEtpTasklet : Object, INtkdTaskletSpawnable
    {
        public QspnManager target_mgr;
        public IQspnEtpMessage etp;
        public bool is_full;
        public Netsukuku.ModRpc.BroadcastCallerInfo caller;
        public void * func()
        {
            try {
                target_mgr.send_etp(etp, is_full, caller);
            } catch (QspnNotAcceptedError e) {
                // ignore, since a broadcast message will never get the error to the caller
            }
            return null;
        }
    }
}

class FakeTCPClient : FakeAddressManagerStub
{
    private FakeArc target_arc;
    public FakeTCPClient(FakeArc target_arc)
    {
        this.target_arc = target_arc;
    }

    public override IQspnEtpMessage get_full_etp
    (IQspnAddress _my_naddr)
    throws Netsukuku.QspnNotAcceptedError, Netsukuku.QspnBootstrapInProgressError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        //print("calling tcp get_full_etp\n");
        tasklet.ms_wait(20);
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        string neigh_ip = target_arc.neighbour_nic_addr;
        var caller = new zcd.ModRpc.TcpCallerInfo
                     (neigh_ip, my_ip);
        tasklet.schedule();
        //print("executing get_full_etp\n");
        IQspnAddress my_naddr = (IQspnAddress)dup_object(_my_naddr);
        IQspnEtpMessage ret = target_mgr.get_full_etp(my_naddr, caller);
        ret = (IQspnEtpMessage)dup_object(ret);
        //print("now ret =\n");
        //print_object(ret);
        return ret;
    }

    public override void send_etp
    (IQspnEtpMessage _etp, bool is_full)
    throws Netsukuku.QspnNotAcceptedError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        //print("tcp send_etp\n");
        tasklet.ms_wait(20);
        IQspnEtpMessage etp = (IQspnEtpMessage)dup_object(_etp);
        //print("now etp =\n");
        //print_object(etp);
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        string neigh_ip = target_arc.neighbour_nic_addr;
        var caller = new zcd.ModRpc.TcpCallerInfo
                     (neigh_ip, my_ip);
        tasklet.schedule();
        target_mgr.send_etp(etp, is_full, caller);
    }
}

class FakeStubFactory : Object, IQspnStubFactory
{
    public SimulatorNode sn;

    public IAddressManagerStub
                    i_qspn_get_broadcast(
                        IQspnMissingArcHandler? missing_handler=null,
                        IQspnArc? ignore_neighbor=null
                    )
    {
        //print(@"node ...$(sn.naddr.pos[0]) is sending broadcast to ...\n");
        var target_arcs = new ArrayList<FakeArc>();
        foreach (IQspnArc _arc in sn.arcs)
        {
            FakeArc arc = (FakeArc) _arc;
            if (ignore_neighbor != null
                && arc.i_qspn_equals(ignore_neighbor))
                continue;
            target_arcs.add(arc);
            //print(@" ...$(arc.naddr.pos[0])\n");
        }
        BroadcastID bcid = new BroadcastID();
        bcid.ignore_nodeid = null; // trick, anyway the arc of 'ignore_neighbor' is already left out.
        return new FakeBroadcastClient(target_arcs, bcid);
    }

    public IAddressManagerStub
                    i_qspn_get_tcp(
                        IQspnArc arc,
                        bool wait_reply=true
                    )
    {
        return new FakeTCPClient((FakeArc) arc);
    }
}

class FakeThresholdCalculator : Object, IQspnThresholdCalculator
{
    public int i_qspn_calculate_threshold(IQspnNodePath p1, IQspnNodePath p2)
    {
        return 10000;
    }
}

class SimulatorNode : Object
{
    public SimulatorNode(string dev, FakeGenericNaddr naddr)
    {
        this.dev = dev;
        int i2 = Random.int_range(0, 255);
        int i3 = Random.int_range(0, 255);
        nic_addr = @"169.254.$(i2).$(i3)";
        this.naddr = naddr;
        arcs = new ArrayList<FakeArc>();
    }
    public string dev;
    public string nic_addr;
    public FakeGenericNaddr naddr;
    public ArrayList<FakeArc> arcs;
    public QspnManager mgr;
    public FakeStubFactory stub_f;
    public FakeArc add_arc(SimulatorNode n0, int cost)
    {
        FakeArc a = new FakeArc(n0.mgr, n0.naddr, new FakeCost(cost), n0.nic_addr, nic_addr);
        arcs.add(a);
        return a;
    }
}

class NodeData : Object
{
    public string name;
    public ArrayList<int> positions;
    public ArrayList<int> elderships;
    public ArrayList<ArcData> arcs;
    public SimulatorNode sn;
}

class ArcData : Object
{
    public string to_name;
    public int cost;
    public int revcost;
}

string[] read_file(string path)
{
    string[] ret = new string[0];
    if (FileUtils.test(path, FileTest.EXISTS))
    {
        try {
            string contents;
            assert(FileUtils.get_contents(path, out contents));
            ret = contents.split("\n");
        } catch (FileError e) {
            error("%s: %d: %s".printf(e.domain.to_string(), e.code, e.message));
        }
    }
    return ret;
}

const int max_paths = 5;
const double max_common_hops_ratio = 0.6;
const int arc_timeout = 3000;

void activate_node(HashMap<string, NodeData> nodes, string k, ArrayList<int> gsizes)
{
    NodeData nd = nodes[k];
    nd.sn = new SimulatorNode("eth0", new FakeGenericNaddr(nd.positions.to_array(), gsizes.to_array()));
    var fp = new FakeFingerprint(nd.elderships.to_array());
    nd.sn.stub_f = new FakeStubFactory(); nd.sn.stub_f.sn = nd.sn;
    var threshold_c = new FakeThresholdCalculator();
    foreach (ArcData ad in nd.arcs)
    {
        nd.sn.add_arc(nodes[ad.to_name].sn, ad.cost);
    }
    nd.sn.mgr = new QspnManager(nd.sn.naddr, max_paths, max_common_hops_ratio, arc_timeout, nd.sn.arcs, fp, threshold_c, nd.sn.stub_f);
    foreach (ArcData ad in nd.arcs)
    {
        tasklet.ms_wait(1);
        nodes[ad.to_name].sn.mgr.arc_add(nodes[ad.to_name].sn.add_arc(nd.sn, ad.revcost));
    }
    while (true)
    {
        if (nd.sn.mgr.is_bootstrap_complete()) break;
        tasklet.ms_wait(10);
    }
}

void test0()
{
    ArrayList<int> gsizes = new ArrayList<int>.wrap({10});
    HashMap<string, NodeData> nodes = new HashMap<string, NodeData>();

    {
        NodeData nd = new NodeData();
        nd.name = "1";
        nd.positions = new ArrayList<int>.wrap({1});
        nd.elderships = new ArrayList<int>.wrap({0});
        nd.arcs = new ArrayList<ArcData>.wrap({});
        nodes[nd.name] = nd;
    }
    {
        NodeData nd = new NodeData();
        nd.name = "2";
        nd.positions = new ArrayList<int>.wrap({2});
        nd.elderships = new ArrayList<int>.wrap({1});
        ArcData ad0 = new ArcData();
        ad0.to_name = "1";
        ad0.cost = 854;
        ad0.revcost = 533;
        nd.arcs = new ArrayList<ArcData>.wrap({ad0});
        nodes[nd.name] = nd;
    }

    foreach (string k in new ArrayList<string>.wrap({"1", "2"}))
    {
        activate_node(nodes, k, gsizes);
        print(@"node $(k): bootstrap complete\n");
        print(@"node $(k): waiting for more messages...\n");
        tasklet.ms_wait(400);
        print(@"node $(k): that's enough.\n");
    }

    {
        try {
            QspnManager mgr = nodes["1"].sn.mgr;
            Gee.List<IQspnNodePath> lst = mgr.get_paths_to(new HCoord(0, 2));
            print(@"node 1 to reach 2 knows $(lst.size) paths.\n");
            assert(lst.size == 1);
            IQspnNodePath p = lst[0];
            Gee.List<IQspnHop> lsth = p.i_qspn_get_hops();
            print(@"the path has $(lsth.size) hops.\n");
            assert(lsth.size == 1);
            IQspnHop h = lsth[0];
            int h_pos = h.i_qspn_get_hcoord().pos;
            assert(h_pos == 2);
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();  // every node has completed bootstrap
        }
    }

    {
        NodeData nd = new NodeData();
        nd.name = "3";
        nd.positions = new ArrayList<int>.wrap({3});
        nd.elderships = new ArrayList<int>.wrap({2});
        ArcData ad0 = new ArcData();
        ad0.to_name = "1";
        ad0.cost = 1125;
        ad0.revcost = 1047;
        ArcData ad1 = new ArcData();
        ad1.to_name = "2";
        ad1.cost = 987;
        ad1.revcost = 1011;
        nd.arcs = new ArrayList<ArcData>.wrap({ad0, ad1});
        nodes[nd.name] = nd;
    }
    {
        activate_node(nodes, "3", gsizes);
        print(@"node 3: bootstrap complete\n");
        print(@"node 3: waiting for more messages...\n");
        tasklet.ms_wait(400);
        print(@"node 3: waiting for more messages...\n");
        tasklet.ms_wait(400);
        print(@"node 3: that's enough.\n");

        try {
            QspnManager mgr = nodes["1"].sn.mgr;
            Gee.List<IQspnNodePath> lst = mgr.get_paths_to(new HCoord(0, 2));
            print(@"node 1 to reach 2 knows $(lst.size) paths.\n");
            // It could be 2 or less, because of the order with which the paths are examined
            // a path might be discarded if a hop is not yet in 'destinations'.
            assert(lst.size <= 2);
            assert(lst.size > 0);
            IQspnNodePath p = lst[0];
            Gee.List<IQspnHop> lsth = p.i_qspn_get_hops();
            print(@"first path has $(lsth.size) hops.\n");
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();  // every node has completed bootstrap
        }
    }

    {
        NodeData nd = new NodeData();
        nd.name = "4";
        nd.positions = new ArrayList<int>.wrap({4});
        nd.elderships = new ArrayList<int>.wrap({3});
        ArcData ad0 = new ArcData();
        ad0.to_name = "3";
        ad0.cost = 1125;
        ad0.revcost = 1047;
        nd.arcs = new ArrayList<ArcData>.wrap({ad0});
        nodes[nd.name] = nd;
    }
    {
        activate_node(nodes, "4", gsizes);
        print(@"node 4: bootstrap complete\n");
        print(@"node 4: waiting for more messages...\n");
        tasklet.ms_wait(400);
        print(@"node 4: waiting for more messages...\n");
        tasklet.ms_wait(400);
        print(@"node 4: that's enough.\n");

        try {
            QspnManager mgr = nodes["4"].sn.mgr;
            Gee.List<IQspnNodePath> lst = mgr.get_paths_to(new HCoord(0, 2));
            print(@"node 4 to reach 2 knows $(lst.size) paths.\n");
            // It could be 2 or less, because of the order with which the paths are examined
            // a path might be discarded if a hop is not yet in 'destinations'.
            assert(lst.size <= 2);
            assert(lst.size > 0);
            IQspnNodePath p = lst[0];
            Gee.List<IQspnHop> lsth = p.i_qspn_get_hops();
            print(@"first path has $(lsth.size) hops.\n");
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();  // every node has completed bootstrap
        }
    }

}

void test_file(string[] args)
{
    string fname = args[1];
    bool wait = false;
    // read data
    int levels;
    ArrayList<int> gsizes = new ArrayList<int>();
    HashMap<string, NodeData> nodes = new HashMap<string, NodeData>();
    ArrayList<string> keys_list = new ArrayList<string>();
    string[] data = read_file(fname);
    int data_cur = 0;
    while (data[data_cur] != "topology") data_cur++;
    data_cur++;
    string s_topology = data[data_cur];
    string[] s_topology_pieces = s_topology.split(" ");
    levels = s_topology_pieces.length;
    foreach (string s_piece in s_topology_pieces) gsizes.insert(0, int.parse(s_piece));
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
        NodeData nd = new NodeData();
        nd.name = s_addr;
        nd.positions = new ArrayList<int>();
        nd.elderships = new ArrayList<int>();
        nd.arcs = new ArrayList<ArcData>();
        foreach (string s_piece in s_addr.split(".")) nd.positions.insert(0, int.parse(s_piece));
        foreach (string s_piece in s_elderships.split(" ")) nd.elderships.insert(0, int.parse(s_piece));
        for (int i = 0; i < arcs_addr.length; i++)
        {
            ArcData ad = new ArcData();
            ad.to_name = arcs_addr[i];
            ad.cost = arcs_cost[i];
            ad.revcost = arcs_revcost[i];
            nd.arcs.add(ad);
        }
        nodes[nd.name] = nd;
        keys_list.add(nd.name);
    }

    // activate and wait the bootstrap for each node
    foreach (string k in keys_list)
    {
        activate_node(nodes, k, gsizes);
        print(@"node $(k): bootstrap complete\n");
        if (wait)
        {
            print(@"node $(k): waiting for more messages...\n");
            tasklet.ms_wait(200);
            print(@"node $(k): presume that's enough.\n");
            print(@"node $(k): any more ...?\n");
            tasklet.ms_wait(200);
            print(@"node $(k): that's enough.\n");
        }
    }

    tasklet.ms_wait(10000);
    NodeData nd0 = nodes[keys_list[0]];
    try {
        for (int l = 1; l <= levels; l++) print(@"node $(nd0.name): at level $(l) we are $(nd0.sn.mgr.get_nodes_inside(l)) nodes.\n");
    } catch (QspnBootstrapInProgressError e) {
        assert_not_reached();  // node has completed bootstrap
    }
    if (args.length > 2 && args[2] == "remove_arc")
    {
        NodeData nd_from = nodes[args[3]];
        NodeData nd_to = nodes[args[4]];
        foreach (FakeArc a in nd_from.sn.arcs)
        {
            if (a.neighbour_qspnmgr == nd_to.sn.mgr)
            {
                nd_from.sn.mgr.arc_remove(a);
                break;
            }
        }
        foreach (FakeArc a in nd_to.sn.arcs)
        {
            if (a.neighbour_qspnmgr == nd_from.sn.mgr)
            {
                nd_to.sn.mgr.arc_remove(a);
                break;
            }
        }
        tasklet.ms_wait(2000);
    }
    else if (args.length > 3)
    {
        string s_addr_from = args[2];
        NodeData nd_from = nodes[s_addr_from];
        var positions = new ArrayList<int>();
        foreach (string s_piece in s_addr_from.split(".")) positions.insert(0, int.parse(s_piece));
        FakeGenericNaddr naddr_from = new FakeGenericNaddr(positions.to_array(), gsizes.to_array());

        string s_addr_to = args[3];
        positions = new ArrayList<int>();
        foreach (string s_piece in s_addr_to.split(".")) positions.insert(0, int.parse(s_piece));
        FakeGenericNaddr naddr_to = new FakeGenericNaddr(positions.to_array(), gsizes.to_array());

        HCoord to_h = naddr_from.i_qspn_get_coord_by_address(naddr_to);
        Gee.List<IQspnNodePath> to_paths;
        try {
            to_paths = nd_from.sn.mgr.get_paths_to(to_h);
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();  // node has completed bootstrap
        }
        print(@"node $(nd_from.name) has $(to_paths.size) paths to reach $(s_addr_to).\n");
        foreach (IQspnNodePath p in to_paths)
        {
            print(s_addr_from);
            foreach (IQspnHop hop in p.i_qspn_get_hops())
            {
                print(@" -arc $(hop.i_qspn_get_arc_id())- $(hcoord_to_string(hop.i_qspn_get_hcoord()))");
            }
            print("\n");
        }
    }
}

string hcoord_to_string(HCoord h)
{
    return @"($(h.lvl), $(h.pos))";
}

INtkdTasklet tasklet;
void main(string[] args)
{
    // init tasklet
    MyTaskletSystem.init();
    tasklet = MyTaskletSystem.get_ntkd();

    // pass tasklet system to module qspn
    QspnManager.init(tasklet);

    if (args.length > 1) test_file(args);
    else test0();

    // end
    MyTaskletSystem.kill();
}
