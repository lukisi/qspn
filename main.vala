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

public class MyNaddr : Netsukuku.Naddr, IQspnNaddr, IQspnMyNaddr, IQspnPartialNaddr
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

    public HCoord i_qspn_get_coord_by_address(IQspnPartialNaddr dest)
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


public class MyNetworkID : Object, IQspnNetworkID
{
    public bool i_qspn_is_same_network(IQspnNetworkID other)
    {
        return true;
    }
}

public abstract class GenericNodeData : Object, IQspnNodeData
{
    private MyNetworkID netid;
    protected MyNaddr naddr;

    public GenericNodeData(MyNaddr naddr)
    {
        this.netid = new MyNetworkID();
        this.naddr = naddr;
    }

    public bool i_qspn_equals(IQspnNodeData other)
    {
        return this == (other as GenericNodeData);
    }

    public bool i_qspn_is_on_same_network(IQspnNodeData other)
    {
        return true;
    }

    public IQspnNetworkID i_qspn_get_netid()
    {
        return netid;
    }

    public IQspnNaddr i_qspn_get_naddr()
    {
        return (IQspnNaddr)naddr;
    }

    public abstract IQspnMyNaddr i_qspn_get_naddr_as_mine();
}

public class MyNodeData : GenericNodeData
{
    public MyNodeData(MyNaddr naddr) {base(naddr);}

    public override IQspnMyNaddr i_qspn_get_naddr_as_mine()
    {
        return (IQspnMyNaddr)naddr;
    }
}

public class OtherNodeData : GenericNodeData
{
    public OtherNodeData(MyNaddr naddr) {base(naddr);}

    public override IQspnMyNaddr i_qspn_get_naddr_as_mine()
    {
        assert(false); return null;
    }
}

public class MyREM : RTT, IQspnREM
{
    public MyREM(long usec_rtt) {base(usec_rtt);}

    public int i_qspn_compare_to(IQspnREM other)
    {
        return compare_to(other as MyREM);
    }

    public IQspnREM i_qspn_add_segment(IQspnREM other)
    {
        return new MyREM((other as MyREM).delay + delay);
    }
}

public class MyFingerprint : Netsukuku.FingerPrint, IQspnFingerprint
{
    public MyFingerprint(int id, int[] elderships)
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
        if (_other.level != level) return false;
        if (_other.elderships.length != elderships.length) return false;
        for (int i = 0; i < elderships.length; i++)
            if (_other.elderships[i] != elderships[i]) return false;
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
        return (sum as MyREM).delay * 1000;
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
    public MyArc(string dest, IQspnNodeData node_data, IQspnREM cost)
    {
        this.dest = dest;
        this.node_data = node_data;
        this.qspn_cost = cost;
    }
    public string dest {get; private set;}
    private IQspnNodeData node_data;
    private IQspnREM qspn_cost;

    public IQspnNodeData i_qspn_get_node_data() {return node_data;}
    public IQspnREM i_qspn_get_cost() {return qspn_cost;}
    public bool i_qspn_equals(IQspnArc other) {return this == (other as MyArc);}

    // unused stuff
    public INeighborhoodNodeID i_neighborhood_neighbour_id {get {assert(false); return null;}} // do not use in this fake
    public string i_neighborhood_mac {get {assert(false); return null;}} // do not use in this fake
    public REM i_neighborhood_cost {get {assert(false); return null;}} // do not use in this fake
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


int main(string[] args)
{
    // A network with 8 bits as address space. 3 to level 0, 2 to level 1, 3 to level 2.
    // Node 6 on gnode 2 on ggnode 1. PseudoIP 1.2.6
    MyNaddr addr1 = new MyNaddr({6, 2, 1}, {8, 4, 8});
    // PseudoIP 1.3.3
    MyNaddr addr2 = new MyNaddr({3, 3, 1}, {8, 4, 8});
    // PseudoIP 5.1.4
    MyNaddr addr3 = new MyNaddr({4, 1, 5}, {8, 4, 8});
    // fingerprints
    // first node in the network, also first g-node of level 2.
    MyFingerprint fp126 = new MyFingerprint(8378237, {0, 0, 0});
    // second in g-node 1
    MyFingerprint fp133 = new MyFingerprint(2384674, {0, 1, 0});
    // second g-node of level 2 in the network, first in g-node 5.
    MyFingerprint fp514 = new MyFingerprint(3466246, {0, 0, 1});
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
    MyNodeData me = null;
    OtherNodeData v1 = null;
    OtherNodeData v2 = null;
    MyArc arc1 = null;
    MyArc arc2 = null;
    IQspnFingerprint fp;
    if (args[1] == "1")
    {
        me = new MyNodeData(addr1);
        fp = fp126;
        v1 = new OtherNodeData(addr2);
        arc1 = new MyArc("192.168.0.62", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr3);
        arc2 = new MyArc("192.168.0.63", v2, new MyREM(1000));
    }
    else if (args[1] == "2")
    {
        me = new MyNodeData(addr2);
        fp = fp133;
        v1 = new OtherNodeData(addr1);
        arc1 = new MyArc("192.168.0.61", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr3);
        arc2 = new MyArc("192.168.0.63", v2, new MyREM(1000));
    }
    else if (args[1] == "3")
    {
        me = new MyNodeData(addr3);
        fp = fp514;
        v1 = new OtherNodeData(addr2);
        arc1 = new MyArc("192.168.0.62", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr1);
        arc2 = new MyArc("192.168.0.61", v2, new MyREM(1000));
    }
    else
    {
        return 1;
    }
    ArrayList<IQspnArc> arcs = new ArrayList<IQspnArc>();
    arcs.add(arc1);
    arcs.add(arc2);
    //
    QspnManager mgr = new QspnManager(me, 4, 0.7, arcs, fp, new MyArcToStub(), new MyFingerprintManager());

    return 0;
}

