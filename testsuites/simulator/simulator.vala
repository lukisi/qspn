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
using Netsukuku.Qspn;
using TaskletSystem;

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
    public FakeCost cost;
    public string neighbour_nic_addr;
    public string my_nic_addr;
    public QspnManager neighbour_qspnmgr;
    public FakeArc neighbour_arc;
    public FakeArc(QspnManager neighbour_qspnmgr,
                    FakeCost cost,
                    string neighbour_nic_addr,
                    string my_nic_addr)
    {
        this.neighbour_qspnmgr = neighbour_qspnmgr;
        this.cost = cost;
        this.neighbour_nic_addr = neighbour_nic_addr;
        this.my_nic_addr = my_nic_addr;
    }

    public IQspnCost i_qspn_get_cost()
    {
        return cost;
    }

    public bool i_qspn_equals(IQspnArc other)
    {
        return this==other;
    }

    public bool i_qspn_comes_from(CallerInfo rpc_caller)
    {
        if (rpc_caller is FakeCallerInfo)
        {
            FakeCallerInfo _rpc_caller = (FakeCallerInfo)rpc_caller;
            FakeArc dest_arc = _rpc_caller.src_arc.neighbour_arc;
            return dest_arc == this;
        }
        error("not implemented yet");
    }
}

class FakeBroadcastClient : Object, IQspnManagerStub
{
    private ArrayList<FakeArc> target_arcs;
    public FakeBroadcastClient(Gee.Collection<FakeArc> target_arcs)
    {
        this.target_arcs = new ArrayList<FakeArc>();
        this.target_arcs.add_all(target_arcs);
    }

    public IQspnEtpMessage get_full_etp
    (Netsukuku.IQspnAddress requesting_address)
    throws Netsukuku.QspnNotAcceptedError, Netsukuku.QspnBootstrapInProgressError, StubError, DeserializeError
    {
        error("FakeBroadcastClient: you should not use broadcast for method get_full_etp.");
    }

    public void send_etp
    (IQspnEtpMessage _etp, bool is_full)
    throws Netsukuku.QspnNotAcceptedError, StubError, DeserializeError
    {
        print("broadcast send_etp\n");
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
            var caller = new FakeCallerInfo(target_arc);
            SendEtpTasklet ts = new SendEtpTasklet();
            ts.target_mgr = target_mgr;
            ts.etp = etp;
            ts.is_full = is_full;
            ts.caller = caller;
            tasklet.spawn(ts);
        }
    }
    private class SendEtpTasklet : Object, ITaskletSpawnable
    {
        public QspnManager target_mgr;
        public IQspnEtpMessage etp;
        public bool is_full;
        public CallerInfo caller;
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

	public void got_destroy() throws StubError, DeserializeError
	{
	    error("not implemented yet");
	}

	public void got_prepare_destroy() throws StubError, DeserializeError
	{
	    error("not implemented yet");
	}
}

class FakeTCPClient : Object, IQspnManagerStub
{
    private FakeArc target_arc;
    public FakeTCPClient(FakeArc target_arc)
    {
        this.target_arc = target_arc;
    }

    public IQspnEtpMessage get_full_etp
    (IQspnAddress _my_naddr)
    throws Netsukuku.QspnNotAcceptedError, Netsukuku.QspnBootstrapInProgressError, StubError, DeserializeError
    {
        print("calling tcp get_full_etp\n");
        tasklet.ms_wait(20);
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        string neigh_ip = target_arc.neighbour_nic_addr;
        var caller = new FakeCallerInfo(target_arc);
        tasklet.schedule();
        //print("executing get_full_etp\n");
        IQspnAddress my_naddr = (IQspnAddress)dup_object(_my_naddr);
        IQspnEtpMessage ret = target_mgr.get_full_etp(my_naddr, caller);
        ret = (IQspnEtpMessage)dup_object(ret);
        //print("now ret =\n");
        //print_object(ret);
        return ret;
    }

    public void send_etp
    (IQspnEtpMessage _etp, bool is_full)
    throws Netsukuku.QspnNotAcceptedError, StubError, DeserializeError
    {
        print("tcp send_etp\n");
        tasklet.ms_wait(20);
        IQspnEtpMessage etp = (IQspnEtpMessage)dup_object(_etp);
        //print("now etp =\n");
        //print_object(etp);
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        string neigh_ip = target_arc.neighbour_nic_addr;
        var caller = new FakeCallerInfo(target_arc);
        tasklet.schedule();
        target_mgr.send_etp(etp, is_full, caller);
    }

	public void got_destroy() throws StubError, DeserializeError
	{
	    error("not implemented yet");
	}

	public void got_prepare_destroy() throws StubError, DeserializeError
	{
	    error("not implemented yet");
	}
}

class FakeStubFactory : Object, IQspnStubFactory
{
    public SimulatorNode sn;

    public IQspnManagerStub
                    i_qspn_get_broadcast(
                            Gee.List<IQspnArc> arcs,
                            IQspnMissingArcHandler? missing_handler=null
                    )
    {
        //print(@"node ...$(sn.naddr.pos[0]) is sending broadcast to ...\n");
        var target_arcs = new ArrayList<FakeArc>();
        foreach (IQspnArc _arc in arcs)
        {
            FakeArc arc = (FakeArc) _arc;
            assert(arc in sn.arcs);
            target_arcs.add(arc);
            //print(@" ...$(arc.naddr.pos[0])\n");
        }
        return new FakeBroadcastClient(target_arcs);
    }

    public IQspnManagerStub
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
        return 3000;
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
        FakeArc a = new FakeArc(n0.mgr, new FakeCost(cost), n0.nic_addr, nic_addr);
        arcs.add(a);
        return a;
    }

    private Timer? tm_handle_gnode_splitted;
    public FakeArc f_a_handle_gnode_splitted;
    public FakeFingerprint f_fp_handle_gnode_splitted;
    public void handle_gnode_splitted(IQspnArc a, HCoord hdest, IQspnFingerprint fp)
    {
        f_a_handle_gnode_splitted = (FakeArc)a;
        f_fp_handle_gnode_splitted = (FakeFingerprint)fp;
        tm_handle_gnode_splitted = new Timer(3000);
    }
    public bool has_handled_gnode_splitted()
    {
        if (tm_handle_gnode_splitted == null) return false;
        if (tm_handle_gnode_splitted.is_expired()) return false;
        return true;
    }

    public void notify_qspn_bootstrap_complete()
    {
        print(@"From $(naddr) got signal qspn_bootstrap_complete()\n");
        int l = naddr.pos.size;
        int count;
        try {
            count = mgr.get_nodes_inside(l);
        } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
        print(@"       we are about $(count) on the net\n");
    }
    public void notify_presence_notified()
    {
        print(@"From $(naddr) got signal presence_notified()\n");
    }
    public void notify_arc_removed(IQspnArc arc)
    {
        print(@"From $(naddr) got signal arc_removed(???)\n");
    }
    public void notify_destination_added(HCoord h)
    {
        print(@"From $(naddr) got signal destination_added(($(h.lvl), $(h.pos)))\n");
    }
    public void notify_destination_removed(HCoord h)
    {
        print(@"From $(naddr) got signal destination_removed(($(h.lvl), $(h.pos)))\n");
    }
    public void notify_path_added(IQspnNodePath p)
    {
        int length = p.i_qspn_get_hops().size;
        IQspnHop last = p.i_qspn_get_hops().last();
        HCoord h = last.i_qspn_get_hcoord();
        print(@"From $(naddr) got signal path_added($(length) steps to ($(h.lvl), $(h.pos)))\n");
    }
    public void notify_path_changed(IQspnNodePath p)
    {
        int length = p.i_qspn_get_hops().size;
        IQspnHop last = p.i_qspn_get_hops().last();
        HCoord h = last.i_qspn_get_hcoord();
        print(@"From $(naddr) got signal path_changed($(length) steps to ($(h.lvl), $(h.pos)))\n");
    }
    public void notify_path_removed(IQspnNodePath p)
    {
        int length = p.i_qspn_get_hops().size;
        IQspnHop last = p.i_qspn_get_hops().last();
        HCoord h = last.i_qspn_get_hcoord();
        print(@"From $(naddr) got signal path_removed($(length) steps to ($(h.lvl), $(h.pos)))\n");
    }
    public void notify_changed_fp(int l)
    {
        print(@"From $(naddr) got signal changed_fp(at level $(l))\n");
    }
    public void notify_changed_nodes_inside(int l)
    {
        if (!mgr.is_bootstrap_complete()) return;
        int count;
        try {
            count = mgr.get_nodes_inside(l);
        } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
        print(@"From $(naddr) got signal changed_nodes_inside(at level $(l)) now is $(count)\n");
    }
    public void notify_gnode_splitted(IQspnArc a, HCoord d, IQspnFingerprint fp)
    {
        print(@"From $(naddr) got signal gnode_splitted(IQspnArc a, HCoord d, IQspnFingerprint fp)\n");
    }
    public void notify_remove_identity()
    {
        print(@"From $(naddr) got signal remove_identity()\n");
    }
}

internal class Timer : Object
{
    private TimeVal start;
    private long msec_ttl;
    public Timer(long msec_ttl)
    {
        start = TimeVal();
        start.get_current_time();
        this.msec_ttl = msec_ttl;
    }

    private long get_lap()
    {
        TimeVal lap = TimeVal();
        lap.get_current_time();
        long sec = lap.tv_sec - start.tv_sec;
        long usec = lap.tv_usec - start.tv_usec;
        if (usec < 0)
        {
            usec += 1000000;
            sec--;
        }
        return sec*1000000 + usec;
    }

    public bool is_expired()
    {
        return get_lap() > msec_ttl*1000;
    }
}

class Directive : Object
{
    // Activate a node
    public bool activate_node = false;
    public string name;
    public ArrayList<int> positions;
    public ArrayList<int> elderships;
    public ArrayList<ArcData> arcs;
    public int hooking_gnode_level;
    public int into_gnode_level;
    // Wait
    public bool wait = false;
    public int wait_msec;
    // Add arc
    public bool add_arc = false;
    public ArcData arc_add;
    // Change arc
    public bool change_arc = false;
    public ArcData arc_change;
    // Remove arc
    public bool remove_arc = false;
    public ArcData arc_remove;
    // Check Split signal
    public bool check_split_signal = false;
    public string check_split_from_name;
    public HCoord check_split_to_h;
    public bool check_split_returns;
    public int check_split_wait_msec;
}

class ArcData : Object
{
    public string from_name;
    public string to_name;
    public FakeArc from_arc;
    public FakeArc to_arc;
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
            error(@"$(e.domain.to_string()): $(e.code): $(e.message)");
        }
    }
    else error(@"Script $(path) not found");
    return ret;
}

const int max_paths = 5;
const double max_common_hops_ratio = 0.6;
const int arc_timeout = 300;

bool first_done = false;

SimulatorNode newnode_create_net(Directive dd, ArrayList<int> gsizes)
{
    SimulatorNode sn = new SimulatorNode("eth0", new FakeGenericNaddr(dd.positions.to_array(), gsizes.to_array()));
    var fp = new FakeFingerprint(dd.elderships.to_array());
    sn.stub_f = new FakeStubFactory(); sn.stub_f.sn = sn;
    sn.mgr = new QspnManager.create_net(sn.naddr, fp, sn.stub_f);

    if (!first_done)
    {
        first_done = true;
        sn.mgr.gnode_splitted.connect((_a, _hdest, _fp) => sn.handle_gnode_splitted(_a, _hdest, _fp));
        sn.mgr.qspn_bootstrap_complete.connect(sn.notify_qspn_bootstrap_complete);
        sn.mgr.presence_notified.connect(sn.notify_presence_notified);
        sn.mgr.arc_removed.connect(sn.notify_arc_removed);
        sn.mgr.destination_added.connect(sn.notify_destination_added);
        sn.mgr.destination_removed.connect(sn.notify_destination_removed);
        sn.mgr.path_added.connect(sn.notify_path_added);
        sn.mgr.path_changed.connect(sn.notify_path_changed);
        sn.mgr.path_removed.connect(sn.notify_path_removed);
        sn.mgr.changed_fp.connect(sn.notify_changed_fp);
        sn.mgr.changed_nodes_inside.connect(sn.notify_changed_nodes_inside);
        sn.mgr.gnode_splitted.connect(sn.notify_gnode_splitted);
        sn.mgr.remove_identity.connect(sn.notify_remove_identity);
    }

    while (true)
    {
        if (sn.mgr.is_bootstrap_complete()) break;
        tasklet.ms_wait(10);
    }
    return sn;
}

SimulatorNode newnode_enter_net(SimulatorNode prev, HashMap<string, SimulatorNode> nodes, Directive dd, ArrayList<int> gsizes)
{
    SimulatorNode sn = new SimulatorNode("eth0", new FakeGenericNaddr(dd.positions.to_array(), gsizes.to_array()));
    var fp = new FakeFingerprint(dd.elderships.to_array());
    sn.stub_f = new FakeStubFactory(); sn.stub_f.sn = sn;
    foreach (ArcData ad in dd.arcs)
    {
        ad.from_arc = sn.add_arc(nodes[ad.to_name], ad.cost);
    }
    sn.mgr = new QspnManager.enter_net(
                    /*Gee.List<IQspnArc> internal_arc_set*/ new ArrayList<IQspnArc>(),
                    /*Gee.List<IQspnArc> internal_arc_prev_arc_set*/ new ArrayList<IQspnArc>(),
                    /*Gee.List<IQspnNaddr> internal_arc_peer_naddr_set*/ new ArrayList<IQspnNaddr>(),
                    /*Gee.List<IQspnArc> external_arc_set*/ sn.arcs,
                    sn.naddr, fp,
                    (old) => old, /* null update_internal_fingerprints */
                    sn.stub_f, dd.hooking_gnode_level, dd.into_gnode_level, prev.mgr);

    sn.mgr.gnode_splitted.connect((_a, _hdest, _fp) => sn.handle_gnode_splitted(_a, _hdest, _fp));
    sn.mgr.qspn_bootstrap_complete.connect(sn.notify_qspn_bootstrap_complete);
    sn.mgr.presence_notified.connect(sn.notify_presence_notified);
    sn.mgr.arc_removed.connect(sn.notify_arc_removed);
    sn.mgr.destination_added.connect(sn.notify_destination_added);
    sn.mgr.destination_removed.connect(sn.notify_destination_removed);
    sn.mgr.path_added.connect(sn.notify_path_added);
    sn.mgr.path_changed.connect(sn.notify_path_changed);
    sn.mgr.path_removed.connect(sn.notify_path_removed);
    sn.mgr.changed_fp.connect(sn.notify_changed_fp);
    sn.mgr.changed_nodes_inside.connect(sn.notify_changed_nodes_inside);
    sn.mgr.gnode_splitted.connect(sn.notify_gnode_splitted);
    sn.mgr.remove_identity.connect(sn.notify_remove_identity);

    foreach (ArcData ad in dd.arcs)
    {
        tasklet.ms_wait(1);
        ad.to_arc = nodes[ad.to_name].add_arc(sn, ad.revcost);
        nodes[ad.to_name].mgr.arc_add(ad.to_arc);
        ad.to_arc.neighbour_arc = ad.from_arc;
        ad.from_arc.neighbour_arc = ad.to_arc;
    }
    while (true)
    {
        if (sn.mgr.is_bootstrap_complete()) break;
        tasklet.ms_wait(10);
    }
    return sn;
}

void activate_node(Directive dd, HashMap<string, SimulatorNode> nodes, ArrayList<int> gsizes)
{
    SimulatorNode sn;
    if (dd.arcs.size == 0)
    {
        sn = newnode_create_net(dd, gsizes);
    }
    else
    {
        var temp = newnode_create_net(dd, gsizes);
        sn = newnode_enter_net(temp, nodes, dd, gsizes);
    }
    nodes[dd.name] = sn;
}

void test_file(string[] args)
{
    string fname = args[1];
    // read data
    int levels;
    ArrayList<int> gsizes = new ArrayList<int>();
    HashMap<string, SimulatorNode> nodes = new HashMap<string, SimulatorNode>();
    ArrayList<Directive> directives = new ArrayList<Directive>();
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
        if (data[data_cur] == "node")
        {
            data_cur++;
            string s_addr = data[data_cur++];
            string s_elderships = data[data_cur++];
            string[] arcs_addr = {};
            int[] arcs_cost = {};
            int[] arcs_revcost = {};
            int hooking_gnode_level = -1;
            int into_gnode_level = -1;
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
                if (line_pieces[0] == "hook")
                {
                    hooking_gnode_level = int.parse(line_pieces[1]);
                    assert(line_pieces[2] == "into");
                    into_gnode_level = int.parse(line_pieces[3]);
                }
                data_cur++;
            }
            // data input done
            Directive dd = new Directive();
            dd.activate_node = true;
            dd.name = s_addr;
            dd.positions = new ArrayList<int>();
            dd.elderships = new ArrayList<int>();
            dd.arcs = new ArrayList<ArcData>();
            dd.hooking_gnode_level = hooking_gnode_level;
            dd.into_gnode_level = into_gnode_level;
            foreach (string s_piece in s_addr.split(".")) dd.positions.insert(0, int.parse(s_piece));
            foreach (string s_piece in s_elderships.split(" ")) dd.elderships.insert(0, int.parse(s_piece));
            for (int i = 0; i < arcs_addr.length; i++)
            {
                ArcData ad = new ArcData();
                ad.to_name = arcs_addr[i];
                ad.cost = arcs_cost[i];
                ad.revcost = arcs_revcost[i];
                dd.arcs.add(ad);
            }
            directives.add(dd);
        }
        else if (data[data_cur] != null && data[data_cur].has_prefix("wait_msec"))
        {
            string line = data[data_cur];
            string[] line_pieces = line.split(" ");
            int wait_msec = int.parse(line_pieces[1]);
            // data input done
            Directive dd = new Directive();
            dd.wait = true;
            dd.wait_msec = wait_msec;
            directives.add(dd);
            data_cur++;
            assert(data[data_cur] == "");
        }
        else if (data[data_cur] != null && data[data_cur].has_prefix("add_arc"))
        {
            string line = data[data_cur];
            string[] line_pieces = line.split(" ");
            assert(line_pieces[1] == "from");
            string from_addr = line_pieces[2];
            assert(line_pieces[3] == "to");
            string to_addr = line_pieces[4];
            assert(line_pieces[5] == "cost");
            int cost = int.parse(line_pieces[6]);
            assert(line_pieces[7] == "revcost");
            int revcost = int.parse(line_pieces[8]);
            // data input done
            Directive dd = new Directive();
            dd.add_arc = true;
            dd.arc_add = new ArcData();
            dd.arc_add.from_name = from_addr;
            dd.arc_add.to_name = to_addr;
            dd.arc_add.cost = cost;
            dd.arc_add.revcost = revcost;
            directives.add(dd);
            data_cur++;
            assert(data[data_cur] == "");
        }
        else if (data[data_cur] != null && data[data_cur].has_prefix("remove_arc"))
        {
            string line = data[data_cur];
            string[] line_pieces = line.split(" ");
            assert(line_pieces[1] == "from");
            string from_addr = line_pieces[2];
            assert(line_pieces[3] == "to");
            string to_addr = line_pieces[4];
            // data input done
            Directive dd = new Directive();
            dd.remove_arc = true;
            dd.arc_remove = new ArcData();
            dd.arc_remove.from_name = from_addr;
            dd.arc_remove.to_name = to_addr;
            directives.add(dd);
            data_cur++;
            assert(data[data_cur] == "");
        }
        else if (data[data_cur] != null && data[data_cur].has_prefix("check_split_signal"))
        {
            // check_split_signal from 2.1.0.0.1.0 to_coord 5,12 wait_msec 12000 returns true
            string line = data[data_cur];
            string[] line_pieces = line.split(" ");
            assert(line_pieces[1] == "from");
            string from_addr = line_pieces[2];
            assert(line_pieces[3] == "to_coord");
            string to_hcoord = line_pieces[4];
            string to_hcoord_lvl = to_hcoord.split(",")[0];
            string to_hcoord_pos = to_hcoord.split(",")[1];
            HCoord to_h = new HCoord(int.parse(to_hcoord_lvl), int.parse(to_hcoord_pos));
            assert(line_pieces[5] == "wait_msec");
            int wait_msec = int.parse(line_pieces[6]);
            assert(line_pieces[7] == "returns");
            bool returns = line_pieces[8].up() == "TRUE";
            // data input done
            Directive dd = new Directive();
            dd.check_split_signal = true;
            dd.check_split_from_name = from_addr;
            dd.check_split_to_h = to_h;
            dd.check_split_wait_msec = wait_msec;
            dd.check_split_returns = returns;
            directives.add(dd);
            data_cur++;
            assert(data[data_cur] == "");
        }
        else if (data_cur >= data.length)
        {
            break;
        }
        else
        {
            data_cur++;
        }
    }

    // execute directives
    foreach (Directive dd in directives)
    {
        if (dd.activate_node)
        {
            print(@"activating node $(dd.name) with $(dd.arcs.size) arcs:\n");
            foreach (ArcData ad in dd.arcs)
            {
                print(@"  to $(ad.to_name)\n");
            }
            activate_node(dd, nodes, gsizes);
            print(@"node $(dd.name): bootstrap complete\n");
        }
        else if (dd.wait)
        {
            print(@"waiting $(dd.wait_msec) msec...\n");
            tasklet.ms_wait(dd.wait_msec);
        }
        else if (dd.add_arc)
        {
            SimulatorNode sn_from = nodes[dd.arc_add.from_name];
            SimulatorNode sn_to = nodes[dd.arc_add.to_name];
            FakeArc from_arc = sn_from.add_arc(sn_to, dd.arc_add.cost);
            FakeArc to_arc = sn_to.add_arc(sn_from, dd.arc_add.revcost);
            from_arc.neighbour_arc = to_arc;
            to_arc.neighbour_arc = from_arc;
            sn_from.mgr.arc_add(from_arc);
            tasklet.ms_wait(10);
            sn_to.mgr.arc_add(to_arc);
            print(@"added arc from $(dd.arc_add.from_name) to $(dd.arc_add.to_name)\n");
        }
        else if (dd.change_arc)
        {
        }
        else if (dd.remove_arc)
        {
            SimulatorNode sn_from = nodes[dd.arc_remove.from_name];
            SimulatorNode sn_to = nodes[dd.arc_remove.to_name];
            foreach (FakeArc a in sn_from.arcs)
            {
                if (a.neighbour_qspnmgr == sn_to.mgr)
                {
                    sn_from.mgr.arc_remove(a);
                    break;
                }
            }
            foreach (FakeArc a in sn_to.arcs)
            {
                if (a.neighbour_qspnmgr == sn_from.mgr)
                {
                    sn_to.mgr.arc_remove(a);
                    break;
                }
            }
            print(@"removed arc from $(dd.arc_remove.from_name) to $(dd.arc_remove.to_name)\n");
        }
        else if (dd.check_split_signal)
        {
            SimulatorNode sn_from = nodes[dd.check_split_from_name];
            print(@"checking split signal from $(dd.check_split_from_name), give it $(dd.check_split_wait_msec) msec...\n");
            Timer t_wait = new Timer(dd.check_split_wait_msec);
            while (true)
            {
                if (t_wait.is_expired())
                {
                    if (dd.check_split_returns) error("did not signal split, while expected");
                    print("no split: ok\n");
                    break;
                }
                if (sn_from.has_handled_gnode_splitted())
                {
                    if (! dd.check_split_returns) error("handled a signal split, while not expected");
                    print("split: ok\n");
                    break;
                }
                tasklet.ms_wait(100);
            }
        }
    }

    if (args.length > 3)
    {
        string s_addr_from = args[2];
        SimulatorNode sn_from = nodes[s_addr_from];
        try {
            for (int l = 1; l <= levels; l++) print(@"node $(s_addr_from): at level $(l) we are $(sn_from.mgr.get_nodes_inside(l)) nodes.\n");
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();  // node has completed bootstrap
        }

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
            to_paths = sn_from.mgr.get_paths_to(to_h);
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();  // node has completed bootstrap
        }
        print(@"node $(s_addr_from) has $(to_paths.size) paths to reach $(s_addr_to).\n");
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

class FakeCallerInfo : CallerInfo
{
    public FakeCallerInfo(FakeArc src_arc)
    {
        base();
        this.src_arc = src_arc;
    }

    public FakeArc src_arc;
}

ITasklet tasklet;
void main(string[] args)
{
    // init tasklet
    PthTaskletImplementer.init();
    tasklet = PthTaskletImplementer.get_tasklet_system();

    // pass tasklet system to module qspn
    QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new FakeThresholdCalculator());

    test_file(args);

    // end
    PthTaskletImplementer.kill();
}
