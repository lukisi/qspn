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

public class FakeNodeID : Object, INeighborhoodNodeID
{
    public int id {get; private set;}
    public FakeNodeID()
    {
        id = Random.int_range(0, 10000);
    }

    public bool i_neighborhood_equals(INeighborhoodNodeID other)
    {
        if (!(other is FakeNodeID)) return false;
        return id == (other as FakeNodeID).id;
    }

    public bool i_neighborhood_is_on_same_network(INeighborhoodNodeID other)
    {
        return true; // not used in this test
    }
}

public class FakeArc : Object, IQspnArc, INeighborhoodArc
{
    public FakeGenericNaddr naddr;
    public FakeREM cost;
    public string neighbour_nic_addr;
    public string my_nic_addr;
    public QspnManager neighbour_qspnmgr;
    public INeighborhoodNodeID neighbour_id;
    public FakeArc(QspnManager neighbour_qspnmgr,
                    FakeGenericNaddr naddr,
                    FakeREM cost,
                    INeighborhoodNodeID neighbour_id,
                    string neighbour_nic_addr,
                    string my_nic_addr)
    {
        this.neighbour_qspnmgr = neighbour_qspnmgr;
        this.naddr = naddr;
        this.cost = cost;
        this.neighbour_id = neighbour_id;
        this.neighbour_nic_addr = neighbour_nic_addr;
        this.my_nic_addr = my_nic_addr;
    }

    public IQspnNaddr i_qspn_get_naddr()
    {
        return naddr;
    }

    public IQspnREM i_qspn_get_cost()
    {
        return cost;
    }

    public bool i_qspn_equals(IQspnArc other)
    {
        return this == other;
    }

    public INeighborhoodNodeID i_neighborhood_neighbour_id {get {return neighbour_id;}}
    public string i_neighborhood_mac {get {return "";}}
    public Object i_neighborhood_cost {get {return cost;}}
    public bool i_neighborhood_is_nic(INeighborhoodNetworkInterface nic) {return false;}
    public bool i_neighborhood_equals(INeighborhoodArc other) {return other == this;}
    public bool i_neighborhood_comes_from(zcd.CallerInfo rpc_caller) {return neighbour_nic_addr == rpc_caller.caller_ip;}
}

public class FakeBroadcastClient : FakeAddressManager
{
    private ArrayList<FakeArc> target_arcs;
    public FakeBroadcastClient(Gee.Collection<FakeArc> target_arcs)
    {
        this.target_arcs = new ArrayList<FakeArc>();
        this.target_arcs.add_all(target_arcs);
    }

    public override void send_etp
    (IQspnEtp etp, zcd.CallerInfo? _rpc_caller = null)
    throws QspnNotAcceptedError, zcd.RPCError
    {
        foreach (FakeArc target_arc in target_arcs)
        {
            QspnManager target_mgr = target_arc.neighbour_qspnmgr;
            string my_ip = target_arc.my_nic_addr;
            CallerInfo caller = new CallerInfo(my_ip, null, null);
            // tasklet for:  target_mgr.send_etp(etp, caller);
            Tasklet.tasklet_callback(
                (_target_mgr, _etp, _caller) => {
                    QspnManager t_target_mgr = (QspnManager)_target_mgr;
                    IQspnEtp t_etp           = (IQspnEtp)_etp;
                    CallerInfo t_caller      = (CallerInfo)_caller;
                    try
                    {
                        t_target_mgr.send_etp(t_etp, t_caller);
                    }
                    catch (QspnNotAcceptedError e)
                    {
                        debug(@"Sending message send_etp got $(e.message)");
                    }
                },
                target_mgr,
                etp,
                caller
                );
        }
    }
}

public class FakeTCPClient : FakeAddressManager
{
    private FakeArc target_arc;
    public FakeTCPClient(FakeArc target_arc)
    {
        this.target_arc = target_arc;
    }

    public override IQspnEtp get_full_etp
    (IQspnNaddr my_naddr, zcd.CallerInfo? _rpc_caller = null)
    throws QspnNotAcceptedError, QspnNotMatureError, RPCError
    {
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        CallerInfo caller = new CallerInfo(my_ip, null, null);
        Tasklet.schedule();
        IQspnEtp ret = target_mgr.get_full_etp(my_naddr, caller);
        return ret;
    }

    public override void send_etp
    (IQspnEtp etp, zcd.CallerInfo? _rpc_caller = null)
    throws QspnNotAcceptedError, zcd.RPCError
    {
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        CallerInfo caller = new CallerInfo(my_ip, null, null);
        Tasklet.schedule();
        target_mgr.send_etp(etp, caller);
    }
}

public class FakeArcToStub : Object, INeighborhoodArcToStub
{
    public QspnManager my_mgr;
    public FakeArcToStub()
    {
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_broadcast(
                        INeighborhoodMissingArcHandler? missing_handler=null,
                        INeighborhoodNodeID? ignore_neighbour=null
                    )
    {
        var target_arcs = new ArrayList<FakeArc>();
        foreach (IQspnArc _arc in my_mgr.current_arcs())
        {
            FakeArc arc = (FakeArc) _arc;
            if (ignore_neighbour != null
                && arc.neighbour_id.i_neighborhood_equals(ignore_neighbour))
                continue;
            target_arcs.add(arc);
        }
        return new FakeBroadcastClient(target_arcs);
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_broadcast_to_nic(
                        INeighborhoodNetworkInterface nic,
                        INeighborhoodMissingArcHandler? missing_handler=null,
                        INeighborhoodNodeID? ignore_neighbour=null
                    )
    {
        assert_not_reached(); // will not be used by this module
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_unicast(
                        INeighborhoodArc arc,
                        bool wait_reply=true
                    )
    {
        assert_not_reached(); // will not be used by this module
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_tcp(
                        INeighborhoodArc _arc,
                        bool wait_reply=true
                    )
    {
        FakeArc arc = (FakeArc) _arc;
        return new FakeTCPClient(arc);
    }
}

public class FakeEtp : Object, IQspnEtp
{
    private FakeGenericNaddr start_node_naddr;
    private ArrayList<FakeFingerprint> start_node_fp;
    private ArrayList<int> start_node_nodes_inside;
    private FakeTPList etp_list;
    private ArrayList<FakePath> known_paths;
    public FakeEtp(FakeGenericNaddr start_node_naddr,
                   FakeTPList etp_list,
                   Gee.List<FakePath> known_paths,
                   Gee.List<FakeFingerprint> start_node_fp,
                   int[] start_node_nodes_inside)
    {
        this.start_node_naddr = start_node_naddr;
        this.start_node_fp = new ArrayList<FakeFingerprint>();
        this.start_node_fp.add_all(start_node_fp);
        this.etp_list = etp_list;
        this.known_paths = new ArrayList<FakePath>();
        this.known_paths.add_all(known_paths);
        this.start_node_nodes_inside = new ArrayList<int>();
        this.start_node_nodes_inside.add_all_array(start_node_nodes_inside);
    }

    // On a received ETP.
    // IQspnNaddr i_qspn_get_naddr();
    // i_qspn_check_network_parameters(IQspnNaddr my_naddr);
    // i_qspn_tplist_adjust(HCoord exit_gnode);
    // i_qspn_tplist_acyclic_check(IQspnNaddr my_naddr);
    // i_qspn_routeset_cleanup(HCoord exit_gnode);
    // i_qspn_routeset_tplist_adjust(HCoord exit_gnode);
    // i_qspn_routeset_tplist_acyclic_check(IQspnNaddr my_naddr);
    // i_qspn_routeset_add_source(HCoord exit_gnode);
    // _routeset_getter();   (foreach IQspnPath p in x.routeset)
    
    // Builds an ETP to be forwarded
    // i_qspn_prepare_forward(HCoord exit_gnode);

    // On an ETP to be forwarded.
    // i_qspn_add_path(IQspnPath path);

    public IQspnNaddr i_qspn_get_naddr()
    {
        return start_node_naddr;
    }

    public bool i_qspn_check_network_parameters(IQspnNaddr my_naddr)
    {
        // check the tp-list
        // level has to be between 0 and levels-1
        // level has to grow only
        // pos has to be between 0 and gsize(level)-1
        int curlvl = 0;
        foreach (HCoord c in etp_list.get_hops())
        {
            if (c.lvl < curlvl) return false;
            if (c.lvl >= my_naddr.i_qspn_get_levels()) return false;
            curlvl = c.lvl;
            if (c.pos < 0) return false;
            if (c.pos >= my_naddr.i_qspn_get_gsize(c.lvl)) return false;
        }
        return true;
    }

    public void i_qspn_tplist_adjust(HCoord exit_gnode)
    {
        // grouping rule
        ArrayList<HCoord> hops = new ArrayList<HCoord>();
        hops.add(exit_gnode);
        foreach (HCoord c in etp_list.get_hops())
        {
            if (c.lvl >= exit_gnode.lvl)
            {
                hops.add(c);
            }
        }
        FakeTPList n = new FakeTPList(hops);
        etp_list = n;
    }

    public bool i_qspn_tplist_acyclic_check(IQspnNaddr my_naddr)
    {
        // acyclic rule
        foreach (HCoord c in etp_list.get_hops())
        {
            if (c.pos == my_naddr.i_qspn_get_pos(c.lvl)) return false;
        }
        return true;
    }

    public void i_qspn_routeset_cleanup(HCoord exit_gnode)
    {
        // remove paths internal to the exit_gnode
        int i = 0;
        while (i < known_paths.size)
        {
            FakePath p = known_paths[i];
            Gee.List<HCoord> l = p.i_qspn_get_hops();
            HCoord dest = l.last();
            if (dest.lvl < exit_gnode.lvl)
            {
                known_paths.remove_at(i);
            }
            else
            {
                i++;
            }
        }
    }

    public void i_qspn_routeset_tplist_adjust(HCoord exit_gnode)
    {
        foreach (FakePath p in known_paths)
        {
            FakeTPList lst_hops = p.get_lst_hops();
            // grouping rule
            ArrayList<HCoord> new_hops = new ArrayList<HCoord>();
            new_hops.add(exit_gnode);
            foreach (HCoord c in lst_hops.get_hops())
            {
                if (c.lvl >= exit_gnode.lvl)
                {
                    new_hops.add(c);
                }
            }
            FakeTPList lst_new_hops = new FakeTPList(new_hops);
            p.set_lst_hops(lst_new_hops);
        }
    }

    public void i_qspn_routeset_tplist_acyclic_check(IQspnNaddr my_naddr)
    {
        // remove paths that does not meet acyclic rule
        int i = 0;
        while (i < known_paths.size)
        {
            FakePath p = known_paths[i];
            bool unmet = false;
            // acyclic rule
            foreach (HCoord c in p.get_lst_hops().get_hops())
            {
                if (c.pos == my_naddr.i_qspn_get_pos(c.lvl))
                {
                    // unmet
                    unmet = true;
                    break;
                }
            }
            if (unmet)
            {
                known_paths.remove_at(i);
            }
            else
            {
                i++;
            }
        }
    }

    public void i_qspn_routeset_add_source(HCoord exit_gnode)
    {
        ArrayList<HCoord> to_exit_gnode_hops = new ArrayList<HCoord>();
        to_exit_gnode_hops.add(exit_gnode);
        FakeTPList to_exit_gnode_list = new FakeTPList(to_exit_gnode_hops);
        int nodes_inside = start_node_nodes_inside[exit_gnode.lvl];
        FakeFingerprint fp = start_node_fp[exit_gnode.lvl];
        FakeREM rem_none = new FakeREM.none();
        FakePath to_exit_gnode = new FakePath(to_exit_gnode_list,
                                            nodes_inside,
                                            rem_none,
                                            fp);
        known_paths.add(to_exit_gnode);
    }

    private IQspnEtpRoutesetIterable my_routeset;
    public unowned IQspnEtpRoutesetIterable _i_qspn_routeset_getter()
    {
        my_routeset = new MyEtpRoutesetIterable(this);
        return my_routeset;
    }

    private class MyEtpRoutesetIterable : Object, IQspnEtpRoutesetIterable
    {
        private Iterator<FakePath> it;
        public MyEtpRoutesetIterable(FakeEtp etp)
        {
            it = etp.known_paths.iterator();
        }

        public IQspnPath? next_value ()
        {
            if (! it.has_next()) return null;
            it.next();
            return (IQspnPath)it.@get();
        }
    }

    public Gee.List<HCoord> i_qspn_get_tplist()
    {
        // add the exit_gnode to my list
        Gee.List<HCoord> ret = new ArrayList<HCoord>();
        ret.add_all(etp_list.get_hops());
        return ret;
    }
}

public class FakeTPList : Object
{
    private ArrayList<HCoord> hops;
    public FakeTPList(Gee.List<HCoord> hops)
    {
        this.hops = new ArrayList<HCoord>();
        this.hops.add_all(hops);
    }

    public FakeTPList.empty()
    {
        this(new ArrayList<HCoord>());
    }

    public Gee.List<HCoord> get_hops() {return hops;}
}

public class FakePath : Object, IQspnPath
{
    private FakeTPList hops;
    private int nodes_inside;
    private FakeREM cost;
    private FakeFingerprint fp;
    public FakePath(FakeTPList hops, int nodes_inside, FakeREM cost, FakeFingerprint fp)
    {
        this.hops = hops;
        this.nodes_inside = nodes_inside;
        this.cost = cost;
        this.fp = fp;
    }

    public FakeTPList get_lst_hops()
    {
        return hops;
    }

    public void set_lst_hops(FakeTPList hops)
    {
        this.hops = hops;
    }

    public void set_cost(FakeREM cost)
    {
        this.cost = cost;
    }

    public IQspnREM i_qspn_get_cost()
    {
        return (IQspnREM)cost;
    }

    public Gee.List<HCoord> i_qspn_get_hops()
    {
        return hops.get_hops();
    }

    public IQspnFingerprint i_qspn_get_fp()
    {
        return (IQspnFingerprint)fp;
    }

    public int i_qspn_get_nodes_inside()
    {
        return nodes_inside;
    }
}

public class FakeEtpFactory : Object, IQspnEtpFactory
{
    private bool busy;
    private int state;
    private FakeGenericNaddr? start_node_naddr;
    private FakeTPList? etp_list;
    private Gee.List<FakePath> known_paths;
    private Gee.List<FakeFingerprint?> start_node_fp;
    private int[] start_node_nodes_inside;

    public FakeEtpFactory()
    {
        reset();
    }

    public IQspnPath i_qspn_create_path
                                (Gee.List<HCoord> hops,
                                IQspnFingerprint fp,
                                int nodes_inside,
                                IQspnREM cost)
    {
        FakeTPList list = new FakeTPList(hops);
        FakePath ret = new FakePath(list,
                                  nodes_inside,
                                  (FakeREM)cost,
                                  (FakeFingerprint)fp);
        return ret;
    }

    public void i_qspn_set_path_cost_dead
                                (IQspnPath path)
    {
        assert(path is FakePath);
        FakePath _path = (FakePath)path;
        _path.set_cost(new FakeREM.dead());
    }

    public bool i_qspn_begin_etp()
    {
        if (busy) return false;
        busy = true;
        return true;
    }

    public void i_qspn_abort_etp()
    {
        reset();
    }

    public void i_qspn_set_my_naddr(IQspnNaddr my_naddr)
    {
        assert(state == 0);
        state = 1;
        start_node_naddr = (FakeGenericNaddr)my_naddr;
        known_paths = new ArrayList<FakePath>();
        start_node_fp = new ArrayList<FakeFingerprint?>();
        int levels = my_naddr.i_qspn_get_levels();
        start_node_nodes_inside = new int[levels];
        for (int i = 0; i < levels; i++) start_node_fp.add(null);
    }

    public void i_qspn_set_gnode_fingerprint
                                (int level,
                                IQspnFingerprint fp)
    {
        assert(state == 1 || state == 2);
        state = 2;
        start_node_fp[level] = (FakeFingerprint)fp;
    }

    public void i_qspn_set_gnode_nodes_inside
                                (int level,
                                int nodes_inside)
    {
        assert(state == 1 || state == 2);
        state = 2;
        start_node_nodes_inside[level] = nodes_inside;
    }

    public void i_qspn_add_path(IQspnPath path)
    {
        assert(state == 2 || state == 3);
        state = 3;
        known_paths.add((FakePath)path);
    }

    public void i_qspn_set_tplist(Gee.List<HCoord> hops)
    {
        assert(state == 2 || state == 3);
        state = 4;
        etp_list = new FakeTPList(hops);
    }

    public IQspnEtp i_qspn_make_etp()
    {
        assert(state == 2 || state == 3 || state == 4);
        if (etp_list == null)
        {
            // new ETP
            etp_list = new FakeTPList.empty();
        }
        var ret = new FakeEtp(start_node_naddr,
                            etp_list,
                            known_paths,
                            start_node_fp,
                            start_node_nodes_inside);
        reset();
        return ret;
    }

    private void reset()
    {
        state = 0;
        busy = false;
        start_node_naddr = null;
        etp_list = null;
    }
}
