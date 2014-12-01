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

public class FakeNetworkID : Object, IQspnNetworkID
{
    public bool i_qspn_is_same_network(IQspnNetworkID other)
    {
        return true;
    }
}

public class FakeNodeData : Object, IQspnNodeData
{
    public int id {get; private set;}
    public FakeNetworkID netid {get; private set;}
    public FakeGenericNaddr naddr {get; private set;}

    public FakeNodeData(FakeNetworkID netid)
    {
        id = Random.int_range(0, 10000);
        this.netid = netid;
        this.naddr = new FakeGenericNaddr({23, 1, 1, 1, 1, 1, 1, 1, 12});
    }

    public bool i_qspn_equals(IQspnNodeData other)
    {
        return id == (other as FakeNodeData).id;
    }

    public bool i_qspn_is_on_same_network(IQspnNodeData other)
    {
        return (other as FakeNodeData).netid.i_qspn_is_same_network(netid);
    }

    public IQspnNetworkID i_qspn_get_netid()
    {
        return netid;
    }

    public IQspnNaddr i_qspn_get_naddr()
    {
        return naddr;
    }

    public IQspnMyNaddr i_qspn_get_naddr_as_mine()
    {
        return (IQspnMyNaddr)naddr;
    }
}

public class FakeREM : RTT, IQspnREM
{
    public FakeREM(long usec_rtt) {base(usec_rtt);}

    public int i_qspn_compare_to(IQspnREM other)
    {
        return compare_to(other as FakeREM);
    }

    public IQspnREM i_qspn_add_segment(IQspnREM other)
    {
        return new FakeREM((other as FakeREM).delay + delay);
    }
}

public class FakeArc : Object, IQspnArc
{
    public IQspnNodeData n {get; private set;}
    public FakeREM cost {get; private set;}
    public FakeArc(IQspnNodeData n, int delay)
    {
        this.n = n;
        cost = new FakeREM(delay);
    }

    public IQspnNodeData i_qspn_get_node_data()
    {
        return n;
    }

    public IQspnREM i_qspn_get_cost()
    {
        return cost;
    }

    public bool i_qspn_equals(IQspnArc other)
    {
        return n.i_qspn_equals((other as FakeArc).n);
    }
}

public class FakeFingerprintManager : Object, IQspnFingerprintManager
{
    public long i_qspn_mismatch_timeout_msec(IQspnREM sum)
    {
        return (sum as FakeREM).delay * 1000;
    }
}

public class FakeArcToStub : Object, INeighborhoodArcToStub
{
    public IAddressManagerRootDispatcher
                    i_neighborhood_get_broadcast(
                        INeighborhoodMissingArcHandler? missing_handler=null,
                        INeighborhoodNodeID? ignore_neighbour=null
                    )
    {
        return null;
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_broadcast_to_nic(
                        INeighborhoodNetworkInterface nic,
                        INeighborhoodMissingArcHandler? missing_handler=null,
                        INeighborhoodNodeID? ignore_neighbour=null
                    )
    {
        return null;
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_unicast(
                        INeighborhoodArc arc,
                        bool wait_reply=true
                    )
    {
        return null;
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_tcp(
                        INeighborhoodArc arc,
                        bool wait_reply=true
                    )
    {
        return null;
    }
}

int main()
{
    // init tasklet
    assert(Tasklet.init());
    {
        var netid = new FakeNetworkID();
        var n1 = new FakeNodeData(netid);
        var n2 = new FakeNodeData(netid);
        var arc = new FakeArc(n2, 2);
        var arclist = new ArrayList<IQspnArc>();
        arclist.add(arc);
        var f1 = new FakeFingerprint(34346, {0, 0, 0, 0, 0, 0, 0, 0, 0});
        var fmgr = new FakeFingerprintManager();
        var tostub = new FakeArcToStub();
        // create module qspn
        var c = new QspnManager(n1, 2, 0.7, arclist, f1, tostub, fmgr);

    }
    assert(Tasklet.kill());
    return 0;
}

