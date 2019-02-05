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
    // Helper: retrieve ETP from an arc
    internal void retrieve_full_etp(QspnManager mgr, IQspnArc arc, out EtpMessage? etp,
     out bool bootstrap_in_progress,
     out bool bad_answer, out string message, out bool bad_link)
    {
        bootstrap_in_progress = false;
        bad_answer = false;
        message = "";
        bad_link = false;
        etp = null;
        IQspnManagerStub stub_get_etp =
                mgr.stub_factory.i_qspn_get_tcp(arc);
        IQspnEtpMessage? resp = null;
        try {
            resp = stub_get_etp.get_full_etp(mgr.my_naddr);
        }
        catch (QspnBootstrapInProgressError e) {
            bootstrap_in_progress = true;
            return;
        }
        catch (StubError e) {
            bad_answer = true;
            message = @"retrieve_full_etp: StubError $(e.message)";
            bad_link = true;
            return;
        }
        catch (DeserializeError e) {
            bad_answer = true;
            message = @"retrieve_full_etp: DeserializeError $(e.message)";
            return;
        }
        catch (QspnNotAcceptedError e) {
            bad_answer = true;
            message = @"retrieve_full_etp: QspnNotAcceptedError $(e.message)";
            return;
        }
        if (resp == null)
        {
            bad_answer = true;
            message = @"retrieve_full_etp: resp is <null>";
            return;
        }
        if (! (resp is EtpMessage))
        {
            bad_answer = true;
            message = @"retrieve_full_etp: resp is not EtpMessage, but $(resp.get_type().name())";
            return;
        }
        etp = (EtpMessage) resp;
        if (! check_incoming_message(etp, mgr.my_naddr))
        {
            bad_answer = true;
            message = @"retrieve_full_etp: check_incoming_message not passed";
            return;
        }
        return;
    }

    // Helper: gather ETP from a set of arcs
    internal class PairArcEtp : Object {
        public PairArcEtp(EtpMessage m, IQspnArc a)
        {
            this.m = m;
            this.a = a;
        }
        public EtpMessage m;
        public IQspnArc a;
    }
    internal class GatherEtpSetData : Object
    {
        public ArrayList<ITaskletHandle> tasks;
        public ArrayList<IQspnArc> arcs;
        public ArrayList<IQspnManagerStub> stubs;
        public ArrayList<PairArcEtp> results;
        public IQspnNaddr my_naddr;
        public unowned FailedArcHandler failed_arc_handler;
    }
    internal delegate void FailedArcHandler(IQspnArc failed_arc, string message, bool bad_link);
    internal Collection<PairArcEtp>
    gather_full_etp_set(QspnManager mgr, Collection<IQspnArc> arcs, FailedArcHandler failed_arc_handler)
    {
        // Work in parallel then join
        // Prepare (one instance for this run) an object work for the tasklets
        GatherEtpSetData work = new GatherEtpSetData();
        work.tasks = new ArrayList<ITaskletHandle>();
        work.arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
        work.stubs = new ArrayList<IQspnManagerStub>();
        work.results = new ArrayList<PairArcEtp>();
        work.my_naddr = mgr.my_naddr;
        work.failed_arc_handler = failed_arc_handler;
        int i = 0;
        foreach (IQspnArc arc in arcs)
        {
            var stub = mgr.stub_factory.i_qspn_get_tcp(arc);
            work.arcs.add(arc);
            work.stubs.add(stub);
            GetFullEtpTasklet ts = new GetFullEtpTasklet();
            ts.mgr = mgr;
            ts.work = work;
            ts.i = i++;
            ITaskletHandle t = tasklet.spawn(ts, /*joinable*/ true);
            work.tasks.add(t);
        }
        // join
        foreach (ITaskletHandle t in work.tasks) t.join();
        return work.results;
    }
    internal class GetFullEtpTasklet : Object, ITaskletSpawnable
    {
        public weak QspnManager mgr;
        public GatherEtpSetData work;
        public int i;
        public void * func()
        {
            tasklet_get_full_etp(mgr, work, i);
            return null;
        }
    }
    internal void tasklet_get_full_etp(QspnManager mgr, GatherEtpSetData work, int i)
    {
        IQspnManagerStub stub = work.stubs[i];
        IQspnEtpMessage? resp = null;
        try {
            int arc_id = mgr.try_retrieve_arc_id(work.arcs[i]);
            debug(@"Requesting ETP from arc $(arc_id)");
            resp = stub.get_full_etp(work.my_naddr);
        }
        catch (ArcRemovedError e) {
            // For some reason the arc is no more. Give up this tasklet.
            return;
        }
        catch (QspnBootstrapInProgressError e) {
            debug("Got QspnBootstrapInProgressError. Give up.");
            // Give up this tasklet. The neighbor will start a flood when its bootstrap is complete.
            return;
        }
        catch (StubError e) {
            work.failed_arc_handler(work.arcs[i], @"gather_full_etp_set: StubError $(e.message)", true);
            return;
        }
        catch (QspnNotAcceptedError e) {
            work.failed_arc_handler(work.arcs[i], @"gather_full_etp_set: QspnNotAcceptedError $(e.message)", false);
            return;
        }
        catch (DeserializeError e) {
            work.failed_arc_handler(work.arcs[i], @"gather_full_etp_set: DeserializeError $(e.message)", false);
            return;
        }
        if (resp == null)
        {
            work.failed_arc_handler(work.arcs[i], @"gather_full_etp_set: resp is <null>", false);
            return;
        }
        if (! (resp is EtpMessage))
        {
            // The module only knows this class that implements IQspnEtpMessage, so this
            //  should not happen. But the rest of the code, who knows? So to be sure
            //  we check. If it is the case, remove the arc.
            work.failed_arc_handler(work.arcs[i],
                    @"gather_full_etp_set: resp is not EtpMessage, but $(resp.get_type().name())", false);
            return;
        }
        EtpMessage m = (EtpMessage) resp;
        if (!check_incoming_message(m, mgr.my_naddr))
        {
            // We check the correctness of a message from another node.
            // If the message is junk, remove the arc.
            work.failed_arc_handler(work.arcs[i], @"gather_full_etp_set: check_incoming_message not passed", false);
            return;
        }
        mgr.arc_to_naddr[work.arcs[i]] = m.node_address;

        debug("Got one.");
        PairArcEtp res = new PairArcEtp(m, work.arcs[i]);
        work.results.add(res);
    }
}
