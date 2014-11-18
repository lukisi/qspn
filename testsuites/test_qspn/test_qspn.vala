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
    public bool is_same_network(IQspnNetworkID other)
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

    public bool equals(IQspnNodeData other)
    {
        return id == (other as FakeNodeData).id;
    }

    public bool is_on_same_network(IQspnNodeData other)
    {
        return (other as FakeNodeData).netid.is_same_network(netid);
    }

    public IQspnNetworkID get_netid()
    {
        return netid;
    }

    public IQspnNaddr get_naddr()
    {
        return naddr;
    }

    public IQspnMyNaddr get_naddr_as_mine()
    {
        return (IQspnMyNaddr)naddr;
    }
}

public class FakeREM : Object, IQspnREM
{
    public int delay {get; private set;}
    public FakeREM(int delay)
    {
        this.delay = delay;
    }

    public int compare(IQspnREM other)
    {
        return (other as FakeREM).delay - delay;
    }

    public IQspnREM add_segment(IQspnREM other)
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

    public IQspnNodeData get_node_data()
    {
        return n;
    }

    public IQspnREM get_cost()
    {
        return cost;
    }

    public bool equals(IQspnArc other)
    {
        return n.equals((other as FakeArc).n);
    }
}

public class FakeFingerprint : Object, IQspnFingerprint
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

public class FakeFingerprintManager : Object, IQspnFingerprintManager
{
    public long mismatch_timeout_msec(IQspnREM sum)
    {
        return (sum as FakeREM).delay * 1000;
    }
}

public class FakeArcToStub : Object, IArcToStub
{
    public IAddressManagerRootDispatcher
                    get_broadcast(
                        IMissingArcHandler? missing_handler=null,
                        INodeID? ignore_neighbour=null
                    )
    {
        return null;
    }

    public IAddressManagerRootDispatcher
                    get_broadcast_to_nic(
                        INetworkInterface nic,
                        IMissingArcHandler? missing_handler=null,
                        INodeID? ignore_neighbour=null
                    )
    {
        return null;
    }

    public IAddressManagerRootDispatcher
                    get_unicast(
                        IArc arc,
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
        var f1 = new FakeFingerprint();
        var f2 = new FakeFingerprint();
        var f3 = new FakeFingerprint();
        var f4 = new FakeFingerprint();
        var flist = new ArrayList<IQspnFingerprint>();
        flist.add(f1);
        flist.add(f2);
        flist.add(f3);
        flist.add(f4);
        var fmgr = new FakeFingerprintManager();
        var tostub = new FakeArcToStub();
        // create module qspn
        var c = new QspnManager(n1, 2, 0.7, arclist, flist, tostub, fmgr);

    }
    assert(Tasklet.kill());
    return 0;
}

