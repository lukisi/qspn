using Gee;
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

public class MyEtp : ETP, IQspnEtp
{
    public MyEtp(MyNaddr start_node_naddr,
                 MyTPList etp_list,
                 Gee.List<MyNpath> known_paths,
                 Gee.List<MyFingerprint> start_node_fp,
                 int[] start_node_nodes_inside)
    {
        base(start_node_naddr, etp_list, known_paths, start_node_fp, start_node_nodes_inside);
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
        return (MyNaddr)start_node_naddr;
    }

    public bool i_qspn_check_network_parameters(IQspnNaddr my_naddr)
    {
        // check the tp-list
        // level has to be between 0 and levels-1
        // level has to grow only
        // pos has to be between 0 and gsize(level)-1
        int curlvl = 0;
        foreach (HCoord c in ((MyTPList)etp_list).get_hops())
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
        foreach (HCoord c in ((MyTPList)etp_list).get_hops())
        {
            if (c.lvl >= exit_gnode.lvl)
            {
                hops.add(c);
            }
        }
        MyTPList n = new MyTPList(hops);
        etp_list = n;
    }

    public bool i_qspn_tplist_acyclic_check(IQspnNaddr my_naddr)
    {
        // acyclic rule
        foreach (HCoord c in ((MyTPList)etp_list).get_hops())
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
            MyNpath p = (MyNpath)known_paths[i];
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
        foreach (Npath _p in known_paths)
        {
            MyNpath p = (MyNpath)_p;
            MyTPList lst_hops = p.get_lst_hops();
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
            MyTPList lst_new_hops = new MyTPList(new_hops);
            p.set_lst_hops(lst_new_hops);
        }
    }

    public void i_qspn_routeset_tplist_acyclic_check(IQspnNaddr my_naddr)
    {
        // remove paths that does not meet acyclic rule
        int i = 0;
        while (i < known_paths.size)
        {
            MyNpath p = (MyNpath)known_paths[i];
            // acyclic rule
            foreach (HCoord c in p.get_lst_hops().get_hops())
            {
                if (c.pos == my_naddr.i_qspn_get_pos(c.lvl))
                {
                    // unmet
                    known_paths.remove_at(i);
                }
                else
                {
                    i++;
                }
            }
        }
    }

    public void i_qspn_routeset_add_source(HCoord exit_gnode)
    {
        ArrayList<HCoord> to_exit_gnode_hops = new ArrayList<HCoord>();
        to_exit_gnode_hops.add(exit_gnode);
        MyTPList to_exit_gnode_list = new MyTPList(to_exit_gnode_hops);
        int nodes_inside = start_node_nodes_inside[exit_gnode.lvl];
        MyFingerprint fp = (MyFingerprint)start_node_fp[exit_gnode.lvl];
        REM nullrem = new NullREM();
        MyNpath to_exit_gnode = new MyNpath(to_exit_gnode_list,
                                            nodes_inside,
                                            nullrem,
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
        private Iterator<Npath> it;
        public MyEtpRoutesetIterable(MyEtp etp)
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
        ret.add_all(((MyTPList)etp_list).get_hops());
        return ret;
    }
}

public class MyTPList : TPList
{
    public MyTPList(Gee.List<HCoord> hops)
    {
        base(hops);
    }

    public MyTPList.empty()
    {
        base(new ArrayList<HCoord>());
    }

    public Gee.List<HCoord> get_hops() {return hops;}
}

public class MyNpath : Npath, IQspnPath
{
    public MyNpath(MyTPList hops, int nodes_inside, IQspnREM cost, IQspnFingerprint fp)
    {
        base(hops, nodes_inside, (REM)cost, (FingerPrint)fp);
    }

    public MyTPList get_lst_hops()
    {
        return (MyTPList)hops;
    }

    public void set_lst_hops(MyTPList hops)
    {
        this.hops = hops;
    }

    public void set_cost(REM cost)
    {
        this.cost = cost;
    }

    public IQspnREM i_qspn_get_cost()
    {
        return (IQspnREM)cost;
    }

    public Gee.List<HCoord> i_qspn_get_hops()
    {
        return ((MyTPList)hops).get_hops();
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

public class MyNaddr : Naddr, IQspnNaddr, IQspnMyNaddr, IQspnPartialNaddr
{
    public MyNaddr(int[] pos, int[] sizes)
    {
        base(pos, sizes);
    }

    public int i_qspn_get_levels()
    {
        return sizes.size;
    }

    public int i_qspn_get_gsize(int level)
    {
        return sizes[level];
    }

    public int i_qspn_get_pos(int level)
    {
        return pos[level];
    }

    public int i_qspn_get_level_of_gnode()
    {
        int l = 0;
        while (l < pos.size)
        {
            if (pos[l] >= 0) return l;
            l++;
        }
        return pos.size; // the whole network
    }

    public IQspnPartialNaddr i_qspn_get_address_by_coord(HCoord dest)
    {
        int[] newpos = new int[pos.size];
        for (int i = 0; i < dest.lvl; i++) newpos[i] = -1;
        for (int i = dest.lvl; i < 9; i++) newpos[i] = pos[i];
        newpos[dest.lvl] = dest.pos;
        return new MyNaddr(newpos, sizes.to_array());
    }

    public HCoord i_qspn_get_coord_by_address(IQspnNaddr dest)
    {
        int l = pos.size-1;
        while (l >= 0)
        {
            if (pos[l] != dest.i_qspn_get_pos(l)) return new HCoord(l, dest.i_qspn_get_pos(l));
            l--;
        }
        // same naddr: error
        return new HCoord(-1, -1);
    }
}

public class MyFingerprint : FingerPrint, IQspnFingerprint
{
    public MyFingerprint(int64 id, int[] elderships)
    {
        this.id = id;
        this.level = 0;
        this.elderships = elderships;
    }

    private MyFingerprint.empty() {}

    public bool i_qspn_equals(IQspnFingerprint other)
    {
        if (! (other is MyFingerprint)) return false;
        MyFingerprint _other = other as MyFingerprint;
        if (_other.id != id) return false;
        return true;
    }

    public bool i_qspn_elder(IQspnFingerprint other)
    {
        assert(other is MyFingerprint);
        MyFingerprint _other = other as MyFingerprint;
        if (_other.elderships[0] < elderships[0]) return false; // other is elder
        return true;
    }

    public int i_qspn_level {
        get {
            return level;
        }
    }

    public IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingers)
    {
        // given that:
        //  levels = level + elderships.length
        // do not construct for level = levels+1
        assert(elderships.length > 0);
        MyFingerprint ret = new MyFingerprint.empty();
        ret.level = level + 1;
        ret.id = id;
        ret.elderships = new int[elderships.length-1];
        for (int i = 1; i < elderships.length; i++)
            ret.elderships[i-1] = elderships[i];
        int cur_eldership = elderships[0];
        // start comparing
        foreach (IQspnFingerprint f in fingers)
        {
            assert(f is MyFingerprint);
            MyFingerprint _f = f as MyFingerprint;
            assert(_f.level == level);
            if (_f.elderships[0] < cur_eldership)
            {
                cur_eldership = _f.elderships[0];
                ret.id = _f.id;
            }
        }
        return ret;
    }
}

public class MyFingerprintManager : Object, IQspnFingerprintManager
{
    public long i_qspn_mismatch_timeout_msec(IQspnREM sum)
    {
        if (sum is RTT)
        {
            return (sum as RTT).delay * 1000;
        }
        assert(false); return 0;
    }
}

public class MyArcRemover : Object, INeighborhoodArcRemover
{
    public void i_neighborhood_arc_remover_remove(INeighborhoodArc arc)
    {
        assert(false); // do not use in this fake
    }
}

public class MyMissingArcHandler : Object, INeighborhoodMissingArcHandler
{
    public void i_neighborhood_missing(INeighborhoodArc arc, INeighborhoodArcRemover arc_remover)
    {
        // do nothing in this fake
    }
}

public class MyArc : Object, INeighborhoodArc, IQspnArc
{
    public MyArc(string dest, IQspnNaddr addr, IQspnREM cost)
    {
        this.dest = dest;
        this.addr = addr;
        this.qspn_cost = cost;
    }
    public string dest {get; private set;}
    public IQspnNaddr addr {get; private set;}
    private IQspnREM qspn_cost;

    public IQspnREM i_qspn_get_cost() {return qspn_cost;}
    public IQspnNaddr i_qspn_get_naddr() {return addr;}
    public bool i_qspn_equals(IQspnArc other) {return this == (other as MyArc);}
    public bool i_neighborhood_comes_from(zcd.CallerInfo rpc_caller) {return true; /*TODO*/}

    // unused stuff
    public INeighborhoodNodeID i_neighborhood_neighbour_id {get {assert(false); return null;}} // do not use in this fake
    public string i_neighborhood_mac {get {assert(false); return null;}} // do not use in this fake
    public Object i_neighborhood_cost {get {assert(false); return null;}} // do not use in this fake
    public bool i_neighborhood_is_nic(INeighborhoodNetworkInterface nic) {assert(false); return false;} // do not use in this fake
    public bool i_neighborhood_equals(INeighborhoodArc other) {assert(false); return false;} // do not use in this fake
}

public class MyArcToStub : Object, INeighborhoodArcToStub
{
    public IAddressManagerRootDispatcher i_neighborhood_get_broadcast
    (INeighborhoodMissingArcHandler? missing_handler=null,
     INeighborhoodNodeID? ignore_neighbour=null)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher i_neighborhood_get_broadcast_to_nic
    (INeighborhoodNetworkInterface nic,
     INeighborhoodMissingArcHandler? missing_handler=null,
     INeighborhoodNodeID? ignore_neighbour=null)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher i_neighborhood_get_unicast
    (INeighborhoodArc arc, bool wait_reply=true)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher i_neighborhood_get_tcp
    (INeighborhoodArc arc, bool wait_reply=true)
    {
        string dest = (arc as MyArc).dest;
        var ret = new AddressManagerTCPClient(dest, null, null, wait_reply);
        return ret;
    }
}

public class MyEtpFactory : Object, IQspnEtpFactory
{
    private bool busy;
    private int state;
    private MyNaddr? start_node_naddr;
    private MyTPList? etp_list;
    private Gee.List<MyNpath> known_paths;
    private Gee.List<MyFingerprint> start_node_fp;
    private int[] start_node_nodes_inside;

    public MyEtpFactory()
    {
        reset();
    }

    public IQspnPath i_qspn_create_path
                                (Gee.List<HCoord> hops,
                                IQspnFingerprint fp,
                                int nodes_inside,
                                IQspnREM cost)
    {
        MyTPList list = new MyTPList(hops);
        MyNpath ret = new MyNpath(list,
                                  nodes_inside,
                                  cost,
                                  fp);
        return ret;
    }

    public void i_qspn_set_path_cost_dead
                                (IQspnPath path)
    {
        assert(path is MyNpath);
        MyNpath _path = (MyNpath)path;
        _path.set_cost(new DeadREM());
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
        start_node_naddr = (MyNaddr)my_naddr;
        known_paths = new ArrayList<MyNpath>();
        start_node_fp = new ArrayList<MyFingerprint>();
        start_node_nodes_inside = new int[my_naddr.i_qspn_get_levels()];
    }

    public void i_qspn_set_gnode_fingerprint
                                (int level,
                                IQspnFingerprint fp)
    {
        assert(state == 1 || state == 2);
        state = 2;
        start_node_fp[level] = (MyFingerprint)fp;
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
        known_paths.add((MyNpath)path);
    }

    public void i_qspn_set_tplist(Gee.List<HCoord> hops)
    {
        assert(state == 2 || state == 3);
        state = 4;
        etp_list = new MyTPList(hops);
    }

    public IQspnEtp i_qspn_make_etp()
    {
        assert(state == 2 || state == 3 || state == 4);
        if (etp_list == null)
        {
            // new ETP
            etp_list = new MyTPList.empty();
        }
        var ret = new MyEtp(start_node_naddr,
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


int main(string[] args)
{
    // Register serializable types
    typeof(MyNaddr).class_peek();
    typeof(MyFingerprint).class_peek();

    // A network with 8 bits as address space. 3 to level 0, 2 to level 1, 3 to level 2.
    // Node 6 on gnode 2 on ggnode 1. PseudoIP 1.2.6
    MyNaddr addr1 = new MyNaddr({6, 2, 1}, {8, 4, 8});
    // PseudoIP 1.3.3
    MyNaddr addr2 = new MyNaddr({3, 3, 1}, {8, 4, 8});
    // PseudoIP 5.1.4
    MyNaddr addr3 = new MyNaddr({4, 1, 5}, {8, 4, 8});
    // fingerprints
    // first node in the network, also first g-node of level 2.
    MyFingerprint fp126 = new MyFingerprint(837425746848237, {0, 0, 0});
    // second in g-node 1
    MyFingerprint fp133 = new MyFingerprint(233468346784674, {0, 1, 0});
    // second g-node of level 2 in the network, first in g-node 5.
    MyFingerprint fp514 = new MyFingerprint(346634745457246, {0, 0, 1});
    // test calculation of fingerprints
    var i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp12 = fp126.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp13 = fp133.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    i.add(fp12);
    IQspnFingerprint fp1 = fp13.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp51 = fp514.i_qspn_construct(i);
    i = new ArrayList<IQspnFingerprint>();
    IQspnFingerprint fp5 = fp51.i_qspn_construct(i);
    // nodes
    MyNaddr me = null;
    MyArc arc1 = null;
    MyArc arc2 = null;
    IQspnFingerprint fp;
    if (args[1] == "1")
    {
        me = addr1;
        fp = fp126;
        arc1 = new MyArc("192.168.0.62", addr2, new RTT(1000));
        arc2 = new MyArc("192.168.0.63", addr3, new RTT(1000));
    }
    else if (args[1] == "2")
    {
        me = addr2;
        fp = fp133;
        arc1 = new MyArc("192.168.0.61", addr1, new RTT(1000));
        arc2 = new MyArc("192.168.0.63", addr3, new RTT(1000));
    }
    else if (args[1] == "3")
    {
        me = addr3;
        fp = fp514;
        arc1 = new MyArc("192.168.0.62", addr2, new RTT(1000));
        arc2 = new MyArc("192.168.0.61", addr1, new RTT(1000));
    }
    else
    {
        return 1;
    }
    ArrayList<IQspnArc> arcs = new ArrayList<IQspnArc>();
    arcs.add(arc1);
    arcs.add(arc2);
    //
    QspnManager mgr = new QspnManager(me,
                                      5,
                                      0.6,
                                      arcs,
                                      fp,
                                      new MyArcToStub(),
                                      new MyFingerprintManager(),
                                      new MyEtpFactory());

    return 0;
}

