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
    internal class MissingArcSendEtp : Object, IQspnMissingArcHandler
    {
        public MissingArcSendEtp(QspnManager mgr, EtpMessage m, bool is_full)
        {
            this.mgr = mgr;
            this.m = m;
            this.is_full = is_full;
        }
        public QspnManager mgr;
        public EtpMessage m;
        public bool is_full;
        public void i_qspn_missing(IQspnArc arc)
        {
            IQspnManagerStub stub =
                    mgr.stub_factory.i_qspn_get_tcp(arc);
            debug("Sending reliable ETP to missing arc");
            try {
                assert(check_outgoing_message(m, mgr.my_naddr));
                stub.send_etp(m, is_full);
            }
            catch (QspnNotAcceptedError e) {
                // we're not in its arcs; remove and emit signal
                mgr.arc_remove(arc);
                warning(@"Qspn: MissingArcSendEtp: QspnNotAcceptedError $(e.message)");
                // emit signal
                mgr.arc_removed(arc);
            }
            catch (StubError e) {
                // remove failed arc and emit signal
                mgr.arc_remove(arc);
                warning(@"Qspn: MissingArcSendEtp: StubError $(e.message)");
                // emit signal
                mgr.arc_removed(arc, true);
            }
            catch (DeserializeError e) {
                // remove failed arc and emit signal
                mgr.arc_remove(arc);
                warning(@"Qspn: MissingArcSendEtp: DeserializeError $(e.message)");
                // emit signal
                mgr.arc_removed(arc);
            }
        }
    }

    internal class MissingArcPrepareDestroy : Object, IQspnMissingArcHandler
    {
        public MissingArcPrepareDestroy(QspnManager mgr)
        {
            this.mgr = mgr;
        }
        public QspnManager mgr;
        public void i_qspn_missing(IQspnArc arc)
        {
            IQspnManagerStub stub =
                    mgr.stub_factory.i_qspn_get_tcp(arc, false);
            try {
                stub.got_prepare_destroy();
            }
            catch (StubError e) {
                // remove failed arc and emit signal
                mgr.arc_remove(arc);
                warning(@"Qspn: MissingArcPrepareDestroy: StubError $(e.message)");
                // emit signal
                mgr.arc_removed(arc, true);
            }
            catch (DeserializeError e) {
                // remove failed arc and emit signal
                mgr.arc_remove(arc);
                warning(@"Qspn: MissingArcPrepareDestroy: DeserializeError $(e.message)");
                // emit signal
                mgr.arc_removed(arc);
            }
        }
    }

    internal class MissingArcDestroy : Object, IQspnMissingArcHandler
    {
        public MissingArcDestroy(QspnManager mgr)
        {
            this.mgr = mgr;
        }
        public QspnManager mgr;
        public void i_qspn_missing(IQspnArc arc)
        {
            IQspnManagerStub stub =
                    mgr.stub_factory.i_qspn_get_tcp(arc, false);
            try {
                stub.got_destroy();
            }
            catch (StubError e) {
                // remove failed arc and emit signal
                mgr.arc_remove(arc);
                warning(@"Qspn: MissingArcDestroy: StubError $(e.message)");
                // emit signal
                mgr.arc_removed(arc, true);
            }
            catch (DeserializeError e) {
                // remove failed arc and emit signal
                mgr.arc_remove(arc);
                warning(@"Qspn: MissingArcDestroy: DeserializeError $(e.message)");
                // emit signal
                mgr.arc_removed(arc);
            }
        }
    }
}

