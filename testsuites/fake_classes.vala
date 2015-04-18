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

public class FakeArc : Object, IQspnArc
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

    public IQspnNaddr i_qspn_get_naddr()
    {
        return naddr;
    }

    public IQspnCost i_qspn_get_cost()
    {
        return cost;
    }

    public bool i_qspn_equals(IQspnArc other)
    {
        return this == other;
    }

    public bool i_qspn_comes_from(zcd.CallerInfo rpc_caller)
    {
        return neighbour_nic_addr == rpc_caller.caller_ip;
    }
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
    (IQspnEtpMessage etp, bool is_full=false, zcd.CallerInfo? _rpc_caller = null)
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
                    IQspnEtpMessage t_etp           = (IQspnEtpMessage)_etp;
                    CallerInfo t_caller      = (CallerInfo)_caller;
                    try
                    {
                        t_target_mgr.send_etp(t_etp, is_full, t_caller);
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

    public override IQspnEtpMessage get_full_etp
    (IQspnAddress my_naddr, zcd.CallerInfo? _rpc_caller = null)
    throws QspnNotAcceptedError, QspnNotMatureError, RPCError
    {
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        CallerInfo caller = new CallerInfo(my_ip, null, null);
        Tasklet.schedule();
        IQspnEtpMessage ret = target_mgr.get_full_etp(my_naddr, caller);
        return ret;
    }

    public override void send_etp
    (IQspnEtpMessage etp, bool is_full=false, zcd.CallerInfo? _rpc_caller = null)
    throws QspnNotAcceptedError, zcd.RPCError
    {
        QspnManager target_mgr = target_arc.neighbour_qspnmgr;
        string my_ip = target_arc.my_nic_addr;
        CallerInfo caller = new CallerInfo(my_ip, null, null);
        Tasklet.schedule();
        target_mgr.send_etp(etp, is_full, caller);
    }
}

public class FakeThresholdCalculator : Object, IQspnThresholdCalculator
{
    public int i_qspn_calculate_threshold(IQspnNodePath p1, IQspnNodePath p2)
    {
        FakeCost c1 = (FakeCost)p1.i_qspn_get_cost();
        FakeCost c2 = (FakeCost)p2.i_qspn_get_cost();
        return (int)(500 * (c1.usec_rtt + c2.usec_rtt) / 1000);
    }
}

public class FakeStubFactory : Object, IQspnStubFactory
{
    public QspnManager my_mgr;
    public FakeStubFactory()
    {
    }

    public IAddressManagerRootDispatcher
                    i_qspn_get_broadcast(
                            IQspnMissingArcHandler? missing_handler=null,
                            IQspnArc? ignore_neighbor=null
                    )
    {
        var target_arcs = new ArrayList<FakeArc>();
        foreach (IQspnArc _arc in my_mgr.current_arcs())
        {
            FakeArc arc = (FakeArc) _arc;
            if (ignore_neighbor != null
                && arc.i_qspn_equals(ignore_neighbor))
                continue;
            target_arcs.add(arc);
        }
        return new FakeBroadcastClient(target_arcs);
    }

    public IAddressManagerRootDispatcher
                    i_qspn_get_tcp(
                            IQspnArc arc,
                            bool wait_reply=true
                    )
    {
        FakeArc _arc = (FakeArc) arc;
        return new FakeTCPClient(_arc);
    }
}

