/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
using TaskletSystem;

namespace Netsukuku.Qspn
{
    // Helper: publish full ETP to all
    private void publish_full_etp(QspnManager mgr)
    {
        // Prepare full ETP and send to all my neighbors.
        EtpMessage full_etp = prepare_full_etp(mgr);
        IQspnManagerStub stub_send_to_all =
                mgr.stub_factory.i_qspn_get_broadcast(
                mgr.get_arcs_broadcast_all(),
                // If a neighbor doesnt send its ACK repeat the message via tcp
                new MissingArcSendEtp(mgr, full_etp, true));
        debug("Sending ETP to all");
        try {
            assert(check_outgoing_message(full_etp, mgr.my_naddr));
            stub_send_to_all.send_etp(full_etp, true);
        }
        catch (QspnNotAcceptedError e) {
            // a broadcast will never get a return value nor an error
            assert_not_reached();
        }
        catch (DeserializeError e) {
            // a broadcast will never get a return value nor an error
            assert_not_reached();
        }
        catch (StubError e) {
            critical(@"QspnManager.publish_full_etp: StubError in send to broadcast to all: $(e.message)");
        }
    }

    private void publish_connectivity(QspnManager mgr, int old_pos, int old_lvl)
    {
        // Send a void ETP to all neighbors outside 'old_lvl'.
        ArrayList<HCoord> hops = new ArrayList<HCoord>((a, b) => a.equals(b));
        hops.add(new HCoord(old_lvl, old_pos));
        EtpMessage etp = prepare_new_etp(mgr, new ArrayList<EtpPath>(), hops);
        ArrayList<IQspnArc> outer_w_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
        foreach (IQspnArc arc in mgr.my_arcs)
        {
            // Consider that this is not the identity which is migrating, but the one which is staying.
            //  We should have the peer_naddr for all the arcs.
            if (mgr.arc_to_naddr[arc] == null) continue;
            HCoord arc_h = mgr.my_naddr.i_qspn_get_coord_by_address(mgr.arc_to_naddr[arc]);
            if (arc_h.lvl == old_lvl && arc_h.pos != old_pos) outer_w_arcs.add(arc);
            if (arc_h.lvl > old_lvl) outer_w_arcs.add(arc);
        }
        IQspnManagerStub stub_send_to_outer =
                mgr.stub_factory.i_qspn_get_broadcast(
                outer_w_arcs,
                // If a neighbor doesnt send its ACK repeat the message via tcp
                new MissingArcSendEtp(mgr, etp, false));
        try {
            assert(check_outgoing_message(etp, mgr.my_naddr));
            stub_send_to_outer.send_etp(etp, false);
        } catch (QspnNotAcceptedError e) {
            // a broadcast will never get a return value nor an error
            assert_not_reached();
        } catch (DeserializeError e) {
            // a broadcast will never get a return value nor an error
            assert_not_reached();
        } catch (StubError e) {
            critical(@"QspnManager.publish_connectivity: StubError in broadcast sending: $(e.message)");
        }
    }
}
