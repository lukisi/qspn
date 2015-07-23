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
using Tasklets;

const uint16 ntkd_port = 60269;

public class MyNodeID : Object, zcd.ModRpc.ISerializable, INeighborhoodNodeID
{
    public int id {get; set;}
    public int netid {get; set;}
    public MyNodeID(int id, int netid)
    {
        this.id = id;
        this.netid = netid;
    }

    public bool check_deserialization()
    {
        return id != 0 && netid != 0;
    }

    public bool i_neighborhood_equals(INeighborhoodNodeID other)
    {
        if (!(other is MyNodeID)) return false;
        return id == (other as MyNodeID).id;
    }

    public bool i_neighborhood_is_on_same_network(INeighborhoodNodeID other)
    {
        if (!(other is MyNodeID)) return false;
        return netid == (other as MyNodeID).netid;
    }
}

Gee.List<IQspnArc> current_arcs_for_broadcast
(BroadcastID bcid,
    Gee.Collection<string> devs)
{
    var ret = new ArrayList<IQspnArc>();
    foreach (FakeArc arc in my_arcs)
    {
        // test arc against bcid (e.g. ignore_neighbour)
        if (bcid.ignore_nodeid != null)
        {
            MyNodeID ignore_nodeid = (MyNodeID)bcid.ignore_nodeid;
            if (arc.nodeid == ignore_nodeid.id) continue;
        }
        // test arc against devs.
        if (! (arc.dev in devs)) continue;
        // This should receive
        ret.add(arc);
    }
    return ret;
}

class MyStubFactory: Object, IQspnStubFactory
{
    public IAddressManagerStub
    i_qspn_get_broadcast
    (IQspnMissingArcHandler? missing_handler=null, IQspnArc? ignore_neighbor=null)
    {
        BroadcastID bcid;
        if (ignore_neighbor != null)
        {
            FakeArc a = (FakeArc)ignore_neighbor;
            MyNodeID ignore_id = new MyNodeID(a.nodeid, 1);
            bcid = new BroadcastID(ignore_id);
        }
        else bcid = new BroadcastID();
        ArrayList<string> devs = new ArrayList<string>(); devs.add_all(t_udp_map.keys);
        IAddressManagerStub ret;
        if (missing_handler == null)
        {
            ret = Netsukuku.ModRpc.get_addr_broadcast(devs, ntkd_port, bcid);
        }
        else
        {
            Gee.List<IQspnArc> lst_expected = current_arcs_for_broadcast(bcid, devs);
            MyAckComm notify_ack = new MyAckComm(bcid, devs, missing_handler, lst_expected);
            ret = Netsukuku.ModRpc.get_addr_broadcast(devs, ntkd_port, bcid, notify_ack);
        }
        return ret;
    }

    private class MyAckComm : Object, zcd.ModRpc.IAckCommunicator
    {
        public BroadcastID bcid;
        public Gee.List<string> devs;
        public IQspnMissingArcHandler missing_handler;
        public Gee.List<IQspnArc> lst_expected;

        public MyAckComm
        (BroadcastID bcid,
            Gee.Collection<string> devs,
            IQspnMissingArcHandler missing_handler,
            Gee.List<IQspnArc> lst_expected)
        {
            this.bcid = bcid;
            this.devs = new ArrayList<string>();
            this.devs.add_all(devs);
            this.missing_handler = missing_handler;
            this.lst_expected = new ArrayList<IQspnArc>();
            this.lst_expected.add_all(lst_expected);
        }

        public void process_macs_list(Gee.List<string> responding_macs)
        {
            // intersect with current ones now
            Gee.List<IQspnArc> lst_expected_now = current_arcs_for_broadcast(bcid, devs);
            Gee.List<IQspnArc> lst_expected_intersect = new ArrayList<IQspnArc>();
            foreach (var el in lst_expected)
                if (el in lst_expected_now)
                    lst_expected_intersect.add(el);
            lst_expected = lst_expected_intersect;
            // prepare a list of missed arcs.
            var lst_missed = new ArrayList<IQspnArc>();
            foreach (IQspnArc expected in lst_expected)
            {
                FakeArc _expected = (FakeArc)expected;
                if (! (_expected.neighbour_mac in responding_macs))
                    lst_missed.add(expected);
            }
            // foreach missed arc launch in a tasklet
            // the 'missing' callback.
            foreach (IQspnArc missed in lst_missed)
            {
                ActOnMissingTasklet ts = new ActOnMissingTasklet();
                ts.missing_handler = missing_handler;
                ts.missed = missed;
                ntkd_tasklet.spawn(ts);
            }
        }

        private class ActOnMissingTasklet : Object, INtkdTaskletSpawnable
        {
            public IQspnMissingArcHandler missing_handler;
            public IQspnArc missed;
            public void * func()
            {
                missing_handler.i_qspn_missing(missed);
                return null;
            }
        }
    }

    public IAddressManagerStub
    i_qspn_get_tcp
    (IQspnArc arc, bool wait_reply=true)
    {
        FakeArc _arc = (FakeArc)arc;
        string addr = _arc.neighbour_nic_addr;
        return Netsukuku.ModRpc.get_addr_tcp_client(addr, ntkd_port);
    }
}

class FakeThresholdCalculator : Object, IQspnThresholdCalculator
{
    public int i_qspn_calculate_threshold(IQspnNodePath p1, IQspnNodePath p2)
    {
        return 10000;
    }
}

class FakeArc : Object, IQspnArc
{
    public FakeGenericNaddr naddr;
    public int nodeid;
    public string neighbour_mac;
    public FakeCost cost;
    public string neighbour_nic_addr;
    public string my_nic_addr;
    public string dev;
    public FakeArc(FakeGenericNaddr naddr,
                   int nodeid,
                   string neighbour_mac,
                   FakeCost cost,
                   string neighbour_nic_addr,
                   string my_nic_addr,
                   string dev)
    {
        this.naddr = naddr;
        this.nodeid = nodeid;
        this.neighbour_mac = neighbour_mac;
        this.cost = cost;
        this.neighbour_nic_addr = neighbour_nic_addr;
        this.my_nic_addr = my_nic_addr;
        this.dev = dev;
    }

    public IQspnCost i_qspn_get_cost()
    {
        return cost;
    }

    public IQspnNaddr i_qspn_get_naddr()
    {
        return naddr;
    }

    public bool i_qspn_equals(IQspnArc _other)
    {
        FakeArc other = (FakeArc)_other;
        return neighbour_nic_addr == other.neighbour_nic_addr && my_nic_addr == other.my_nic_addr;
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

public class AddressManager : FakeAddressManagerSkeleton
{
    public QspnManager qspn_manager;
    public override unowned IQspnManagerSkeleton qspn_manager_getter()
    {
        return qspn_manager;
    }
}
AddressManager? address_manager;

class MyServerDelegate : Object, ModRpc.IRpcDelegate
{
    public MyServerDelegate(INeighborhoodNodeID id)
    {
        this.id = id;
    }
    private INeighborhoodNodeID id;

    public ModRpc.IAddressManagerSkeleton? get_addr(zcd.ModRpc.CallerInfo caller)
    {
        assert(address_manager != null);
        if (caller is zcd.ModRpc.TcpCallerInfo)
        {
            return address_manager;
        }
        else if (caller is ModRpc.UnicastCallerInfo)
        {
            ModRpc.UnicastCallerInfo c = (ModRpc.UnicastCallerInfo)caller;
            if (c.unicastid.nodeid.i_neighborhood_equals(id))
            {
                // got from nic ... which has MAC ...
                string my_mac = macgetter.get_mac(c.dev).up();
                if (c.unicastid.mac == my_mac)
                {
                    return address_manager;
                }
            }
            return null;
        }
        else if (caller is ModRpc.BroadcastCallerInfo)
        {
            ModRpc.BroadcastCallerInfo c = (ModRpc.BroadcastCallerInfo)caller;
            if (c.broadcastid.ignore_nodeid != null)
                if (c.broadcastid.ignore_nodeid.i_neighborhood_equals(id))
                    return null;
            return address_manager;
        }
        else
        {
            error(@"Unexpected class $(caller.get_type().name())");
        }
    }
}

class MyServerErrorHandler : Object, zcd.ModRpc.IRpcErrorHandler
{
    public void error_handler(Error e)
    {
        error(@"error_handler: $(e.message)");
    }
}

zcd.IZcdTasklet zcd_tasklet;
Netsukuku.INtkdTasklet ntkd_tasklet;

int mynodeid;
string naddr;
string gsizes;
string elderships;
[CCode (array_length = false, array_null_terminated = true)]
string[] interfaces;
bool go;

int main(string[] args)
{
    go = false; // default
    mynodeid = -1;
    OptionContext oc = new OptionContext();
    OptionEntry[] entries = new OptionEntry[7];
    int index = 0;
    entries[index++] = {"nodeid", 'n', 0, OptionArg.INT, ref mynodeid, "My node ID. unique number.", null};
    entries[index++] = {"naddr", 'a', 0, OptionArg.STRING, ref naddr, "My Netsukuku Address, dotted-form.", null};
    entries[index++] = {"gsizes", 's', 0, OptionArg.STRING, ref gsizes, "Sizes of groups, dotted-form.", null};
    entries[index++] = {"elderships", 'e', 0, OptionArg.STRING, ref elderships, "My elderships, dotted-form", null};
    entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface and its nic_addr (only last 2 octets) coma-separated. e.g. -i eth1,11.22. You can use it multiple times.", null};
    entries[index++] = {"go", 'g', 0, OptionArg.NONE, ref go, "Start immediately as new network", null};
    entries[index++] = { null };
    oc.add_main_entries(entries, null);
    try {
        oc.parse(ref args);
    }
    catch (OptionError e) {
        print(@"Error parsing options: $(e.message)\n");
        return 1;
    }

    if (mynodeid == -1) error("You have to set your nodeid (option -n)");
    if (naddr == null || naddr == "") error("You have to set your address (option -a)");
    if (gsizes == null || gsizes == "") error("You have to set sizes of groups (option -s)");
    if (elderships == null || elderships == "") error("You have to set your elderships (option -e)");
    ArrayList<int> _naddr = new ArrayList<int>();
    net_gsizes = new ArrayList<int>();
    ArrayList<int> _elderships = new ArrayList<int>();
    foreach (string s_piece in naddr.split(".")) _naddr.insert(0, int.parse(s_piece));
    foreach (string s_piece in gsizes.split(".")) net_gsizes.insert(0, int.parse(s_piece));
    foreach (string s_piece in elderships.split(".")) _elderships.insert(0, int.parse(s_piece));
    if (_naddr.size != net_gsizes.size || _naddr.size != _elderships.size) error("You have to use same number of levels");
    my_naddr = new FakeGenericNaddr(_naddr.to_array(), net_gsizes.to_array());
    my_fp = new FakeFingerprint(_elderships.to_array());
    my_arcs = new ArrayList<FakeArc>((a, b) => a.i_qspn_equals(b));
    my_routes = new HashMap<string, Route>();
    my_destinations = new ArrayList<string>();
    if (interfaces.length == 0) error("You have to handle some NICs (option -i)");
    nic_addr_map = new HashMap<string, string>();
    foreach (string dev_def in interfaces)
    {
        string dev = dev_def.split(",")[0];
        string nic_addr = dev_def.split(",")[1];
        nic_addr = @"169.254.$(nic_addr)";
        nic_addr_map[dev] = nic_addr;
    }

    // Initialize tasklet system
    MyTaskletSystem.init();
    zcd_tasklet = MyTaskletSystem.get_zcd();
    ntkd_tasklet = MyTaskletSystem.get_ntkd();

    // Initialize known serializable classes
    typeof(MyNodeID).class_peek();
    typeof(UnicastID).class_peek();
    typeof(BroadcastID).class_peek();
    // Pass tasklet system to ModRpc (and ZCD)
    zcd.ModRpc.init_tasklet_system(zcd_tasklet);
    // Pass tasklet system to module neighborhood
    QspnManager.init(ntkd_tasklet);

    // instantiate delegate in order to be able to listen on the NICs
    my_id = new MyNodeID(mynodeid, 1);
    print_my_nodeid();
    print_my_macs();
    dlg = new MyServerDelegate(my_id);
    err = new MyServerErrorHandler();

    // Listen to the NICs and assign nic-address
    t_udp_map = new HashMap<string, zcd.IZcdTaskletHandle>();
    t_tcp_map = new HashMap<string, zcd.IZcdTaskletHandle>();
    foreach (string dev in nic_addr_map.keys)
    {
        string nic_addr = nic_addr_map[dev];
        assert(! t_udp_map.has_key(dev));
        t_udp_map[dev] = Netsukuku.ModRpc.udp_listen(dlg, err, ntkd_port, dev);
        try {
            CommandResult com_ret = Tasklet.exec_command(@"ip address add $(nic_addr) dev $(dev)");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
        } catch (SpawnError e) {error("Unable to spawn a command");}
        t_tcp_map[dev] = Netsukuku.ModRpc.tcp_listen(dlg, err, ntkd_port, nic_addr);
    }

    {
        if (go) run_manager();

        // start a tasklet to get commands from stdin.
        CommandLineInterfaceTasklet ts = new CommandLineInterfaceTasklet();
        ntkd_tasklet.spawn(ts);

        // register handlers for SIGINT and SIGTERM to exit
        Posix.signal(Posix.SIGINT, safe_exit);
        Posix.signal(Posix.SIGTERM, safe_exit);
        // Main loop
        while (true)
        {
            zcd_tasklet.ms_wait(100);
            if (do_me_exit) break;
        }
    }
    if (address_manager != null) stop_manager();
    remove_handlers();
    MyTaskletSystem.kill();
    print("\nExiting.\n");
    return 0;
}

bool do_me_exit = false;
void safe_exit(int sig)
{
    // We got here because of a signal. Quick processing.
    do_me_exit = true;
}

class CommandLineInterfaceTasklet : Object, INtkdTaskletSpawnable
{
    public void * func()
    {
        try {
            while (true)
            {
                print("Ok> ");
                uint8 buf[256];
                size_t len = Tasklet.read(0, (void*)buf, buf.length);
                if (len > 255) error("Error during read of CLI: line too long");
                string line = (string)buf;
                if (line.has_suffix("\n")) line = line.substring(0, line.length-1);
                ArrayList<string> _args = new ArrayList<string>();
                foreach (string s_piece in line.split(" ")) _args.add(s_piece);
                if (_args.size == 0)
                {}
                else if (_args[0] == "a" && _args.size == 7)
                {
                    add_arc(_args[1], @"169.254.$(_args[2])", _args[3], int.parse(_args[6]), int64.parse(_args[4]), _args[5]);
                }
                else if (_args[0] == "c" && _args.size == 3)
                {
                    changed_arc(@"169.254.$(_args[1])", int64.parse(_args[2]));
                }
                else if (_args[0] == "r" && _args.size == 2)
                {
                    remove_arc(@"169.254.$(_args[1])");
                }
                else if (_args[0] == "i" && _args.size == 1)
                {
                    print_my_nodeid();
                    print_my_macs();
                    string arcs = " ";
                    foreach (FakeArc a in my_arcs)
                    {
                        string n_ip = arc_dotted_form(a);
                        arcs += @"$(a.dev),$(a.neighbour_mac),$(n_ip) ";
                    }
                    print(@"Arcs: [$(arcs)]\n");
                    if (address_manager == null) print("Not started.\n");
                    else
                    {
                        print("Started.\n");
                        print(@"Routes: $(my_routes.keys.size)\n");
                        foreach (string dst in my_routes.keys)
                        {
                            Route r = my_routes[dst];
                            print(@" $(dst) gw $(r.gw) dev $(r.dev)\n");
                        }
                    }
                }
                else if (_args[0] == "g" && _args.size == 1)
                {
                    run_manager();
                }
                else if (_args[0] == "help")
                {
                    print("""
Command list:

> a <dev> <neighbor_nic_addr> <neighbor_mac> <usec_rtt> <neighbor's Netsukuku address> <neighbor's ID>
  Adds an arc to a neighbor, specifying data for my NIC and its NIC.
  You can give this command before or after command 'g'.
  e.g. a eth1 23.112 CC:AF:78:2E:C8:B6 1050 8.1.0.0.0.1 37629

> c <neighbor_nic_addr> <usec_rtt>
  Changes the cost of an arc.
  You can give this command only after command 'g'.
  e.g. c 23.112 900

> r <neighbor_nic_addr>
  Removes an arc.
  You can give this command only after command 'g'.
  e.g. c 23.112

> i
  Prints information about this node.

> g
  Runs the qspn manager.

> help
  Shows this menu.

> Ctrl-C
  Exits.

""");
                }
                else
                {
                    print("CLI: unknown command\n");
                }
            }
        } catch (Error e) {
            error(@"Error during read of CLI: $(e.message)");
        }
    }
}

// Delegates
MyServerDelegate dlg;
MyServerErrorHandler err;
// Handles for UDP and TCP
HashMap<string, zcd.IZcdTaskletHandle> t_udp_map;
HashMap<string, zcd.IZcdTaskletHandle> t_tcp_map;
// My node stuff
INeighborhoodNodeID my_id;
HashMap<string, string> nic_addr_map;
FakeGenericNaddr my_naddr;
ArrayList<int> net_gsizes;
ArrayList<string> my_addresses;
FakeFingerprint my_fp;
ArrayList<FakeArc> my_arcs;
ArrayList<string> my_destinations;
HashMap<string, DispatchableTasklet> my_destinations_dispatchers;
HashMap<string, Route> my_routes;

class Route : Object
{
    public Route(string dest, string gw, string dev, string? prevmac=null)
    {
        this.prevmac = prevmac;
        this.dest = dest;
        this.gw = gw;
        this.dev = dev;
    }
    public string? prevmac;
    public string dest;
    public string gw;
    public string dev;
}

const int max_paths = 5;
const double max_common_hops_ratio = 0.6;
const int arc_timeout = 10000;

void add_arc(string dev, string n_nic_addr, string neighbour_mac, int nodeid, int64 usec_rtt, string n_addr)
{
    if (! nic_addr_map.has_key(dev))
    {
        print(@"not handled device $(dev).\n");
        return;
    }
    string nic_addr = nic_addr_map[dev];
    ArrayList<int> _naddr = new ArrayList<int>();
    foreach (string s_piece in n_addr.split(".")) _naddr.insert(0, int.parse(s_piece));
    if (_naddr.size != net_gsizes.size)
    {
        print("You have to use same number of levels.\n");
        return;
    }
    FakeCost c = new FakeCost(usec_rtt);
    FakeGenericNaddr n_naddr = new FakeGenericNaddr(_naddr.to_array(), net_gsizes.to_array());
    FakeArc arc = new FakeArc(n_naddr, nodeid, neighbour_mac, c, n_nic_addr, nic_addr, dev);
    my_arcs.add(arc);
    try {
        CommandResult com_ret = Tasklet.exec_command(@"ip route add $(n_nic_addr) dev $(dev) src $(nic_addr)");
        if (com_ret.exit_status != 0)
            error(@"$(com_ret.cmderr)\n");
    } catch (SpawnError e) {error("Unable to spawn a command");}
    if (address_manager != null)
    {
        address_manager.qspn_manager.arc_add(arc);
    }
}

public void print_my_nodeid()
{
    MyNodeID id = (MyNodeID)my_id;
    print(@"My NodeID = $(id.id)\nIn network $(id.netid)\n");
}

public void print_my_macs()
{
    foreach (string dev in nic_addr_map.keys)
    {
        string nic_addr = nic_addr_map[dev];
        string mac = macgetter.get_mac(dev).up();
        print(@"Handling NIC: name $(dev) hw_addr $(mac) ip_addr $(nic_addr)\n");
    }
}

void changed_arc(string n_nic_addr, int64 usec_rtt)
{
    assert(address_manager != null);
    FakeArc? found = null;
    int i;
    for (i = 0; i < my_arcs.size; i++)
    {
        if (my_arcs[i].neighbour_nic_addr == n_nic_addr)
        {
            found = my_arcs[i];
            break;
        }
    }
    assert(found != null);
    string dev = found.dev;
    string my_nic_addr = found.my_nic_addr;
    string neighbour_mac = found.neighbour_mac;
    FakeGenericNaddr n_naddr = found.naddr;
    int nodeid = found.nodeid;
    FakeCost c = new FakeCost(usec_rtt);
    FakeArc arc = new FakeArc(n_naddr, nodeid, neighbour_mac, c, n_nic_addr, my_nic_addr, dev);
    my_arcs[i] = arc;
    address_manager.qspn_manager.arc_is_changed(arc);
}

void remove_arc(string n_nic_addr)
{
    assert(address_manager != null);
    FakeArc? found = null;
    int i;
    for (i = 0; i < my_arcs.size; i++)
    {
        if (my_arcs[i].neighbour_nic_addr == n_nic_addr)
        {
            found = my_arcs[i];
            break;
        }
    }
    assert(found != null);
    address_manager.qspn_manager.arc_remove(found);
    my_arcs.remove_at(i);
}

void run_manager()
{
    assert(address_manager == null);

    // create manager
    address_manager = new AddressManager();
    // create module qspn
    address_manager.qspn_manager =
        new QspnManager(my_naddr,
                        max_paths,
                        max_common_hops_ratio,
                        arc_timeout,
                        my_arcs,
                        my_fp,
                        new FakeThresholdCalculator(),
                        new MyStubFactory());
    // connect signals
    address_manager.qspn_manager.failed_hook.connect(() => {
        // The hook on a particular network has failed.
        print("\nFailed hook.\n");
        do_me_exit = true;
    });
    address_manager.qspn_manager.qspn_bootstrap_complete.connect(() => {
        // The hook on a particular network has completed; the module is bootstrap_complete.
        print("\nBootstrap completed.\n");
        Gee.List<HCoord> dests;
        try {
            dests = address_manager.qspn_manager.get_known_destinations();
        } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
        foreach (HCoord dest in dests)
            update_routes_to_dest(dest);
    });
    address_manager.qspn_manager.arc_removed.connect((_arc) => {
        // An arc (is not working) has been removed from my list.
        IQspnArc arc = _arc;
        FakeArc a = (FakeArc)arc;
        string n_ip = arc_dotted_form(a);
        print(@"\nAn arc removed: $(a.dev),$(a.neighbour_mac),$(n_ip).\n");
        if (a in my_arcs) my_arcs.remove(a);
    });
    address_manager.qspn_manager.destination_added.connect((_d) => {
        // A gnode (or node) is now known on the network and the first path towards
        //  it is now available to this node.
        IQspnPartialNaddr d = _d;
        string dest = dotted_form(d);
        print(@"\nA destination added: $(dest).\n");
        if (! my_destinations_dispatchers.has_key(dest))
        {
            my_destinations_dispatchers[dest] = new DispatchableTasklet(ntkd_tasklet);
        }
        DispatchableTasklet dt = my_destinations_dispatchers[dest];
        DestinationAddedTasklet ts = new DestinationAddedTasklet();
        ts.dest = dest;
        ts.d = d;
        dt.dispatch(ts);
    });
    address_manager.qspn_manager.destination_removed.connect((_d) => {
        // A gnode (or node) has been removed from the network and the last path
        //  towards it has been deleted from this node.
        IQspnPartialNaddr d = _d;
        string dest = dotted_form(d);
        print(@"\nA destination removed: $(dest).\n");
        if (! my_destinations_dispatchers.has_key(dest))
        {
            my_destinations_dispatchers[dest] = new DispatchableTasklet(ntkd_tasklet);
        }
        DispatchableTasklet dt = my_destinations_dispatchers[dest];
        DestinationRemovedTasklet ts = new DestinationRemovedTasklet();
        ts.dest = dest;
        ts.d = d;
        dt.dispatch(ts, true);
        if (dt.is_empty()) my_destinations_dispatchers.unset(dest);
    });
    address_manager.qspn_manager.path_added.connect((_p) => {
        // A new path (might be the first) to a destination has been found.
        IQspnNodePath p = _p;
        string dest = dotted_form(p.i_qspn_get_hops().last().i_qspn_get_naddr());
        print(@"\nA path added to $(dest).\n");
        update_routes(p);
    });
    address_manager.qspn_manager.path_changed.connect((_p) => {
        // A path to a destination has changed.
        IQspnNodePath p = _p;
        string dest = dotted_form(p.i_qspn_get_hops().last().i_qspn_get_naddr());
        print(@"\nA path changed to $(dest).\n");
        update_routes(p);
    });
    address_manager.qspn_manager.path_removed.connect((_p) => {
        // A path (might be the last) to a destination has been deleted.
        IQspnNodePath p = _p;
        string dest = dotted_form(p.i_qspn_get_hops().last().i_qspn_get_naddr());
        print(@"\nA path removed to $(dest).\n");
        update_routes(p);
    });
    address_manager.qspn_manager.changed_fp.connect((_l) => {
        // My g-node of level l changed its fingerprint.
        int l = _l;
        print(@"\nA change in my fingerprints at level $(l).\n");
        // TODO
    });
    address_manager.qspn_manager.changed_nodes_inside.connect((_l) => {
        // My g-node of level l changed its nodes_inside.
        int l = _l;
        print(@"\nA change in my nodes_inside at level $(l).\n");
        // TODO
    });
    address_manager.qspn_manager.gnode_splitted.connect((_a, _d, _fp) => {
        // A gnode has splitted and the part which has this fingerprint MUST migrate.
        IQspnArc a = _a;
        HCoord d = _d;
        IQspnFingerprint fp = _fp;
        print(@"\nA g-node split.\n");
        // TODO
    });

    // Addresses:
    my_addresses = new ArrayList<string>();
    //  * base
    my_addresses.add(dotted_form(my_naddr, -1, false, true));
    //  * base (anonymous form)
    my_addresses.add(dotted_form(my_naddr, -1, true, true));
    for (int inside_level = my_naddr.i_qspn_get_levels() - 1; inside_level > 0; inside_level--)
    {
        //  * internal in inside_level
        my_addresses.add(dotted_form(my_naddr, inside_level, false, true));
        //  * internal in inside_level (anonymous form)
        my_addresses.add(dotted_form(my_naddr, inside_level, true, true));
    }
    foreach (string dev in nic_addr_map.keys) foreach (string s in my_addresses)
    {
        try {
            CommandResult com_ret = Tasklet.exec_command(@"ip address add $(s) dev $(dev)");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
        } catch (SpawnError e) {error("Unable to spawn a command");}
    }
}

void update_routes(IQspnNodePath p)
{
    IQspnHop f = p.i_qspn_get_hops().last();
    IQspnPartialNaddr d = f.i_qspn_get_naddr();
    HCoord h = my_naddr.i_qspn_get_coord_by_address(d);
    update_routes_to_dest(h);
}

void update_routes_to_dest(HCoord h)
{
    IQspnPartialNaddr d = my_naddr.i_qspn_get_address_by_coord(h);
    string dest = dotted_form(d);
    if (! my_destinations_dispatchers.has_key(dest))
    {
        my_destinations_dispatchers[dest] = new DispatchableTasklet(ntkd_tasklet);
    }
    DispatchableTasklet dt = my_destinations_dispatchers[dest];
    UpdateRoutesTasklet ts = new UpdateRoutesTasklet();
    ts.dest = dest;
    ts.d = d;
    dt.dispatch(ts);
}

class DestinationAddedTasklet : Object, INtkdTaskletSpawnable
{
    public string dest;
    public IQspnPartialNaddr d;
    public void * func()
    {
        if (dest in my_destinations)
            warning(@"DestinationAddedTasklet: $(dest) was already present.");
        else my_destinations.add(dest);
        return null;
    }
}

class DestinationRemovedTasklet : Object, INtkdTaskletSpawnable
{
    public string dest;
    public IQspnPartialNaddr d;
    public void * func()
    {
        if (! (dest in my_destinations))
            warning(@"DestinationRemovedTasklet: $(dest) was not present.");
        else my_destinations.remove(dest);
        return null;
    }
}

class NeighborData : Object
{
    public string mac;
    public FakeGenericNaddr d_as_partial;
}

class UpdateRoutesTasklet : Object, INtkdTaskletSpawnable
{
    public string dest;
    public IQspnPartialNaddr d;
    public void * func()
    {
        HashMap<string, Route> new_routes = new HashMap<string, Route>();
        Gee.List<IQspnNodePath> paths;
        try {
            paths =
                address_manager.qspn_manager.get_paths_to(my_naddr.i_qspn_get_coord_by_address(d));
        } catch (QspnBootstrapInProgressError e) {
            // not available yet
            print("UpdateRoutesTasklet: bootstrap not completed yet\n");
            return null;
        }
        string dest = dotted_form(d);
        ArrayList<NeighborData> neighbors = new ArrayList<NeighborData>();
        foreach (FakeArc arc in my_arcs)
        {
            NeighborData neighbor = new NeighborData();
            neighbor.mac = arc.neighbour_mac;
            neighbor.d_as_partial = (FakeGenericNaddr)my_naddr.i_qspn_get_address_by_coord(
                    my_naddr.i_qspn_get_coord_by_address(arc.naddr));
            neighbors.add(neighbor);
        }
        foreach (IQspnNodePath path in paths)
        {
            FakeArc path_arc = (FakeArc)path.i_qspn_get_arc();
            string path_dev = path_arc.dev;
            if (new_routes.is_empty)
            {
                // absolute best
                string k = @"$(dest)_main";
                string gw = arc_dotted_form(path_arc);
                Route r = new Route(dest, gw, path_dev);
                new_routes[k] = r;
            }
            bool completed = true;
            foreach (NeighborData neighbor in neighbors)
            {
                // is it best without neighbor?
                string k = @"$(dest)_$(neighbor.mac)";
                // new_routes contains k?
                if (new_routes.has_key(k)) continue;
                // path contains neighbor's g-node?
                ArrayList<FakeGenericNaddr> searchable_path = new ArrayList<FakeGenericNaddr>((a, b) => a.equals(b));
                foreach (IQspnHop path_h in path.i_qspn_get_hops())
                    searchable_path.add((FakeGenericNaddr)path_h.i_qspn_get_naddr());
                if (neighbor.d_as_partial in searchable_path)
                {
                    completed = false;
                    continue;
                }
                // best without neighbor.
                string gw = arc_dotted_form(path_arc);
                Route r = new Route(dest, gw, path_dev);
                new_routes[k] = r;
            }
            if (completed) break;
        }
        // TODO
        /*
   * richiedere al qspn_manager l'elenco delle path verso la destinazione,
     cercare la migliore in assoluto e per ogni prevmac la migliore
     che non passa mai per il suo g-nodo. Esprimerle in una mappa new_routes
     fatta come la my_routes.
   * sulla base degli oggetti Route presenti in my_routes e in new_routes,
     effettuare sul s.o. le operazioni per aggiornare le rotte nel kernel.
   * modificare gli elementi di my_routes per renderli come new_routes.
        */
        return null;
    }
}

string dotted_form(IQspnPartialNaddr naddr, int inside_level=-1, bool anonymous_form=false, bool omit_suffix=false)
{
    int i = 0;
    int multiplier = 1;
    int levels = naddr.i_qspn_get_levels();
    int level_of_gnode = naddr.i_qspn_get_level_of_gnode();
    int class_size = 1;
    for (int j = 0; j < levels; j++)
    {
        int pos_j;
        if (j == level_of_gnode) class_size = multiplier;
        if (j >= level_of_gnode) pos_j = naddr.i_qspn_get_pos(j);
        else pos_j = 0;
        if (inside_level != -1 && j == levels-1)
        {
            i += inside_level * multiplier;
        }
        else if (inside_level == -1 || inside_level > j)
        {
            i += pos_j * multiplier;
        }
        int gsize = naddr.i_qspn_get_gsize(j);
        multiplier *= gsize;
    }
    if (anonymous_form) i += multiplier;
    multiplier *= 2;
    if (inside_level != -1) i += multiplier;

    int suffix = 32 - (int)(Math.floor( Math.log2( class_size ) ));
    int i0 = i % 256;
    i /= 256;
    int i1 = i % 256;
    i /= 256;
    int i2 = i;
    string ret = @"10.$(i2).$(i1).$(i0)";
    if (!omit_suffix) ret = @"$(ret)/$(suffix)";
    return ret;
}

string arc_dotted_form(FakeArc a, bool include_suffix=false)
{
    return dotted_form(a.naddr, -1, false, !include_suffix);
}

void stop_manager()
{
    assert(address_manager != null);

    // TODO remove routes

    // remove my addresses
    foreach (string dev in nic_addr_map.keys) foreach (string s in my_addresses)
    {
        try {
            CommandResult com_ret = Tasklet.exec_command(@"ip address del $(s)/32 dev $(dev)");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
        } catch (SpawnError e) {error("Unable to spawn a command");}
    }

    address_manager.qspn_manager = null;
    address_manager = null;
}

void remove_handlers()
{
    ArrayList<string> devs = new ArrayList<string>(); devs.add_all(t_udp_map.keys);
    foreach (string dev in devs)
    {
        string nic_addr = nic_addr_map[dev];
        assert(t_udp_map.has_key(dev));
        t_udp_map[dev].kill();
        t_udp_map.unset(dev);
        try {
            CommandResult com_ret = Tasklet.exec_command(@"ip address del $(nic_addr)/32 dev $(dev)");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
        } catch (SpawnError e) {error("Unable to spawn a command");}
        assert(t_tcp_map.has_key(dev));
        t_tcp_map[dev].kill();
        t_tcp_map.unset(dev);
    }
}

public class DispatchableTasklet
{
    private class DispatchedTasklet : Object
    {
        public INtkdChannel ch;
        public INtkdTaskletSpawnable sp;
    }
    private class DispatcherTasklet : Object, INtkdTaskletSpawnable
    {
        public DispatchableTasklet dsp;
        public void * func()
        {
            while (dsp.lst_sp.size > 0)
            {
                DispatchedTasklet x = dsp.lst_sp.remove_at(0);
                x.sp.func();
                if (x.ch.get_balance() < 0) x.ch.send_async(0);
            }
            return null;
        }
    }
    private INtkdTaskletHandle? t;
    private ArrayList<DispatchedTasklet> lst_sp;
    private INtkdTasklet tasklet;
    public DispatchableTasklet(INtkdTasklet tasklet)
    {
        this.tasklet = tasklet;
        t = null;
        lst_sp = new ArrayList<DispatchedTasklet>();
    }
    public void dispatch(INtkdTaskletSpawnable sp, bool wait=false)
    {
        DispatchedTasklet dt = new DispatchedTasklet();
        dt.ch = tasklet.get_channel();
        dt.sp = sp;
        lst_sp.add(dt);
        if (t == null || !t.is_running())
        {
            DispatcherTasklet ts = new DispatcherTasklet();
            ts.dsp = this;
            t = tasklet.spawn(ts);
        }
        if (wait)
        {
            dt.ch.recv();
        }
    }
    public bool is_empty()
    {
        return t == null || !t.is_running();
    }
}
