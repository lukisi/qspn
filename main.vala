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

    public int get_levels()
    {
        return sizes.size;
    }

    public int get_gsize(int level)
    {
        return sizes[level];
    }

    public int get_pos(int level)
    {
        return pos[level];
    }

    public int get_level_of_gnode()
    {
        int l = 0;
        while (l < pos.size)
        {
            if (pos[l] >= 0) return l;
            l++;
        }
        return pos.size; // the whole network
    }

    public IQspnPartialNaddr get_address_by_coord(HCoord dest)
    {
        int[] newpos = new int[pos.size];
        for (int i = 0; i < dest.lvl; i++) newpos[i] = -1;
        for (int i = dest.lvl; i < 9; i++) newpos[i] = pos[i];
        newpos[dest.lvl] = dest.pos;
        return new MyNaddr(newpos, sizes.to_array());
    }

    public HCoord get_coord_by_address(IQspnPartialNaddr dest)
    {
        int l = pos.size-1;
        while (l >= 0)
        {
            if (pos[l] != dest.get_pos(l)) return new HCoord(l, dest.get_pos(l));
            l--;
        }
        // same naddr: error
        return new HCoord(-1, -1);
    }
}


public class MyNetworkID : Object, IQspnNetworkID
{
    public bool is_same_network(IQspnNetworkID other)
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

    public bool equals(IQspnNodeData other)
    {
        return this == (other as GenericNodeData);
    }

    public bool is_on_same_network(IQspnNodeData other)
    {
        return true;
    }

    public IQspnNetworkID get_netid()
    {
        return netid;
    }

    public IQspnNaddr get_naddr()
    {
        return (IQspnNaddr)naddr;
    }

    public abstract IQspnMyNaddr get_naddr_as_mine();
}

public class MyNodeData : GenericNodeData
{
    public MyNodeData(MyNaddr naddr) {base(naddr);}

    public override IQspnMyNaddr get_naddr_as_mine()
    {
        return (IQspnMyNaddr)naddr;
    }
}

public class OtherNodeData : GenericNodeData
{
    public OtherNodeData(MyNaddr naddr) {base(naddr);}

    public override IQspnMyNaddr get_naddr_as_mine()
    {
        assert(false); return null;
    }
}

public class MyREM : RTT, IQspnREM
{
    public MyREM(long usec_rtt) {base(usec_rtt);}

    public int qspn_compare_to(IQspnREM other)
    {
        return compare_to(other as MyREM);
    }

    public IQspnREM qspn_add_segment(IQspnREM other)
    {
        return new MyREM((other as MyREM).delay + delay);
    }
}

public class MyFingerprint : Object, IQspnFingerprint
{
    public bool equals(IQspnFingerprint other)
    {
        return other == this;
    }

    public bool is_elder(IQspnFingerprint other)
    {
        return true;
    }
}

public class MyFingerprintManager : Object, IQspnFingerprintManager
{
    public long mismatch_timeout_msec(IQspnREM sum)
    {
        return (sum as MyREM).delay * 1000;
    }
}

public class MyArcRemover : Object, IArcRemover
{
    public void i_arc_remover_remove(IArc arc)
    {
        assert(false); // do not use in this fake
    }
}

public class MyMissingArcHandler : Object, IMissingArcHandler
{
    public void missing(IArc arc, IArcRemover arc_remover)
    {
        // do nothing in this fake
    }
}

public class MyArc : Object, IArc, IQspnArc
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

    public IQspnNodeData get_node_data() {return node_data;}
    public IQspnREM qspn_get_cost() {return qspn_cost;}
    public bool qspn_equals(IQspnArc other) {return this == (other as MyArc);}

    // unused stuff
    public INeighborhoodNodeID neighbour_id {get {assert(false); return null;}} // do not use in this fake
    public string mac {get {assert(false); return null;}} // do not use in this fake
    public REM cost {get {assert(false); return null;}} // do not use in this fake
    public bool is_nic(INetworkInterface nic) {assert(false); return false;} // do not use in this fake
    public bool equals(IArc other) {assert(false); return false;} // do not use in this fake
}

public class MyArcToStub : Object, IArcToStub
{
    public IAddressManagerRootDispatcher get_broadcast
    (IMissingArcHandler? missing_handler=null,
     INeighborhoodNodeID? ignore_neighbour=null)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher get_broadcast_to_nic
    (INetworkInterface nic,
     IMissingArcHandler? missing_handler=null,
     INeighborhoodNodeID? ignore_neighbour=null)
    {
        assert(false); return null; // do not use in this fake
    }

    public IAddressManagerRootDispatcher get_unicast
    (IArc arc, bool wait_reply=true)
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
    MyFingerprint fp1 = new MyFingerprint();
    MyFingerprint fp12 = new MyFingerprint();
    MyFingerprint fp126 = new MyFingerprint();
    MyFingerprint fp13 = new MyFingerprint();
    MyFingerprint fp133 = new MyFingerprint();
    MyFingerprint fp5 = new MyFingerprint();
    MyFingerprint fp51 = new MyFingerprint();
    MyFingerprint fp514 = new MyFingerprint();
    ArrayList<MyFingerprint> fp_list = new ArrayList<MyFingerprint>();
    // nodes
    MyNodeData me = null;
    OtherNodeData v1 = null;
    OtherNodeData v2 = null;
    MyArc arc1 = null;
    MyArc arc2 = null;
    if (args[1] == "1")
    {
        me = new MyNodeData(addr1);
        fp_list.add(fp126);
        fp_list.add(fp12);
        fp_list.add(fp1);
        v1 = new OtherNodeData(addr2);
        arc1 = new MyArc("192.168.0.62", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr3);
        arc2 = new MyArc("192.168.0.63", v2, new MyREM(1000));
    }
    else if (args[1] == "2")
    {
        me = new MyNodeData(addr2);
        fp_list.add(fp133);
        fp_list.add(fp13);
        fp_list.add(fp1);
        v1 = new OtherNodeData(addr1);
        arc1 = new MyArc("192.168.0.61", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr3);
        arc2 = new MyArc("192.168.0.63", v2, new MyREM(1000));
    }
    else if (args[1] == "3")
    {
        me = new MyNodeData(addr3);
        fp_list.add(fp514);
        fp_list.add(fp51);
        fp_list.add(fp5);
        v1 = new OtherNodeData(addr2);
        arc1 = new MyArc("192.168.0.62", v1, new MyREM(1000));
        v2 = new OtherNodeData(addr1);
        arc2 = new MyArc("192.168.0.61", v2, new MyREM(1000));
    }
    ArrayList<IQspnArc> arcs = new ArrayList<IQspnArc>();
    arcs.add(arc1);
    arcs.add(arc2);
    //
    QspnManager mgr = new QspnManager(me, 4, 0.7, arcs, fp_list, new MyArcToStub(), new MyFingerprintManager());

    return 0;
}

