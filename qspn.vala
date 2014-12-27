using Gee;
using zcd;
using Tasklets;

namespace Netsukuku
{
    // in ntkd-rpc  IQspnPath

    internal bool hcoord_equals(HCoord a, HCoord b)
    {
        return (a.lvl == b.lvl) && (a.pos == b.pos);
    }

    internal bool variations_are_important(IQspnPath oldpath, IQspnPath newpath)
    {
        if (! oldpath.i_qspn_get_fp().i_qspn_equals(newpath.i_qspn_get_fp())) return true;
        int old_num = oldpath.i_qspn_get_nodes_inside();
        int threshod = (int)(old_num * 0.1);
        int new_num = newpath.i_qspn_get_nodes_inside();
        if (new_num > old_num + threshod) return true;
        if (new_num < old_num - threshod) return true;
        if (oldpath.i_qspn_get_cost()
            .i_qspn_important_variation(newpath.i_qspn_get_cost()))
            return true;
        return false;
    }

    internal class NodePath : Object
    {
        public NodePath(IQspnArc arc_to_first_hop, IQspnPath path)
        {
            this.arc_to_first_hop = arc_to_first_hop;
            this.path = path;
        }
        public IQspnArc arc_to_first_hop;
        public IQspnPath path;
        public bool hops_are_equal(NodePath q)
        {
            if (! arc_to_first_hop.i_qspn_equals(arc_to_first_hop)) return false;
            Gee.List<HCoord> mylist = path.i_qspn_get_hops();
            Gee.List<HCoord> qlist = q.path.i_qspn_get_hops();
            if (mylist.size != qlist.size) return false;
            for (int i = 0; i < mylist.size; i++)
                if (! hcoord_equals(mylist[i], qlist[i])) return false;
            return true;
        }
    }

    internal class RetPath : Object, IQspnNodePath
    {
        public IQspnPartialNaddr destination;
        public IQspnArc arc_to_first_hop;
        public ArrayList<IQspnPartialNaddr> hops;
        public IQspnREM cost;
        public int nodes_inside;

        /* Interface */
        public IQspnPartialNaddr i_qspn_get_destination() {return destination;}
        public IQspnArc i_qspn_get_arc_to_first_hop() {return arc_to_first_hop;}
        public Gee.List<IQspnPartialNaddr> i_qspn_get_hops() {return hops;}
        public IQspnREM i_qspn_get_cost() {return cost;}
        public int i_qspn_get_nodes_inside() {return nodes_inside;}
    }

    internal class Destination : Object
    {
        public Destination(HCoord dest, Gee.List<NodePath> paths)
        {
            this.dest = dest;
            this.paths = new ArrayList<NodePath>();
            this.paths.add_all(paths);
        }
        public HCoord dest;
        public ArrayList<NodePath> paths;

        private NodePath? _best_path;
        public NodePath? best_path {
            get {
                if (paths.is_empty) return null;
                paths.sort((a, b) => {
                    IQspnREM _a = a.path.i_qspn_get_cost();
                    _a = _a.i_qspn_add_segment(a.arc_to_first_hop.i_qspn_get_cost());
                    IQspnREM _b = b.path.i_qspn_get_cost();
                    _b = _b.i_qspn_add_segment(b.arc_to_first_hop.i_qspn_get_cost());
                    return _a.i_qspn_compare_to(_b);
                });
                _best_path = paths.first();
                return _best_path;
            }
        }
    }

    public interface IQspnEtpFactory : Object
    {
        public abstract IQspnPath i_qspn_create_path
                                    (Gee.List<HCoord> hops,
                                    IQspnFingerprint fp,
                                    int nodes_inside,
                                    IQspnREM cost);
        public abstract void i_qspn_set_path_cost_dead
                                    (IQspnPath path);
        public abstract bool i_qspn_begin_etp();
        public abstract void i_qspn_abort_etp();
        public abstract void i_qspn_set_my_naddr(IQspnNaddr my_naddr);
        public abstract void i_qspn_set_gnode_fingerprint
                                    (int level,
                                    IQspnFingerprint fp);
        public abstract void i_qspn_set_gnode_nodes_inside
                                    (int level,
                                    int nodes_inside);
        public abstract void i_qspn_add_path(IQspnPath path);
        public abstract void i_qspn_set_tplist(Gee.List<HCoord> hops);
        public abstract IQspnEtp i_qspn_make_etp();
    }

    public class QspnManager : Object,
                               IQspnManager
    {
        public static void init()
        {
            // Register serializable types
            // typeof(Xxx).class_peek();
        }

        private int max_paths;
        private double max_common_hops_ratio;
        private ArrayList<IQspnArc> my_arcs;
        private ArrayList<IQspnFingerprint> my_fingerprints;
        private ArrayList<int> my_nodes_inside;
        private INeighborhoodArcToStub arc_to_stub;
        private IQspnFingerprintManager fingerprint_manager;
        private IQspnEtpFactory etp_factory;
        private int levels;
        private IQspnMyNaddr my_naddr;
        private bool mature;
        private Tasklet? periodical_update_tasklet = null;
        private ArrayList<QueuedEvent> queued_events;
        // This collection can be indexed by level and then by iteration on the
        //  values. This is useful when we want to iterate on a certain level.
        //  In addition we can specify a level and then refer by index to the
        //  position. This is useful when we want to remove one item.
        private ArrayList<HashMap<int, Destination>> destinations;

        public QspnManager(IQspnMyNaddr my_naddr,
                           int max_paths,
                           double max_common_hops_ratio,
                           Gee.List<IQspnArc> my_arcs,
                           IQspnFingerprint my_fingerprint,
                           INeighborhoodArcToStub arc_to_stub,
                           IQspnFingerprintManager fingerprint_manager,
                           IQspnEtpFactory etp_factory
                           )
        {
            this.my_naddr = my_naddr;
            this.max_paths = max_paths;
            this.max_common_hops_ratio = max_common_hops_ratio;
            this.arc_to_stub = arc_to_stub;
            this.fingerprint_manager = fingerprint_manager;
            this.etp_factory = etp_factory;
            // all the arcs
            this.my_arcs = new ArrayList<IQspnArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.i_qspn_equals(b);
                }
            );
            foreach (IQspnArc arc in my_arcs) this.my_arcs.add(arc);
            // find levels of the network
            levels = my_naddr.i_qspn_get_levels();
            // Only the level 0 fingerprint is given. The other ones
            // will be constructed when the node is mature.
            this.my_fingerprints = new ArrayList<IQspnFingerprint>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.i_qspn_equals(b);
                }
            );
            this.my_nodes_inside = new ArrayList<int>();
            my_fingerprints.add(my_fingerprint); // level 0 fingerprint
            my_nodes_inside.add(1); // level 0 nodes_inside
            for (int lvl = 1; lvl <= levels; lvl++)
            {
                // At start build fingerprint at level lvl with fingerprint at
                // level lvl-1 and an ampty set.
                my_fingerprints.add(my_fingerprints[lvl-1]
                        .i_qspn_construct(new ArrayList<IQspnFingerprint>()));
                // The same with the number of nodes inside our g-node.
                my_nodes_inside.add(1);
            }
            // prepare empty map
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int i = 0; i < levels; i++) destinations.add(
                new HashMap<int, Destination>());
            // mature if alone
            qspn_mature.connect(on_mature);
            if (this.my_arcs.is_empty)
            {
                mature = true;
                qspn_mature();
            }
            else
            {
                mature = false;
                queued_events = new ArrayList<QueuedEvent>();
                // start in a tasklet the request of an ETP from all neighbors.
                Tasklet.tasklet_callback(
                    (t) => {
                        (t as QspnManager).get_first_etps();
                    },
                    this
                );
            }
        }

        public void stop_operations()
        {
            if (periodical_update_tasklet != null)
                periodical_update_tasklet.abort();
        }

        private void on_mature()
        {
            debug("Event qspn_mature");
            // start in a tasklet the periodical send of full updates.
            periodical_update_tasklet = Tasklet.tasklet_callback(
                (t) => {
                    (t as QspnManager).periodical_update();
                },
                this
            );
        }

        class MissingArcSendEtp : Object, INeighborhoodMissingArcHandler
        {
            public MissingArcSendEtp(QspnManager qspnman, IQspnEtp etp)
            {
                this.qspnman = qspnman;
                this.etp = etp;
            }
            public QspnManager qspnman;
            public IQspnEtp etp;
            public void i_neighborhood_missing(
                            INeighborhoodArc arc,
                            INeighborhoodArcRemover arc_remover
                        )
            {
                IAddressManagerRootDispatcher disp =
                        qspnman.arc_to_stub.i_neighborhood_get_tcp(arc);
                debug("Sending ETP to missing arc");
                try {
                    disp.qspn_manager.send_etp(etp);
                }
                catch (QspnNotAcceptedError e) {
                    // possibly we're not in its arcs; log and ignore.
                    log_warn(@"MissingArcSendEtp: $(e.message)");
                }
                catch (RPCError e) {
                    // remove failed arcs and emit signal
                    qspnman.arc_remove(arc as IQspnArc);
                    // emit signal
                    qspnman.arc_removed(arc as IQspnArc);
                    return;
                }
            }
        }

        class QueuedEvent : Object
        {
            public QueuedEvent.arc_add(IQspnArc arc)
            {
                this.arc = arc;
                type = 1;
            }
            public QueuedEvent.arc_is_changed(IQspnArc arc)
            {
                this.arc = arc;
                type = 2;
            }
            public QueuedEvent.arc_remove(IQspnArc arc)
            {
                this.arc = arc;
                type = 3;
            }
            public QueuedEvent.etp_received(IQspnEtp etp, IQspnArc arc)
            {
                this.etp = etp;
                this.arc = arc;
                type = 4;
            }
            public int type;
            // 1 arc_add
            // 2 arc_is_changed
            // 3 arc_remove
            // 4 etp_received
            public IQspnArc arc;
            public IQspnEtp etp;
        }

        // The module is notified if an arc is added/changed/removed
        public void arc_add(IQspnArc arc)
        {
            Tasklet.tasklet_callback((_qspnmgr, _arc) => {
                    QspnManager qspnmgr = (QspnManager)_qspnmgr;
                    qspnmgr.tasklet_arc_add((IQspnArc)_arc);
                },
                this,
                arc
                );
        }

        private void tasklet_arc_add(IQspnArc arc)
        {
            // From outside the module is notified of the creation of this new arc.
            if (!mature)
            {
                queued_events.add(new QueuedEvent.arc_add(arc));
                return;
            }
            if (arc in my_arcs)
            {
                log_warn("QspnManager.arc_add: already in my arcs.");
                return;
            }
            my_arcs.add(arc);
            IAddressManagerRootDispatcher disp_get_etp =
                    arc_to_stub.i_neighborhood_get_tcp((arc as INeighborhoodArc));
            IQspnEtp? etp = null;
            try {
                while (true)
                {
                    try {
                        debug("Requesting ETP from new arc");
                        etp = disp_get_etp.qspn_manager.get_full_etp(my_naddr);
                        break;
                    }
                    catch (QspnNotAcceptedError e) {
                        // possibly temporary.
                        log_warn(@"QspnManager.arc_add: get_full_etp not accepted: $(e.message)");
                        ms_wait(2000);
                    }
                    catch (QspnNotMatureError e) {
                        // wait for it to become mature
                        ms_wait(2000);
                    }
                }
            }
            catch (RPCError e) {
                // remove failed arc and emit signal
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
            // Got ETP from new neighbor/arc. Purify it.
            etp = process_etp(etp);
            if (etp == null)
            {
                // should not happen
                log_warn("QspnManager.arc_add: get_full_etp returned invalid etp");
                // remove failed arc and emit signal
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
            // Update my map with it.
            ArrayList<PairArcEtp> etps = new ArrayList<PairArcEtp>();
            etps.add(new PairArcEtp(etp, arc));
            UpdateMapResult ret = update_map(etps);
            // create a new etp for old arcs (not the new one)
            if (ret.interesting)
            {
                IQspnEtp new_etp = prepare_new_etp(ret.changed_paths);
                IAddressManagerRootDispatcher disp_send_to_old =
                        arc_to_stub.i_neighborhood_get_broadcast(
                        /* If a neighbor doesnt send its ACK repeat the message via tcp */
                        new MissingArcSendEtp(this, new_etp),
                        /* Ignore this neighbor */
                        (arc as INeighborhoodArc).i_neighborhood_neighbour_id);
                debug("Sending ETP to old");
                try {
                    disp_send_to_old.qspn_manager.send_etp(new_etp);
                }
                catch (QspnNotAcceptedError e) {
                    // a broadcast will never get a return value nor an error
                    assert_not_reached();
                }
                catch (RPCError e) {
                    log_error(@"QspnManager.arc_add: RPCError in send to broadcast to old: $(e.message)");
                }
            }
            // create a new etp for arc
            IQspnEtp full_etp = prepare_full_etp();
            IAddressManagerRootDispatcher disp_send_to_arc =
                    arc_to_stub.i_neighborhood_get_tcp((arc as INeighborhoodArc));
            debug("Sending ETP to new arc");
            try {
                disp_send_to_arc.qspn_manager.send_etp(full_etp);
            }
            catch (QspnNotAcceptedError e) {
                // should definitely not happen.
                log_warn(@"QspnManager.arc_add: send_etp not accepted: $(e.message)");
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
            catch (RPCError e) {
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
            // That's it.
        }

        public void arc_is_changed(IQspnArc changed_arc)
        {
            Tasklet.tasklet_callback((_qspnmgr, _changed_arc) => {
                    QspnManager qspnmgr = (QspnManager)_qspnmgr;
                    qspnmgr.tasklet_arc_is_changed((IQspnArc)_changed_arc);
                },
                this,
                changed_arc
                );
        }

        private void tasklet_arc_is_changed(IQspnArc changed_arc)
        {
            // From outside the module is notified that the cost of this arc of mine
            // is changed.
            if (!mature)
            {
                queued_events.add(new QueuedEvent.arc_is_changed(changed_arc));
                return;
            }
            if (!(changed_arc in my_arcs))
            {
                log_warn("QspnManager.arc_is_changed: not in my arcs.");
                return;
            }
            // gather ETP from all of my arcs
            Collection<PairArcEtp> results =
                gather_full_etp_set(my_arcs, (arc) => {
                    // remove failed arcs and emit signal
                    arc_remove(arc);
                    // emit signal
                    arc_removed(arc);
                });
            // Process ETPs and update my map
            ArrayList<PairArcEtp> valid_etp_set = new ArrayList<PairArcEtp>();
            foreach (PairArcEtp pair_arc_etp in results)
            {
                // Purify received etp.
                IQspnEtp? etp = process_etp(pair_arc_etp.etp);
                // if it's not to be dropped...
                if (etp != null) valid_etp_set.add(pair_arc_etp);
            }
            UpdateMapResult ret = update_map(valid_etp_set, changed_arc);
            // create a new etp for all
            if (ret.interesting)
            {
                IQspnEtp new_etp = prepare_new_etp(ret.changed_paths);
                IAddressManagerRootDispatcher disp_send_to_all =
                        arc_to_stub.i_neighborhood_get_broadcast(
                        /* If a neighbor doesnt send its ACK repeat the message via tcp */
                        new MissingArcSendEtp(this, new_etp));
                debug("Sending ETP to all");
                try {
                    disp_send_to_all.qspn_manager.send_etp(new_etp);
                }
                catch (QspnNotAcceptedError e) {
                    // a broadcast will never get a return value nor an error
                    assert_not_reached();
                }
                catch (RPCError e) {
                    log_error(@"QspnManager.arc_is_changed: RPCError in send to broadcast to all: $(e.message)");
                }
            }
        }

        public void arc_remove(IQspnArc removed_arc)
        {
            Tasklet.tasklet_callback((_qspnmgr, _removed_arc) => {
                    QspnManager qspnmgr = (QspnManager)_qspnmgr;
                    qspnmgr.tasklet_arc_remove((IQspnArc)_removed_arc);
                },
                this,
                removed_arc
                );
        }

        private void tasklet_arc_remove(IQspnArc removed_arc)
        {
            // From outside the module is notified that this arc of mine
            // has been removed.
            // Or, either, the module itself wants to remove this arc (possibly
            // because it failed to send a message).
            if (!mature)
            {
                queued_events.add(new QueuedEvent.arc_remove(removed_arc));
                return;
            }
            if (!(removed_arc in my_arcs))
            {
                log_warn("QspnManager.arc_remove: not in my arcs.");
                return;
            }
            // First, remove the arc...
            my_arcs.remove(removed_arc);
            // ... and all the NodePath from it.
            var dest_to_remove = new ArrayList<Destination>();
            var path_to_add_to_changed_paths = new ArrayList<NodePath>();
            for (int l = 0; l < levels; l++) foreach (Destination d in destinations[l])
            {
                int i = 0;
                while (i < d.paths.size)
                {
                    NodePath np = d.paths[i];
                    if (np.arc_to_first_hop.i_qspn_equals(removed_arc))
                    {
                        d.paths.remove_at(i);
                        etp_factory.i_qspn_set_path_cost_dead(np.path);
                        path_to_add_to_changed_paths.add(np);
                    }
                    else
                    {
                        i++;
                    }
                }
                if (d.paths.is_empty) dest_to_remove.add(d);
            }
            foreach (Destination d in dest_to_remove)
            {
                destination_removed(my_naddr.i_qspn_get_address_by_coord(d.dest));
                destinations[d.dest.lvl].unset(d.dest.pos);
            }
            // Then do the same as when arc is changed:
            // gather ETP from all of my arcs
            Collection<PairArcEtp> results =
                gather_full_etp_set(my_arcs, (arc) => {
                    // remove failed arcs and emit signal
                    arc_remove(arc);
                    // emit signal
                    arc_removed(arc);
                });
            // Process ETPs and update my map
            ArrayList<PairArcEtp> valid_etp_set = new ArrayList<PairArcEtp>();
            foreach (PairArcEtp pair_arc_etp in results)
            {
                // Purify received etp.
                IQspnEtp? etp = process_etp(pair_arc_etp.etp);
                // if it's not to be dropped...
                if (etp != null) valid_etp_set.add(pair_arc_etp);
            }
            UpdateMapResult ret = update_map(valid_etp_set);
            // create a new etp for all
            ArrayList<NodePath> changed_paths = new ArrayList<NodePath>();
            changed_paths.add_all(ret.changed_paths);
            changed_paths.add_all(path_to_add_to_changed_paths);
            IQspnEtp new_etp = prepare_new_etp(changed_paths);
            IAddressManagerRootDispatcher disp_send_to_all =
                    arc_to_stub.i_neighborhood_get_broadcast(
                    /* If a neighbor doesnt send its ACK repeat the message via tcp */
                    new MissingArcSendEtp(this, new_etp));
            debug("Sending ETP to all");
            try {
                disp_send_to_all.qspn_manager.send_etp(new_etp);
            }
            catch (QspnNotAcceptedError e) {
                // a broadcast will never get a return value nor an error
                assert_not_reached();
            }
            catch (RPCError e) {
                log_error(@"QspnManager.arc_remove: RPCError in send to broadcast to all: $(e.message)");
            }
        }

        // The hook on a particular network has failed.
        public signal void failed_hook();
        // The hook on a particular network has completed; the module is mature.
        public signal void qspn_mature();
        // An arc (is not working) has been removed from my list.
        public signal void arc_removed(IQspnArc arc);
        // A gnode (or node) is now known on the network and the first path towards
        //  it is now available to this node.
        public signal void destination_added(IQspnPartialNaddr d);
        // A gnode (or node) has been removed from the network and the last path
        //  towards it has been deleted from this node.
        public signal void destination_removed(IQspnPartialNaddr d);
        // A new path (might be the first) to a destination has been found.
        public signal void path_added(IQspnNodePath p);
        // A path to a destination has changed.
        public signal void path_changed(IQspnNodePath p);
        // A path (might be the last) to a destination has been deleted.
        public signal void path_removed(IQspnNodePath p);
        // My g-node of level l changed its fingerprint.
        public signal void changed_fp(int l);
        // My g-node of level l changed its nodes_inside.
        public signal void changed_nodes_inside(int l);
        // A gnode has splitted and the part reachable by this path MUST migrate.
        public signal void gnode_splitted(IQspnPath p);

        // Helper: get IQspnNodePath from NodePath
        private RetPath get_ret_path(NodePath np)
        {
            IQspnPath p = np.path;
            IQspnArc arc = np.arc_to_first_hop;
            HCoord dest = p.i_qspn_get_hops().last();
            RetPath r = new RetPath();
            r.destination = my_naddr.i_qspn_get_address_by_coord(dest);
            r.arc_to_first_hop = arc;
            r.hops = new ArrayList<IQspnPartialNaddr>();
            foreach (HCoord h in p.i_qspn_get_hops())
                r.hops.add(my_naddr.i_qspn_get_address_by_coord(h));
            r.cost = p.i_qspn_get_cost().i_qspn_add_segment(arc.i_qspn_get_cost());
            r.nodes_inside = p.i_qspn_get_nodes_inside();
            return r;
        }

        // Helper: prepare new ETP
        private IQspnEtp prepare_new_etp(Collection<NodePath> node_paths, Gee.List<HCoord>? tplist=null)
        {
            // ? try
            while (! etp_factory.i_qspn_begin_etp()) ms_wait(100);
            etp_factory.i_qspn_set_my_naddr(my_naddr);
            for (int level = 0; level < levels; level++)
            {
                etp_factory.i_qspn_set_gnode_fingerprint(level, my_fingerprints[level]);
                etp_factory.i_qspn_set_gnode_nodes_inside(level, my_nodes_inside[level]);
            }
            foreach (NodePath np in node_paths)
            {
                IQspnREM cost = np.arc_to_first_hop.i_qspn_get_cost()
                        .i_qspn_add_segment(np.path.i_qspn_get_cost());
                int nodes_inside = np.path.i_qspn_get_nodes_inside();
                IQspnFingerprint fp = np.path.i_qspn_get_fp();
                Gee.List<HCoord> hops = np.path.i_qspn_get_hops();
                IQspnPath tosend = etp_factory.i_qspn_create_path
                        (hops, fp, nodes_inside, cost);
                etp_factory.i_qspn_add_path(tosend);
            }
            if (tplist != null) etp_factory.i_qspn_set_tplist(tplist);
            return etp_factory.i_qspn_make_etp();
            // ? catch XxxError: etp_factory.i_qspn_abort_etp(); throw new YyyError || return null
        }

        // Helper: prepare full ETP
        private IQspnEtp prepare_full_etp()
        {
            Collection<NodePath> all_paths = new ArrayList<NodePath>();
            foreach (var d1 in destinations)
                foreach (Destination d in d1.values)
                {
                    all_paths.add_all(d.paths);
                }
            return prepare_new_etp(all_paths);
        }

        // Helper: prepare full ETP
        private IQspnEtp prepare_fwd_etp(IQspnEtp etp, Collection<NodePath> node_paths)
        {
            Gee.List<HCoord> tplist = etp.i_qspn_get_tplist();
            return prepare_new_etp(node_paths, tplist);
        }

        // Helper: gather ETP from a set of arcs
        class GatherEtpSetData : Object
        {
            public ArrayList<Tasklet> tasks;
            public ArrayList<IQspnArc> arcs;
            public ArrayList<IAddressManagerRootDispatcher> disps;
            public ArrayList<PairArcEtp> results;
            public IQspnNaddr my_naddr;
            public unowned FailedArcHandler failed_arc_handler;
        }
        private delegate void FailedArcHandler(IQspnArc failed_arc);
        private Collection<PairArcEtp>
        gather_full_etp_set(Collection<IQspnArc> arcs, FailedArcHandler failed_arc_handler)
        {
            // Work in parallel then join
            // Prepare (one instance for this run) an object work for the tasklets
            GatherEtpSetData work = new GatherEtpSetData();
            work.tasks = new ArrayList<Tasklet>();
            work.arcs = new ArrayList<IQspnArc>();
            work.disps = new ArrayList<IAddressManagerRootDispatcher>();
            work.results = new ArrayList<PairArcEtp>();
            work.my_naddr = my_naddr;
            work.failed_arc_handler = failed_arc_handler;
            int i = 0;
            foreach (IQspnArc arc in arcs)
            {
                var disp =
                    arc_to_stub.i_neighborhood_get_tcp((arc as INeighborhoodArc));
                work.arcs.add(arc);
                work.disps.add(disp);
                Tasklet t = Tasklet.tasklet_callback(
                    (t_work, t_i) => {
                        GatherEtpSetData _work = t_work as GatherEtpSetData;
                        int _i = (t_i as SerializableInt).i;
                        try
                        {
                            IAddressManagerRootDispatcher _disp = _work.disps[_i];
                            IQspnEtp etp = _disp.qspn_manager.get_full_etp(_work.my_naddr);
                            PairArcEtp res = new PairArcEtp(etp, _work.arcs[_i]);
                            _work.results.add(res);
                        }
                        catch (QspnNotMatureError e)
                        {
                            // ignore
                        }
                        catch (RPCError e)
                        {
                            _work.failed_arc_handler(_work.arcs[_i]);
                        }
                    },
                    work,
                    new SerializableInt(i++),
                    null,
                    null,
                    true /* joinable */
                );
                work.tasks.add(t);
            }
            // join
            foreach (Tasklet t in work.tasks) t.join();
            var ret = new ArrayList<PairArcEtp>();
            ret.add_all(work.results);
            return ret;
        }

        private void get_first_etps()
        {
            debug("Gathering ETP from all of my arcs");
            // gather ETP from all of my arcs
            Collection<PairArcEtp> results =
                gather_full_etp_set(my_arcs, (arc) => {
                    // remove failed arcs and emit signal
                    arc_remove(arc);
                    // emit signal
                    arc_removed(arc);
                });
            // on everything fail signal hook impossible
            if (results.is_empty)
            {
                failed_hook();
            }
            else
            {
                debug("Processing ETP set");
                // Process ETPs and update my map
                ArrayList<PairArcEtp> valid_etp_set = new ArrayList<PairArcEtp>();
                foreach (PairArcEtp pair_arc_etp in results)
                {
                    // Purify received etp.
                    IQspnEtp? etp = process_etp(pair_arc_etp.etp);
                    // if it's not to be dropped...
                    if (etp != null) valid_etp_set.add(pair_arc_etp);
                }
                update_map(valid_etp_set);
                // prepare ETP and send to all my neighbors.
                IQspnEtp full_etp = prepare_full_etp();
                IAddressManagerRootDispatcher disp_send_to_all =
                        arc_to_stub.i_neighborhood_get_broadcast(
                        /* If a neighbor doesnt send its ACK repeat the message via tcp */
                        new MissingArcSendEtp(this, full_etp));
                debug("Sending ETP to all");
                try {
                    disp_send_to_all.qspn_manager.send_etp(full_etp);
                }
                catch (QspnNotAcceptedError e) {
                    // a broadcast will never get a return value nor an error
                    assert_not_reached();
                }
                catch (RPCError e) {
                    log_error(@"QspnManager.get_first_etps: RPCError in send to broadcast to all: $(e.message)");
                }
                // Now we are hooked to the network and mature.
                foreach (QueuedEvent ev in queued_events)
                {
                    if (ev.type == 1) arc_add(ev.arc);
                    if (ev.type == 2) arc_is_changed(ev.arc);
                    if (ev.type == 3) arc_remove(ev.arc);
                    if (ev.type == 4) got_etp_from_arc(ev.etp, ev.arc);
                }
                mature = true;
                qspn_mature();
            }
        }

        /** Periodically update full
          */
        private void periodical_update()
        {
            while (true)
            {
                ms_wait(600000); // 10 minutes
                IQspnEtp full_etp = prepare_full_etp();
                IAddressManagerRootDispatcher disp_send_to_all =
                        arc_to_stub.i_neighborhood_get_broadcast(
                        /* If a neighbor doesnt send its ACK repeat the message via tcp */
                        new MissingArcSendEtp(this, full_etp));
                debug("Sending ETP to all");
                try {
                    disp_send_to_all.qspn_manager.send_etp(full_etp);
                }
                catch (QspnNotAcceptedError e) {
                    // a broadcast will never get a return value nor an error
                    assert_not_reached();
                }
                catch (RPCError e) {
                    log_error(@"QspnManager.periodical_update: RPCError in send to broadcast to all: $(e.message)");
                }
            }
        }

        // Helper: process received ETP to make it valid for me.
        // It returns the same instance if ok, or null if to be dropped.
        private IQspnEtp? process_etp(IQspnEtp etp)
        {
            IQspnEtp? ret = null;
            if (etp.i_qspn_check_network_parameters(my_naddr))
            {
                HCoord exit_gnode = my_naddr.
                        i_qspn_get_coord_by_address(
                        etp.i_qspn_get_naddr());
                etp.i_qspn_tplist_adjust(exit_gnode);
                if (etp.i_qspn_tplist_acyclic_check(my_naddr))
                {
                    etp.i_qspn_routeset_cleanup(exit_gnode);
                    etp.i_qspn_routeset_tplist_adjust(exit_gnode);
                    etp.i_qspn_routeset_tplist_acyclic_check(my_naddr);
                    etp.i_qspn_routeset_add_source(exit_gnode);
                    ret = etp;
                }
                else
                {
                    // dropped because of acyclic rule
                }
            }
            else
            {
                // malformed ETP
                log_warn("ETP malformed");
            }
            return ret;
        }

        class PairArcEtp : Object {
            public PairArcEtp(IQspnEtp etp, IQspnArc arc)
            {
                this.etp = etp;
                this.arc = arc;
            }
            public IQspnEtp etp;
            public IQspnArc arc;
        }
        class PairStatePath : Object {
            public PairStatePath(int state, NodePath path)
            {
                this.state = state;
                this.path = path;
            }
            public int state;
            public NodePath path;
        }
        class UpdateMapResult : Object {
            public bool interesting;
            public Gee.List<NodePath> changed_paths;
        }
        private UpdateMapResult update_map(Collection<PairArcEtp> etps, IQspnArc? changed_arc=null)
        {
            HashMap<HCoord,Gee.List<PairStatePath>> temp_dict =
                    new HashMap<HCoord,Gee.List<PairStatePath>>(
                    /*HashDataFunc<K>? key_hash_func*/(v) => {return 1;},
                    /*EqualDataFunc<K>? key_equal_func*/(a, b) => {
                        return hcoord_equals(a, b);
                    });
            foreach (PairArcEtp pair in etps)
            {
                IQspnEtp e = pair.etp;
                IQspnArc arc = pair.arc;
                foreach (IQspnPath v in e.i_qspn_routeset)
                {
                    NodePath q = new NodePath(arc, v);
                    HCoord dst = q.path.i_qspn_get_hops().last();
                    if (! temp_dict.has_key(dst))
                    {
                        temp_dict[dst] = new ArrayList<PairStatePath>();
                        if (destinations[dst.lvl].has_key(dst.pos))
                        {
                            foreach (NodePath p in destinations[dst.lvl][dst.pos].paths)
                            {
                                // old path. maybe changed its arc.
                                int s = 1;
                                if (p.arc_to_first_hop.i_qspn_equals(changed_arc))
                                    s = 4;
                                temp_dict[dst].add(new PairStatePath(s, p));
                            }
                        }
                    }
                    bool exists = false;
                    for (int i = 0; i < temp_dict[dst].size; i++)
                    {
                        NodePath r = temp_dict[dst][i].path;
                        if (r.hops_are_equal(q))
                        {
                            exists = true;
                            if (variations_are_important(r.path, q.path))
                            {
                                // substitute.
                                temp_dict[dst][i] = new PairStatePath(4, q);
                            }
                            // else   unchanged. ignore.
                            break;
                        }
                    }
                    if (! exists)
                    {
                        // new path.
                        if (temp_dict[dst].is_empty)
                        {
                            // new destination.
                            temp_dict[dst].add(new PairStatePath(2, q));
                        }
                        else
                        {
                            temp_dict[dst].add(new PairStatePath(3, q));
                        }
                    }
                }
            }

            // process available paths
            Gee.List<NodePath> changed_paths = new ArrayList<NodePath>();
            foreach (HCoord dst in temp_dict.keys)
            {
                // sort set temp_dict[dst] which is ArrayList<PairStatePath>
                temp_dict[dst].sort((a, b) => {
                    IQspnREM _a = a.path.path.i_qspn_get_cost();
                    _a = _a.i_qspn_add_segment(a.path.arc_to_first_hop.i_qspn_get_cost());
                    IQspnREM _b = b.path.path.i_qspn_get_cost();
                    _b = _b.i_qspn_add_segment(b.path.arc_to_first_hop.i_qspn_get_cost());
                    return _a.i_qspn_compare_to(_b);
                });
                int i = 0;
                int good_paths = 0;
                Gee.List<IQspnFingerprint> distinct_fp = new ArrayList<IQspnFingerprint>((a, b) => {
                    return a.i_qspn_equals(b);
                });
                while (i < temp_dict[dst].size)
                {
                    int n = temp_dict[dst][i].state;
                    NodePath q = temp_dict[dst][i].path;
                    IQspnFingerprint fp = q.path.i_qspn_get_fp();
                    if (!(fp in distinct_fp))
                    {
                        distinct_fp.add(fp);
                        good_paths++;
                    }
                    else
                    {
                        if (good_paths >= max_paths)
                        {
                            etp_factory.i_qspn_set_path_cost_dead(q.path);
                            if (n == 1) temp_dict[dst][i].state = 4;
                        }
                        else
                        {
                            if (! q.path.i_qspn_get_cost().i_qspn_is_dead())
                            {
                                bool disjoint = true;
                                for (int j = 0; j < i; j++)
                                {
                                    NodePath q1 = temp_dict[dst][j].path;
                                    if (! q1.path.i_qspn_get_cost().i_qspn_is_dead())
                                    {
                                        // how many hops in q1 (exclude destination)
                                        double denominator = 0.0;
                                        var q1_hops = q1.path.i_qspn_get_hops();
                                        q1_hops = q1_hops[0:q1_hops.size-1];
                                        foreach (HCoord h1 in q1_hops)
                                        {
                                            denominator += diam(h1);
                                        }
                                        if (denominator != 0)
                                        {
                                            double common_hops = 0;
                                            foreach (HCoord h in q1_hops)
                                            {
                                                bool contains = false;
                                                var q_hops = q.path.i_qspn_get_hops();
                                                q_hops = q_hops[0:q_hops.size-1];
                                                foreach (HCoord h_test in q_hops)
                                                {
                                                    if (hcoord_equals(h, h_test))
                                                    {
                                                        contains = true;
                                                        break;
                                                    }
                                                }
                                                if (contains)
                                                {
                                                    common_hops += diam(h);
                                                }
                                            }
                                            double common_hops_ratio = common_hops / denominator;
                                            if (common_hops_ratio > max_common_hops_ratio)
                                            {
                                                disjoint = false;
                                                break;
                                            }
                                        }
                                    }
                                }
                                if (! disjoint)
                                {
                                    etp_factory.i_qspn_set_path_cost_dead(q.path);
                                    if (n == 1) temp_dict[dst][i].state = 4;
                                }
                                else
                                {
                                    good_paths++;
                                }
                            }
                        }
                    }
                    i++;
                }
                bool destination_was_known = false;
                bool destination_exists = false;
                Gee.List<NodePath> current_paths = new ArrayList<NodePath>();
                foreach (PairStatePath pair_nq in temp_dict[dst])
                {
                    int n = pair_nq.state;
                    NodePath q = pair_nq.path;
                    if ((! destination_was_known) && (n == 4 || n == 1))
                        destination_was_known = true;
                    if ((! destination_exists) && (! q.path.i_qspn_get_cost().i_qspn_is_dead()))
                        destination_exists = true;
                }
                if (destination_exists && (! destination_was_known))
                {
                    destination_added(my_naddr.i_qspn_get_address_by_coord(dst));
                }
                foreach (PairStatePath pair_nq in temp_dict[dst])
                {
                    int n = pair_nq.state;
                    NodePath q = pair_nq.path;
                    if (n == 1)
                    {
                        // path unchanged and not dead
                        current_paths.add(q);
                    }
                    else if (n == 2 || n == 3)
                    {
                        if (! q.path.i_qspn_get_cost().i_qspn_is_dead())
                        {
                            current_paths.add(q);
                            changed_paths.add(q);
                            path_added(get_ret_path(q));
                        }
                    }
                    else if (n == 4)
                    {
                        changed_paths.add(q);
                        if (! q.path.i_qspn_get_cost().i_qspn_is_dead())
                        {
                            current_paths.add(q);
                            path_changed(get_ret_path(q));
                        }
                        else
                        {
                            path_removed(get_ret_path(q));
                        }
                    }
                }
                if (destination_was_known && (! destination_exists))
                {
                    destination_removed(my_naddr.i_qspn_get_address_by_coord(dst));
                    destinations[dst.lvl].unset(dst.pos);
                }
                if (destination_exists)
                {
                    destinations[dst.lvl][dst.pos] = new Destination(dst, current_paths);
                }
            }
            bool variations = false;
            for (int l = 1; l < levels; l++)
            {
                Gee.List<IQspnFingerprint> sibling_fp = new ArrayList<IQspnFingerprint>();
                int sum_nodes = 0;
                foreach (int pos in destinations[l-1].keys)
                {
                    IQspnFingerprint? fp_dst = null;
                    Destination d = destinations[l-1][pos];
                    foreach (NodePath p in d.paths)
                    {
                        IQspnFingerprint fp_dst_p = p.path.i_qspn_get_fp();
                        if (fp_dst == null)
                        {
                            fp_dst = fp_dst_p;
                        }
                        else
                        {
                            if (! fp_dst.i_qspn_equals(fp_dst_p))
                                if (! fp_dst.i_qspn_elder(fp_dst_p))
                                    fp_dst = fp_dst_p;
                        }
                    }
                    sibling_fp.add(fp_dst);
                    int nn_dst = d.best_path.path.i_qspn_get_nodes_inside();
                    sum_nodes += nn_dst;
                }
                IQspnFingerprint current_fp_l = my_fingerprints[l-1].i_qspn_construct(sibling_fp);
                if (! current_fp_l.i_qspn_equals(my_fingerprints[l]))
                {
                    my_fingerprints[l] = current_fp_l;
                    variations = true;
                    changed_fp(l);
                }
                int current_nn_l = my_nodes_inside[l-1] + sum_nodes;
                if (current_nn_l != my_nodes_inside[l])
                {
                    my_nodes_inside[l] = current_nn_l;
                    variations = true;
                    changed_nodes_inside(l);
                }
            }
            UpdateMapResult ret = new UpdateMapResult();
            ret.interesting = (! changed_paths.is_empty) || variations;
            ret.changed_paths = changed_paths;
            return ret;
        }

        // Helper: estimate of nodes in a path while traversing a certain g-node
        private double diam(HCoord h)
        {
            if (h.lvl == 0) return 1;
            if (destinations[h.lvl].has_key(h.pos))
            {
                Destination d = destinations[h.lvl][h.pos];
                NodePath? np = d.best_path;
                if (np != null)
                {
                    return Math.sqrt(np.path.i_qspn_get_nodes_inside());
                }
            }
            return 1.0;
        }

        /** Provides a collection of known paths to a destination
          */
        public Gee.List<IQspnNodePath> get_paths_to(HCoord d) throws QspnNotMatureError
        {
            if (!mature) throw new QspnNotMatureError.GENERIC("I am not mature.");
            var ret = new ArrayList<IQspnNodePath>();
            if (d.lvl < levels && destinations[d.lvl].has_key(d.pos))
            {
                foreach (NodePath np in destinations[d.lvl][d.pos].paths)
                    ret.add(get_ret_path(np));
            }
            return ret;
        }

        /** Gives the estimate of the number of nodes that are inside my g-node
          */
        public int get_nodes_inside(int level) throws QspnNotMatureError
        {
            if (!mature) throw new QspnNotMatureError.GENERIC("I am not mature.");
            return my_nodes_inside[level];
        }

        /** Gives the fingerprint of my g-node
          */
        public IQspnFingerprint get_fingerprint(int level) throws QspnNotMatureError
        {
            if (!mature) throw new QspnNotMatureError.GENERIC("I am not mature.");
            return my_fingerprints[level];
        }

        /** Informs whether the node is mature
          */
        public bool is_mature()
        {
            return mature;
        }

        /** Gives the list of current arcs
          */
        public Gee.List<IQspnArc> current_arcs()
        {
            var ret = new ArrayList<IQspnArc>();
            ret.add_all(my_arcs);
            return ret;
        }

        /* Remotable methods
         */

        public IQspnEtp get_full_etp(IQspnNaddr requesting_naddr, zcd.CallerInfo? _rpc_caller=null) throws QspnNotAcceptedError, QspnNotMatureError
        {
            if (!mature) throw new QspnNotMatureError.GENERIC("I am not mature.");

            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from this arc.
            IQspnArc? arc = null;
            foreach (IQspnArc _arc in my_arcs)
            {
                INeighborhoodArc iarc = (INeighborhoodArc) _arc;
                if (iarc.i_neighborhood_comes_from(rpc_caller))
                {
                    arc = _arc;
                    break;
                }
            }
            if (arc == null) throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");

            HCoord b = my_naddr.i_qspn_get_coord_by_address(requesting_naddr);
            var node_paths = new ArrayList<NodePath>();
            for (int l = b.lvl; l < levels; l++) foreach (Destination d in destinations[l])
            {
                foreach (NodePath np in d.paths)
                {
                    bool found = false;
                    foreach (HCoord h in np.path.i_qspn_get_hops())
                    {
                        if (hcoord_equals(h, b)) found = true;
                        if (found) break;
                    }
                    if (!found) node_paths.add(np);
                }
            }
            debug("Sending ETP on request");
            return prepare_new_etp(node_paths);
        }

        public void send_etp(IQspnEtp etp, zcd.CallerInfo? _rpc_caller=null) throws QspnNotAcceptedError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from this arc.
            IQspnArc? arc = null;
            foreach (IQspnArc _arc in my_arcs)
            {
                INeighborhoodArc iarc = (INeighborhoodArc) _arc;
                if (iarc.i_neighborhood_comes_from(rpc_caller))
                {
                    arc = _arc;
                    break;
                }
            }
            if (arc == null) throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");

            got_etp_from_arc(etp, arc);
        }
        
        private void got_etp_from_arc(IQspnEtp etp, IQspnArc arc)
        {
            if (!mature)
            {
                queued_events.add(new QueuedEvent.etp_received(etp, arc));
                return;
            }
            debug("Processing ETP");
            IQspnEtp? processed = process_etp(etp);
            // if it's not to be dropped...
            if (processed != null)
            {
                // ... update my map with it.
                ArrayList<PairArcEtp> etps = new ArrayList<PairArcEtp>();
                etps.add(new PairArcEtp(processed, arc));
                UpdateMapResult ret = update_map(etps);
                if (ret.interesting)
                {
                    IQspnEtp fwd_etp = prepare_fwd_etp(processed, ret.changed_paths);
                    IAddressManagerRootDispatcher disp_send_to_others =
                            arc_to_stub.i_neighborhood_get_broadcast(
                            /* If a neighbor doesnt send its ACK repeat the message via tcp */
                            new MissingArcSendEtp(this, fwd_etp),
                            /* Ignore this neighbor */
                            (arc as INeighborhoodArc).i_neighborhood_neighbour_id);
                    debug("Sending ETP to others");
                    try {
                        disp_send_to_others.qspn_manager.send_etp(fwd_etp);
                    }
                    catch (QspnNotAcceptedError e) {
                        // a broadcast will never get a return value nor an error
                        assert_not_reached();
                    }
                    catch (RPCError e) {
                        log_error(@"QspnManager.got_etp_from_arc: RPCError in send to broadcast to others: $(e.message)");
                    }
                }
            }
        }
    }
}
