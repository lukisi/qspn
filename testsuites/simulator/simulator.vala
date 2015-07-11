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

void print_object(Object obj)
{
    print(@"$(obj.get_type().name())\n");
    Json.Node n = Json.gobject_serialize(obj);
    Json.Generator g = new Json.Generator();
    g.root = n;
    g.pretty = true;
    string t = g.to_data(null);
    print(@"$(t)\n");
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
    (IQspnEtpMessage etp, bool is_full)
    throws Netsukuku.QspnNotAcceptedError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        print("broadcast send_etp\n");
        print_object(etp);
        foreach (FakeArc target_arc in target_arcs)
        {
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
    (IQspnAddress my_naddr)
    throws Netsukuku.QspnNotAcceptedError, Netsukuku.QspnBootstrapInProgressError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        print("tcp get_full_etp\n");
        print_object(my_naddr);
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        string neigh_ip = target_arc.neighbour_nic_addr;
        var caller = new zcd.ModRpc.TcpCallerInfo
                     (neigh_ip, my_ip);
        tasklet.schedule();
        IQspnEtpMessage ret = target_mgr.get_full_etp(my_naddr, caller);
        return ret;
    }

    public override void send_etp
    (IQspnEtpMessage etp, bool is_full)
    throws Netsukuku.QspnNotAcceptedError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        print("tcp send_etp\n");
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
        var target_arcs = new ArrayList<FakeArc>();
        foreach (IQspnArc _arc in sn.arcs)
        {
            FakeArc arc = (FakeArc) _arc;
            if (ignore_neighbor != null
                && arc.i_qspn_equals(ignore_neighbor))
                continue;
            target_arcs.add(arc);
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

INtkdTasklet tasklet;
void main()
{
    const int max_paths = 4;
    const double max_common_hops_ratio = 0.7;
    const int arc_timeout = 3000;

    // init tasklet
    MyTaskletSystem.init();
    tasklet = MyTaskletSystem.get_ntkd();

    // pass tasklet system to module qspn
    QspnManager.init(tasklet);

    SimulatorNode sn0 = new SimulatorNode("eth0", new FakeGenericNaddr({1,0,1}, {2,2,2}));
    var fp = new FakeFingerprint({0,0,0});
    sn0.stub_f = new FakeStubFactory(); sn0.stub_f.sn = sn0;
    var threshold_c = new FakeThresholdCalculator();
    sn0.mgr = new QspnManager(sn0.naddr, max_paths, max_common_hops_ratio, arc_timeout, sn0.arcs, fp, threshold_c, sn0.stub_f);
    while (true)
    {
        if (sn0.mgr.is_bootstrap_complete()) break;
        tasklet.ms_wait(10);
    }
    print("node 0: bootstrap complete\n");

    SimulatorNode sn1 = new SimulatorNode("eth0", new FakeGenericNaddr({0,0,1}, {2,2,2}));
    fp = new FakeFingerprint({1,0,0});
    sn1.stub_f = new FakeStubFactory(); sn1.stub_f.sn = sn1;
    threshold_c = new FakeThresholdCalculator();
    sn1.add_arc(sn0, 1200);
    sn1.mgr = new QspnManager(sn1.naddr, max_paths, max_common_hops_ratio, arc_timeout, sn1.arcs, fp, threshold_c, sn1.stub_f);
    tasklet.ms_wait(200);
    sn0.mgr.arc_add(sn0.add_arc(sn1, 1050));
    while (true)
    {
        if (sn1.mgr.is_bootstrap_complete()) break;
        tasklet.ms_wait(10);
    }
    print("node 1: bootstrap complete\n");

    SimulatorNode sn2 = new SimulatorNode("eth0", new FakeGenericNaddr({0,1,1}, {2,2,2}));
    fp = new FakeFingerprint({0,1,0});
    sn2.stub_f = new FakeStubFactory(); sn2.stub_f.sn = sn2;
    threshold_c = new FakeThresholdCalculator();
    sn2.add_arc(sn0, 1200);
    sn2.mgr = new QspnManager(sn2.naddr, max_paths, max_common_hops_ratio, arc_timeout, sn2.arcs, fp, threshold_c, sn2.stub_f);
    tasklet.ms_wait(200);
    sn0.mgr.arc_add(sn0.add_arc(sn2, 1050));
    while (true)
    {
        if (sn2.mgr.is_bootstrap_complete()) break;
        tasklet.ms_wait(10);
    }
    print("node 2: bootstrap complete\n");

    tasklet.ms_wait(200);
    try {
        for (int l = 0; l < 3; l++) print(@"node 1: at level $(l) we are $(sn1.mgr.get_nodes_inside(l)) nodes.\n");
    } catch (QspnBootstrapInProgressError e) {
        assert_not_reached();  // node 1 has completed bootstrap
    }

    // end
    MyTaskletSystem.kill();
}
