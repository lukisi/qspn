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

using Netsukuku;
using Netsukuku.ModRpc;

public class FakeAddressManagerSkeleton : Object,
                                  IAddressManagerSkeleton,
                                  INeighborhoodManagerSkeleton,
                                  IQspnManagerSkeleton
{
	public virtual unowned INeighborhoodManagerSkeleton
	neighborhood_manager_getter()
	{
	    return this;
	}

	public virtual unowned IQspnManagerSkeleton
	qspn_manager_getter()
	{
	    return this;
	}

	public virtual uint16 expect_ping
	(string guid, uint16 peer_port, zcd.ModRpc.CallerInfo? caller = null)
	throws Netsukuku.NeighborhoodUnmanagedDeviceError
    {
        error("FakeAddressManagerSkeleton: you must override method expect_ping.");
    }

	public virtual void here_i_am 
	(Netsukuku.INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.ModRpc.CallerInfo? caller = null)
    {
        error("FakeAddressManagerSkeleton: you must override method here_i_am.");
    }

	public virtual void remove_arc 
	(Netsukuku.INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.ModRpc.CallerInfo? caller = null)
    {
        error("FakeAddressManagerSkeleton: you must override method remove_arc.");
    }

	public virtual void request_arc
	(Netsukuku.INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.ModRpc.CallerInfo? caller = null)
	throws Netsukuku.NeighborhoodRequestArcError
    {
        error("FakeAddressManagerSkeleton: you must override method request_arc.");
    }

	public virtual Netsukuku.IQspnEtpMessage get_full_etp
	(Netsukuku.IQspnAddress requesting_address, zcd.ModRpc.CallerInfo? caller = null)
	throws Netsukuku.QspnNotAcceptedError, Netsukuku.QspnBootstrapInProgressError
    {
        error("FakeAddressManagerSkeleton: you must override method get_full_etp.");
    }

	public virtual void send_etp
	(Netsukuku.IQspnEtpMessage etp, bool is_full, zcd.ModRpc.CallerInfo? caller = null)
	throws Netsukuku.QspnNotAcceptedError
    {
        error("FakeAddressManagerSkeleton: you must override method send_etp.");
    }
}

public class FakeAddressManagerStub : Object,
                                  IAddressManagerStub,
                                  INeighborhoodManagerStub,
                                  IQspnManagerStub
{
	public virtual unowned INeighborhoodManagerStub
	neighborhood_manager_getter()
	{
	    return this;
	}

	public virtual unowned IQspnManagerStub
	qspn_manager_getter()
	{
	    return this;
	}

	public virtual uint16 expect_ping
	(string guid, uint16 peer_port)
	throws Netsukuku.NeighborhoodUnmanagedDeviceError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        error("FakeAddressManagerStub: you must override method expect_ping.");
    }

	public virtual void here_i_am 
	(Netsukuku.INeighborhoodNodeID my_id, string mac, string nic_addr)
	throws zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        error("FakeAddressManagerStub: you must override method here_i_am.");
    }

	public virtual void remove_arc 
	(Netsukuku.INeighborhoodNodeID my_id, string mac, string nic_addr)
	throws zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        error("FakeAddressManagerStub: you must override method remove_arc.");
    }

	public virtual void request_arc
	(Netsukuku.INeighborhoodNodeID my_id, string mac, string nic_addr)
	throws Netsukuku.NeighborhoodRequestArcError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        error("FakeAddressManagerStub: you must override method request_arc.");
    }

    public virtual IQspnEtpMessage get_full_etp
    (Netsukuku.IQspnAddress requesting_address)
    throws Netsukuku.QspnNotAcceptedError, Netsukuku.QspnBootstrapInProgressError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        error("FakeAddressManagerStub: you must override method get_full_etp.");
    }

    public virtual void send_etp
    (Netsukuku.IQspnEtpMessage etp, bool is_full)
    throws Netsukuku.QspnNotAcceptedError, zcd.ModRpc.StubError, zcd.ModRpc.DeserializeError
    {
        error("FakeAddressManagerStub: you must override method send_etp.");
    }
}

