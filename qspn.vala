/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2014-2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
    internal Gee.EqualDataFunc<IQspnArc> equal_func_iqspnarc;
    internal void init_equal_func_iqspnarc()
    {
        equal_func_iqspnarc = (a, b) => a.i_qspn_equals(b);
    }

    internal errordomain ArcRemovedError {
        GENERIC
    }

    internal errordomain AcyclicError {
        GENERIC
    }

    internal errordomain ArcNotFoundError {
        GENERIC
    }

    internal ITasklet tasklet;
    public class QspnManager : Object, IQspnManagerSkeleton
    {
        internal static Gee.EqualDataFunc<PairFingerprints> equal_func_pair_fingerprints = (a, b) => a.equals(b);

        public static void init
                      (ITasklet _tasklet,
                       int _max_paths,
                       double _max_common_hops_ratio,
                       int _arc_timeout,
                       IQspnThresholdCalculator _threshold_calculator
                      )
        {
            // Register serializable types
            typeof(NullCost).class_peek();
            typeof(DeadCost).class_peek();
            typeof(EtpPath).class_peek();
            typeof(EtpMessage).class_peek();
            tasklet = _tasklet;
            max_paths = _max_paths;
            max_common_hops_ratio = _max_common_hops_ratio;
            arc_timeout = _arc_timeout;
            threshold_calculator = _threshold_calculator;
        }

        public static void init_rngen(IRandomNumberGenerator? rngen=null, uint32? seed=null)
        {
            PRNGen.init_rngen(rngen, seed);
        }

        private static int max_paths;
        private static double max_common_hops_ratio;
        private static int arc_timeout;
        private static IQspnThresholdCalculator threshold_calculator;

        internal IQspnMyNaddr my_naddr;
        internal ArrayList<IQspnArc> my_arcs;
        internal HashMap<IQspnArc,IQspnNaddr?> arc_to_naddr;
        internal HashMap<int, IQspnArc> id_arc_map;
        internal ArrayList<IQspnFingerprint> my_fingerprints;
        internal ArrayList<int> my_nodes_inside;
        internal IQspnStubFactory stub_factory;
        private int connectivity_from_level;
        private int connectivity_to_level;
        internal static int levels;
        internal static int[] gsizes;
        private bool bootstrap_complete;
        private int guest_gnode_level;
        private int host_gnode_level;
        private ITaskletHandle? periodical_update_tasklet = null;
        private ArrayList<IQspnArc> queued_arcs;
        private ArrayList<PairFingerprints> pending_gnode_split;
        // This collection can be accessed by index (level) and then by iteration on the
        //  values. This is useful when we want to iterate on a certain level.
        //  In addition we can specify a level and then refer by index to the
        //  position. This is useful when we want to remove one item.
        internal ArrayList<HashMap<int, Destination>> destinations;

        // The hook on a particular network has completed; the module is bootstrap_complete.
        public signal void qspn_bootstrap_complete();
        // The first valid ETP from this module should have been processed by our neighbors.
        public signal void presence_notified();
        // An arc has been removed from my list. May happen because of a bad link or
        // because of other events.
        public signal void arc_removed(IQspnArc arc, bool bad_link=false);
        // A gnode (or node) is now known on the network and the first path towards
        //  it is now available to this node.
        public signal void destination_added(HCoord h);
        // A gnode (or node) has been removed from the network and the last path
        //  towards it has been deleted from this node.
        public signal void destination_removed(HCoord h);
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
        // A gnode has splitted and the part which has this fingerprint MUST migrate.
        public signal void gnode_splitted(IQspnArc a, HCoord d, IQspnFingerprint fp);
        // This identity has been dismissed.
        public signal void remove_identity();

        // No default constructor */
        private QspnManager() {
            assert_not_reached();
        }

        private bool is_main_identity {
            get {
                return connectivity_from_level == 0;
            }
        }

        /* 3 types of constructor */
        public QspnManager.create_net(IQspnMyNaddr my_naddr,
                           IQspnFingerprint my_fingerprint,
                           IQspnStubFactory stub_factory
                           )
        {
            this.my_naddr = my_naddr;
            // This is a *main identity*, not a *connectivity* one.
            connectivity_from_level = 0;
            connectivity_to_level = 0;
            this.stub_factory = stub_factory;
            pending_gnode_split = new ArrayList<PairFingerprints>((owned) equal_func_pair_fingerprints);
            // empty set of arcs
            init_equal_func_iqspnarc();
            my_arcs = new ArrayList<IQspnArc>((owned) equal_func_iqspnarc);
            arc_to_naddr = new HashMap<IQspnArc,IQspnNaddr?>(null, (owned) equal_func_iqspnarc);
            id_arc_map = new HashMap<int, IQspnArc>();
            // find parameters of the network
            levels = my_naddr.i_qspn_get_levels();
            gsizes = new int[levels];
            for (int l = 0; l < levels; l++) gsizes[l] = my_naddr.i_qspn_get_gsize(l);
            this.my_fingerprints = new ArrayList<IQspnFingerprint>();
            this.my_nodes_inside = new ArrayList<int>();
            // Fingerprint at level 0.
            my_fingerprints.add(my_fingerprint);
            // Nodes_inside at level 0.
            my_nodes_inside.add(1);
            // At upper levels
            for (int l = 1; l <= levels; l++)
            {
                my_fingerprints.add(my_fingerprints[l-1]
                        .i_qspn_construct(new ArrayList<IQspnFingerprint>()));
                my_nodes_inside.add(my_nodes_inside[l-1]);
            }
            // prepare empty map
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int l = 0; l < levels; l++) destinations.add(
                new HashMap<int, Destination>());
            // register an internal handler of my own signal bootstrap_complete:
            qspn_bootstrap_complete.connect(on_bootstrap_complete);
            // With this type of constructor we get immediately bootstrap_complete.
            bootstrap_complete = true;
            guest_gnode_level = levels;
            // Start a tasklet where we signal we have completed the bootstrap,
            // after a small wait, so that the signal actually is emitted after the costructor returns.
            BootstrapCompleteTasklet ts = new BootstrapCompleteTasklet();
            ts.mgr = this;
            tasklet.spawn(ts);
        }
        private class BootstrapCompleteTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public void * func()
            {
                tasklet.ms_wait(1);
                mgr.qspn_bootstrap_complete();
                return null;
            }
        }

        private delegate IQspnArc ArcToArcDelegate(IQspnArc old) throws ArcNotFoundError;

        public QspnManager.enter_net(
                           Gee.List<IQspnArc> internal_arc_set,
                           Gee.List<IQspnArc> internal_arc_prev_arc_set,
                           Gee.List<IQspnNaddr> internal_arc_peer_naddr_set,
                           Gee.List<IQspnArc> external_arc_set,
                           IQspnMyNaddr my_naddr,
                           IQspnFingerprint my_fingerprint,
                           ChangeFingerprintDelegate update_internal_fingerprints,
                           IQspnStubFactory stub_factory,
                           int guest_gnode_level,
                           int host_gnode_level,
                           QspnManager previous_identity
                           )
        {
            this.my_naddr = my_naddr;
            // This might be a *main identity*, or a *connectivity* one.
            connectivity_from_level = previous_identity.connectivity_from_level;
            connectivity_to_level = previous_identity.connectivity_to_level;
            assert(connectivity_from_level < guest_gnode_level+1);
            if (connectivity_to_level > guest_gnode_level) connectivity_to_level = guest_gnode_level;
            this.stub_factory = stub_factory;
            pending_gnode_split = new ArrayList<PairFingerprints>((owned) equal_func_pair_fingerprints);
            // all the arcs
            init_equal_func_iqspnarc();
            my_arcs = new ArrayList<IQspnArc>((owned) equal_func_iqspnarc);
            arc_to_naddr = new HashMap<IQspnArc,IQspnNaddr?>(null, (owned) equal_func_iqspnarc);
            id_arc_map = new HashMap<int, IQspnArc>();
            assert(internal_arc_set.size == internal_arc_peer_naddr_set.size);
            assert(internal_arc_set.size == internal_arc_prev_arc_set.size);
            ArcToArcDelegate old_arc_to_new_arc = (old_arc) => {
                for (int i = 0; i < internal_arc_set.size; i++)
                {
                    if (internal_arc_prev_arc_set[i] == old_arc)
                        return internal_arc_set[i];
                }
                throw new ArcNotFoundError.GENERIC("");
            };
            for (int i = 0; i < internal_arc_set.size; i++)
            {
                IQspnArc internal_arc = internal_arc_set[i];
                IQspnArc internal_arc_prev_arc = internal_arc_prev_arc_set[i];
                IQspnNaddr internal_arc_peer_naddr = internal_arc_peer_naddr_set[i];
                // Check data right away
                IQspnCost c = internal_arc.i_qspn_get_cost();
                assert(c != null);

                // retrieve ID for the arc
                int arc_id = 0;
                try {
                    arc_id = previous_identity.try_retrieve_arc_id(internal_arc_prev_arc);
                } catch (ArcRemovedError e) {
                    // shouldn't happen in constructor.
                    assert_not_reached();
                }
                // memorize
                assert(! (internal_arc in my_arcs));
                my_arcs.add(internal_arc);
                arc_to_naddr[internal_arc] = internal_arc_peer_naddr;
                id_arc_map[arc_id] = internal_arc;
            }
            foreach (IQspnArc external_arc in external_arc_set)
            {
                // Check data right away
                IQspnCost c = external_arc.i_qspn_get_cost();
                assert(c != null);

                // generate ID for the arc
                int arc_id = 0;
                while (arc_id == 0 || id_arc_map.has_key(arc_id))
                {
                    arc_id = PRNGen.int_range(0, int.MAX);
                }
                // memorize
                assert(! (external_arc in my_arcs));
                my_arcs.add(external_arc);
                arc_to_naddr[external_arc] = null;
                id_arc_map[arc_id] = external_arc;
            }
            assert(host_gnode_level <= levels);
            assert(guest_gnode_level < host_gnode_level);
            // Prepare empty map, then import paths from ''previous_identity''.
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int l = 0; l < levels; l++) destinations.add(
                new HashMap<int, Destination>());
            for (int l = 0; l < guest_gnode_level; l++)
            {
                foreach (int pos in previous_identity.destinations[l].keys)
                {
                    Destination destination = previous_identity.destinations[l][pos];
                    Destination destination_copy = destination.copy(update_internal_fingerprints);
                    ArrayList<NodePath> np_to_del = new ArrayList<NodePath>();
                    foreach (NodePath np in destination_copy.paths)
                    {
                        try {
                            np.arc = old_arc_to_new_arc(np.arc);
                        } catch (ArcNotFoundError e) {
                            // This path is no more valid. Probably the arc has been removed for a link problem.
                            np_to_del.add(np);
                        }
                    }
                    // Remove invalid paths. If no more paths remain then destination_copy is not valid.
                    foreach (NodePath np in np_to_del) destination_copy.paths.remove(np);
                    if (destination_copy.paths.is_empty) continue;
                    // If destination_copy is valid, add it.
                    destinations[l][pos] = destination_copy;
                }
            }
            this.my_fingerprints = new ArrayList<IQspnFingerprint>();
            this.my_nodes_inside = new ArrayList<int>();
            // Fingerprint at level 0.
            my_fingerprints.add(my_fingerprint);
            // Nodes_inside at level 0.
            my_nodes_inside.add(1);
            // At upper levels
            for (int l = 1; l <= levels; l++)
            {
                my_fingerprints.add(my_fingerprints[l-1]
                        .i_qspn_construct(new ArrayList<IQspnFingerprint>()));
                my_nodes_inside.add(my_nodes_inside[l-1]);
            }
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // register an internal handler of my own signal bootstrap_complete:
            qspn_bootstrap_complete.connect(on_bootstrap_complete);
            // With this type of constructor we are not bootstrap_complete.
            bootstrap_complete = false;
            this.guest_gnode_level = guest_gnode_level;
            this.host_gnode_level = host_gnode_level;
            BootstrapPhaseTasklet ts = new BootstrapPhaseTasklet();
            ts.mgr = this;
            tasklet.spawn(ts);
        }

        public QspnManager.migration(
                           Gee.List<IQspnArc> internal_arc_set,
                           Gee.List<IQspnArc> internal_arc_prev_arc_set,
                           Gee.List<IQspnNaddr> internal_arc_peer_naddr_set,
                           Gee.List<IQspnArc> external_arc_set,
                           IQspnMyNaddr my_naddr,
                           IQspnFingerprint my_fingerprint,
                           ChangeFingerprintDelegate update_internal_fingerprints,
                           IQspnStubFactory stub_factory,
                           int guest_gnode_level,
                           int host_gnode_level,
                           QspnManager previous_identity
                           )
        {
            this.my_naddr = my_naddr;
            // This might be a *main identity*, or a *connectivity* one.
            connectivity_from_level = previous_identity.connectivity_from_level;
            connectivity_to_level = previous_identity.connectivity_to_level;
            assert(connectivity_from_level < guest_gnode_level+1);
            if (connectivity_to_level > guest_gnode_level) connectivity_to_level = guest_gnode_level;
            this.stub_factory = stub_factory;
            pending_gnode_split = new ArrayList<PairFingerprints>((owned) equal_func_pair_fingerprints);
            // all the arcs
            init_equal_func_iqspnarc();
            my_arcs = new ArrayList<IQspnArc>((owned) equal_func_iqspnarc);
            arc_to_naddr = new HashMap<IQspnArc,IQspnNaddr?>(null, (owned) equal_func_iqspnarc);
            id_arc_map = new HashMap<int, IQspnArc>();
            assert(internal_arc_set.size == internal_arc_peer_naddr_set.size);
            assert(internal_arc_set.size == internal_arc_prev_arc_set.size);
            ArcToArcDelegate old_arc_to_new_arc = (old_arc) => {
                for (int i = 0; i < internal_arc_set.size; i++)
                {
                    if (internal_arc_prev_arc_set[i] == old_arc)
                        return internal_arc_set[i];
                }
                throw new ArcNotFoundError.GENERIC("");
            };
            for (int i = 0; i < internal_arc_set.size; i++)
            {
                IQspnArc internal_arc = internal_arc_set[i];
                IQspnNaddr internal_arc_peer_naddr = internal_arc_peer_naddr_set[i];
                IQspnArc internal_arc_prev_arc = internal_arc_prev_arc_set[i];
                // Check data right away
                IQspnCost c = internal_arc.i_qspn_get_cost();
                assert(c != null);

                // retrieve ID for the arc
                int arc_id = 0;
                try {
                    arc_id = previous_identity.try_retrieve_arc_id(internal_arc_prev_arc);
                } catch (ArcRemovedError e) {
                    // shouldn't happen in constructor.
                    assert_not_reached();
                }
                // memorize
                assert(! (internal_arc in my_arcs));
                my_arcs.add(internal_arc);
                arc_to_naddr[internal_arc] = internal_arc_peer_naddr;
                id_arc_map[arc_id] = internal_arc;
            }
            foreach (IQspnArc external_arc in external_arc_set)
            {
                // Check data right away
                IQspnCost c = external_arc.i_qspn_get_cost();
                assert(c != null);

                // generate ID for the arc
                int arc_id = 0;
                while (arc_id == 0 || id_arc_map.has_key(arc_id))
                {
                    arc_id = PRNGen.int_range(0, int.MAX);
                }
                // memorize
                assert(! (external_arc in my_arcs));
                my_arcs.add(external_arc);
                arc_to_naddr[external_arc] = null;
                id_arc_map[arc_id] = external_arc;
            }
            assert(host_gnode_level <= levels);
            assert(guest_gnode_level < host_gnode_level);
            // Prepare empty map, then import paths from ''previous_identity''.
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int l = 0; l < levels; l++) destinations.add(
                new HashMap<int, Destination>());
            for (int l = 0; l < guest_gnode_level; l++)
            {
                foreach (int pos in previous_identity.destinations[l].keys)
                {
                    Destination destination = previous_identity.destinations[l][pos];
                    Destination destination_copy = destination.copy(update_internal_fingerprints);
                    ArrayList<NodePath> np_to_del = new ArrayList<NodePath>();
                    foreach (NodePath np in destination_copy.paths)
                    {
                        try {
                            np.arc = old_arc_to_new_arc(np.arc);
                        } catch (ArcNotFoundError e) {
                            // This path is no more valid. Probably the arc has been removed for a link problem.
                            np_to_del.add(np);
                        }
                    }
                    // Remove invalid paths. If no more paths remain then destination_copy is not valid.
                    foreach (NodePath np in np_to_del) destination_copy.paths.remove(np);
                    if (destination_copy.paths.is_empty) continue;
                    // If destination_copy is valid, add it.
                    destinations[l][pos] = destination_copy;
                }
            }
            this.my_fingerprints = new ArrayList<IQspnFingerprint>();
            this.my_nodes_inside = new ArrayList<int>();
            // Fingerprint at level 0.
            my_fingerprints.add(my_fingerprint);
            // Nodes_inside at level 0.
            my_nodes_inside.add(1);
            // At upper levels
            for (int l = 1; l <= levels; l++)
            {
                my_fingerprints.add(my_fingerprints[l-1]
                        .i_qspn_construct(new ArrayList<IQspnFingerprint>()));
                my_nodes_inside.add(my_nodes_inside[l-1]);
            }
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // register an internal handler of my own signal bootstrap_complete:
            qspn_bootstrap_complete.connect(on_bootstrap_complete);
            // With this type of constructor we are not bootstrap_complete.
            bootstrap_complete = false;
            this.guest_gnode_level = guest_gnode_level;
            this.host_gnode_level = host_gnode_level;
            BootstrapPhaseTasklet ts = new BootstrapPhaseTasklet();
            ts.mgr = this;
            tasklet.spawn(ts);
        }

        private class BootstrapPhaseTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public void * func()
            {
                mgr.bootstrap_phase();
                return null;
            }
        }
        private void bootstrap_phase()
        {
            queued_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            // Consider that if (arc_to_naddr[arc] == null) then it was not an internal_arc.
            foreach (IQspnArc arc in my_arcs) if (arc_to_naddr[arc] == null)
                queued_arcs.add(arc);
            while (! queued_arcs.is_empty && ! bootstrap_complete)
            {
                IQspnArc arc = queued_arcs.remove_at(0);
                int arc_id = 0;
                try {
                    arc_id = try_retrieve_arc_id(arc);
                } catch (ArcRemovedError e) {
                    continue;
                }
                EtpMessage? etp;
                bool bootstrap_in_progress;
                bool bad_answer;
                string message;
                bool bad_link;
                retrieve_full_etp(this, arc, out etp, out bootstrap_in_progress, out bad_answer, out message, out bad_link);
                if (bootstrap_in_progress) continue;
                if (bad_answer)
                {
                    arc_remove(arc);
                    warning(@"Qspn: bootstrap: $(message)");
                    arc_removed(arc, bad_link);
                    continue;
                }
                int lvl = my_naddr.i_qspn_get_coord_by_address(etp.node_address).lvl;
                if (lvl < guest_gnode_level || lvl >= host_gnode_level) continue;
                // Process etp. No forward is needed.
                // Revise the paths in it.
                Gee.List<NodePath> q;
                try
                {
                    q = revise_etp(etp, arc, arc_id, true);
                }
                catch (AcyclicError e)
                {
                    // Ignore this message
                    continue;
                }
                // Update my map. Collect changed paths.
                Collection<EtpPath> all_paths_set;
                Collection<HCoord> b_set;
                update_map(q, null,
                           out all_paths_set,
                           out b_set);
                finalize_paths(all_paths_set);
                // Re-evaluate informations on our g-nodes.
                bool changes_in_my_gnodes;
                update_clusters(out changes_in_my_gnodes);
                // Then exit bootstrap, process all arcs, send full ETP to all.
                exit_bootstrap_phase();
            }
            if (! bootstrap_complete)
            {
                int max_wait = 10000;
                // TODO max(10 sec, 1000 * max(bestpath(dst).rtt for dst in known_destinations))
                tasklet.ms_wait(max_wait);
                if (! bootstrap_complete)
                {
                    exit_bootstrap_phase();
                }
            }
        }

        private void exit_bootstrap_phase()
        {
            // Exit bootstrap.
            bootstrap_complete = true;
            guest_gnode_level = levels;
            qspn_bootstrap_complete();
            // Process all arcs.
            queued_arcs.clear();
            ArrayList<IQspnArc> my_arcs_copy = new ArrayList<IQspnArc>();
            my_arcs_copy.add_all(my_arcs);
            foreach (IQspnArc arc in my_arcs_copy)
            {
                int arc_id = 0;
                try {
                    arc_id = try_retrieve_arc_id(arc);
                } catch (ArcRemovedError e) {
                    continue;
                }
                EtpMessage? etp;
                bool bootstrap_in_progress;
                bool bad_answer;
                string message;
                bool bad_link;
                retrieve_full_etp(this, arc, out etp, out bootstrap_in_progress, out bad_answer, out message, out bad_link);
                if (bootstrap_in_progress) continue;
                if (bad_answer)
                {
                    arc_remove(arc);
                    warning(@"Qspn: exit_bootstrap: $(message)");
                    arc_removed(arc, bad_link);
                    continue;
                }
                // Process etp. No forward is needed.
                // Revise the paths in it.
                Gee.List<NodePath> q;
                try
                {
                    q = revise_etp(etp, arc, arc_id, true);
                }
                catch (AcyclicError e)
                {
                    // Ignore this message
                    continue;
                }
                // Update my map. Collect changed paths.
                Collection<EtpPath> all_paths_set;
                Collection<HCoord> b_set;
                update_map(q, null,
                           out all_paths_set,
                           out b_set);
                finalize_paths(all_paths_set);
                // Re-evaluate informations on our g-nodes.
                bool changes_in_my_gnodes;
                update_clusters(out changes_in_my_gnodes);
            }
            // Prepare full ETP and send to all my neighbors.
            publish_full_etp(this);
            tasklet.ms_wait(1000);
            presence_notified();
        }

        // Helper: get id of arc
        internal int try_retrieve_arc_id(IQspnArc arc) throws ArcRemovedError
        {
            foreach (int id in id_arc_map.keys)
            {
                if (id_arc_map[id].i_qspn_equals(arc))
                {
                    return id;
                }
            }
            throw new ArcRemovedError.GENERIC("The arc might have been just removed.");
        }

        // Helper: get arcs for a broadcast message to all.
        internal Gee.List<IQspnArc> get_arcs_broadcast_all()
        {
            var ret = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            ret.add_all(my_arcs);
            return ret;
        }
        // Helper: get arcs for a broadcast message to all but one.
        internal Gee.List<IQspnArc> get_arcs_broadcast_all_but_one(IQspnArc arc)
        {
            var ret = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc one in my_arcs) if (! arc.i_qspn_equals(one))
                ret.add(one);
            return ret;
        }

        private void on_bootstrap_complete()
        {
            // start in a tasklet the periodical send of full updates.
            PeriodicalUpdateTasklet ts = new PeriodicalUpdateTasklet();
            ts.mgr = this;
            periodical_update_tasklet = tasklet.spawn(ts);
        }
        private class PeriodicalUpdateTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public void * func()
            {
                mgr.periodical_update();
            }
        }
        /** Periodically update full
          */
        [NoReturn]
        private void periodical_update()
        {
            while (true)
            {
                tasklet.ms_wait(600000); // 10 minutes
                if (my_arcs.size == 0) continue;
                publish_full_etp(this);
            }
        }

        public void stop_operations()
        {
            if (periodical_update_tasklet != null)
            {
                periodical_update_tasklet.kill();
                periodical_update_tasklet = null;
            }
        }

        // The module is notified if an arc is added/changed/removed
        public void arc_add(IQspnArc arc)
        {
            // Check data right away
            IQspnCost c = arc.i_qspn_get_cost();
            assert(c != null);

            ArcAddTasklet ts = new ArcAddTasklet();
            ts.mgr = this;
            ts.arc = arc;
            tasklet.spawn(ts);
        }

        private class ArcAddTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public IQspnArc arc;
            public void * func()
            {
                mgr.tasklet_arc_add(arc);
                return null;
            }
        }
        private void tasklet_arc_add(IQspnArc arc)
        {
            // From outside the module is notified of the creation of this new arc.
            if (arc in my_arcs)
            {
                warning("QspnManager.arc_add: already in my arcs.");
                return;
            }
            // generate ID for the arc
            int arc_id = 0;
            while (arc_id == 0 || id_arc_map.has_key(arc_id))
            {
                arc_id = PRNGen.int_range(0, int.MAX);
            }
            // memorize
            my_arcs.add(arc);
            arc_to_naddr[arc] = null;
            id_arc_map[arc_id] = arc;

            // during bootstrap add the arc to queued_arcs and then return
            if (!bootstrap_complete)
            {
                queued_arcs.add(arc);
                return;
            }

            EtpMessage? etp;
            bool bootstrap_in_progress;
            bool bad_answer;
            string message;
            bool bad_link;
            retrieve_full_etp(this, arc, out etp, out bootstrap_in_progress, out bad_answer, out message, out bad_link);
            if (bootstrap_in_progress) return; // Give up. The neighbor will start a flood when its bootstrap is complete.
            if (bad_answer)
            {
                arc_remove(arc);
                warning(@"Qspn: arc_add: $(message)");
                arc_removed(arc, bad_link);
                return;
            }

            debug("Processing ETP from new arc.");
            // Got ETP from new neighbor/arc. Revise the paths in it.
            Gee.List<NodePath> q;
            try
            {
                q = revise_etp(etp, arc, arc_id, true);
            }
            catch (AcyclicError e)
            {
                // This should not happen.
                warning("QspnManager: arc_add: the neighbor produced an ETP with a cycle.");
                return;
            }
            // Update my map. Collect changed paths.
            Collection<EtpPath> all_paths_set;
            Collection<HCoord> b_set;
            update_map(q, null,
                       out all_paths_set,
                       out b_set);
            finalize_paths(all_paths_set);
            // If needed, spawn a new flood for the first detection of a gnode split.
            if (! b_set.is_empty)
                spawn_flood_first_detection_split(b_set);
            // Re-evaluate informations on our g-nodes.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // forward?
            if (((! all_paths_set.is_empty) ||
                changes_in_my_gnodes) &&
                my_arcs.size > 1 /*at least another neighbor*/ )
            {
                debug("Forward ETP to all but the new arc");
                send_etp_multi(this, prepare_fwd_etp(this, all_paths_set, etp), get_arcs_broadcast_all_but_one(arc));
            }

            // create a new etp for arc
            debug("Sending ETP to new arc");
            send_etp_uni(this, prepare_full_etp(this), true, arc);
            // That's it.
        }

        public void arc_is_changed(IQspnArc changed_arc)
        {
            // Check data right away
            IQspnCost c = changed_arc.i_qspn_get_cost();
            assert(c != null);

            ArcIsChangedTasklet ts = new ArcIsChangedTasklet();
            ts.mgr = this;
            ts.changed_arc = changed_arc;
            tasklet.spawn(ts);
        }
        private class ArcIsChangedTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public IQspnArc changed_arc;
            public void * func()
            {
                mgr.tasklet_arc_is_changed(changed_arc);
                return null;
            }
        }
        private void tasklet_arc_is_changed(IQspnArc changed_arc)
        {
            // From outside the module is notified that the cost of this arc of mine
            // is changed.
            if (!(changed_arc in my_arcs))
            {
                warning("QspnManager.arc_is_changed: not in my arcs.");
                return;
            }

            // manage my_arcs and id_arc_map
            int changed_arc_id = 0;
            try {
                changed_arc_id = try_retrieve_arc_id(changed_arc);
            } catch (ArcRemovedError e) {
                // shouldn't happen here: just verified the arc is in my_arcs.
                assert_not_reached();
            }
            // remove old instance, we do not know if it's the same instance
            my_arcs.remove(changed_arc);
            my_arcs.add(changed_arc);
            id_arc_map[changed_arc_id] = changed_arc;
            // the same change has to be done in all the involved NodePath
            for (int l = 0; l < levels; l++)
                foreach (Destination d in destinations[l].values)
                    foreach (NodePath np in d.paths)
            {
                if (np.arc.i_qspn_equals(changed_arc))
                {
                    np.arc = changed_arc;
                }
            }

            // during bootstrap do nothing
            if (!bootstrap_complete)
            {
                return;
            }

            // gather ETP from all of my arcs
            Collection<PairArcEtp> results =
                gather_full_etp_set(this, my_arcs, (arc, msg, bad_link) => {
                    // remove failed arcs and emit signal
                    arc_remove(arc);
                    warning(@"Qspn: arc_is_changed: $(msg)");
                    // emit signal
                    arc_removed(arc, bad_link);
                });
            // Got ETPs. Revise the paths in each of them.
            Gee.List<NodePath> q = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
            foreach (PairArcEtp pair in results)
            {
                int arc_id = 0;
                try {
                    arc_id = try_retrieve_arc_id(pair.a);
                } catch (ArcRemovedError e) {
                    continue;
                }
                try
                {
                    q.add_all(revise_etp(pair.m, pair.a, arc_id, true));
                }
                catch (AcyclicError e)
                {
                    // This should not happen.
                    warning(@"QspnManager: arc_changed: the neighbor with arc $(arc_id) produced an ETP with a cycle.");
                    // ignore this etp
                }
            }
            // Update my map. Collect changed paths.
            Collection<EtpPath> all_paths_set;
            Collection<HCoord> b_set;
            update_map(q, changed_arc,
                       out all_paths_set,
                       out b_set);
            finalize_paths(all_paths_set);
            // If needed, spawn a new flood for the first detection of a gnode split.
            if (! b_set.is_empty)
                spawn_flood_first_detection_split(b_set);
            // Re-evaluate informations on our g-nodes.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // send update?
            if ((! all_paths_set.is_empty) ||
                changes_in_my_gnodes)
            {
                // create a new etp for all.
                debug("Sending ETP to all");
                send_etp_multi(this, prepare_new_etp(this, all_paths_set), get_arcs_broadcast_all());
            }
        }

        public void arc_remove(IQspnArc removed_arc)
        {
            // Check data right away
            IQspnCost c = removed_arc.i_qspn_get_cost();
            assert(c != null);

            if (!(removed_arc in my_arcs))
            {
                warning("QspnManager.arc_remove: not in my arcs.");
                return;
            }
            int arc_id = 0;
            try {
                arc_id = try_retrieve_arc_id(removed_arc);
            } catch (ArcRemovedError e) {
                // shouldn't happen here: just verified the arc is in my_arcs.
                assert_not_reached();
            }

            // during bootstrap remove the arc from queued_arcs and then return
            if (!bootstrap_complete)
            {
                if (removed_arc in queued_arcs) queued_arcs.remove(removed_arc);
                return;
            }

            // First, remove the arc...
            my_arcs.remove(removed_arc);
            arc_to_naddr.unset(removed_arc);
            id_arc_map.unset(arc_id);
            // ... and all the NodePath from it.
            var dest_to_remove = new ArrayList<Destination>();
            var paths_to_add_to_all_paths = new ArrayList<EtpPath>();
            for (int l = 0; l < levels; l++) foreach (Destination d in destinations[l].values)
            {
                int i = 0;
                while (i < d.paths.size)
                {
                    NodePath np = d.paths[i];
                    if (np.arc.i_qspn_equals(removed_arc))
                    {
                        d.paths.remove_at(i);
                        path_removed(get_ret_path(np));
                        EtpPath p = prepare_path_for_sending(np);
                        p.cost = new DeadCost();
                        paths_to_add_to_all_paths.add(p);
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
                destination_removed(d.dest);
                destinations[d.dest.lvl].unset(d.dest.pos);
            }

            // Then proceed in a tasklet
            ArcRemoveTasklet ts = new ArcRemoveTasklet();
            ts.mgr = this;
            ts.removed_arc = removed_arc;
            ts.paths_to_add_to_all_paths = paths_to_add_to_all_paths;
            tasklet.spawn(ts);
        }
        private class ArcRemoveTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public IQspnArc removed_arc;
            public ArrayList<EtpPath> paths_to_add_to_all_paths;
            public void * func()
            {
                mgr.tasklet_arc_remove(removed_arc, paths_to_add_to_all_paths);
                return null;
            }
        }
        private void tasklet_arc_remove(IQspnArc removed_arc, ArrayList<EtpPath> paths_to_add_to_all_paths)
        {
            // From outside the module is notified that this arc of mine
            // has been removed.
            // Or, either, the module itself wants to remove this arc (possibly
            // because it failed to send a message).

            // We already removed the arc and all the NodePath from it.

            // Then do the same as when arc is changed and remember to add paths_to_add_to_all_paths
            // gather ETP from all of my arcs
            Collection<PairArcEtp> results =
                gather_full_etp_set(this, my_arcs, (arc, msg, bad_link) => {
                    // remove failed arcs and emit signal
                    arc_remove(arc);
                    warning(@"Qspn: arc_remove: $(msg)");
                    // emit signal
                    arc_removed(arc, bad_link);
                });
            // Got ETPs. Revise the paths in each of them.
            Gee.List<NodePath> q = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
            foreach (PairArcEtp pair in results)
            {
                int arc_m_id = 0;
                try {
                    arc_m_id = try_retrieve_arc_id(pair.a);
                } catch (ArcRemovedError e) {
                    continue;
                }
                try
                {
                    q.add_all(revise_etp(pair.m, pair.a, arc_m_id, true));
                }
                catch (AcyclicError e)
                {
                    // This should not happen.
                    warning(@"QspnManager: arc_remove: the neighbor with arc $(arc_m_id) produced an ETP with a cycle.");
                    // ignore this etp
                }
            }
            // Update my map. Collect changed paths.
            Collection<EtpPath> all_paths_set;
            Collection<HCoord> b_set;
            update_map(q, null,
                       out all_paths_set,
                       out b_set);
            all_paths_set.add_all(paths_to_add_to_all_paths);
            finalize_paths(all_paths_set);
            // If needed, spawn a new flood for the first detection of a gnode split.
            if (! b_set.is_empty)
                spawn_flood_first_detection_split(b_set);
            // Re-evaluate informations on our g-nodes.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // send update?
            if (((! all_paths_set.is_empty) ||
                changes_in_my_gnodes) &&
                my_arcs.size > 0 /*at least a neighbor remains*/ )
            {
                // create a new etp for all.
                debug("Sending ETP to all");
                send_etp_multi(this, prepare_new_etp(this, all_paths_set), get_arcs_broadcast_all());
            }
        }

        // Helper: revise an ETP, correct its id_list and the paths inside it.
        //  The ETP has been already checked with check_incoming_message.
        private Gee.List<NodePath> revise_etp(EtpMessage m, IQspnArc arc, int arc_id, bool is_full) throws AcyclicError
        {
            ArrayList<NodePath> ret = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
            HCoord v = my_naddr.i_qspn_get_coord_by_address(m.node_address);
            int i = v.lvl + 1;
            IQspnNaddr? old_peer_naddr = arc_to_naddr[arc];
            arc_to_naddr[arc] = m.node_address;
            bool peer_naddr_changed = false;
            if (old_peer_naddr != null)
            {
                if (old_peer_naddr.i_qspn_get_pos(v.lvl) != m.node_address.i_qspn_get_pos(v.lvl))
                {
                    peer_naddr_changed = true;
                }
            }
            // grouping rule on m.hops
            while ((! m.hops.is_empty) && m.hops[0].lvl < i-1)
            {
                m.hops.remove_at(0);
            }
            m.hops.insert(0, v);
            // acyclic rule on m.hops
            foreach (HCoord g in m.hops)
            {
                if (g.pos == my_naddr.i_qspn_get_pos(g.lvl))
                {
                    // the ETP has done a cycle
                    debug("Cyclic ETP dropped");
                    throw new AcyclicError.GENERIC("Cycle in ETP");
                }
            }
            // revise paths:
            // remove paths to ignore
            int j = 0;
            while (j < m.p_list.size)
            {
                EtpPath p = m.p_list[j];
                if (p.ignore_outside[i-1])
                {
                    m.p_list.remove_at(j);
                }
                else
                {
                    j++;
                }
            }
            // grouping rule
            foreach (EtpPath p in m.p_list)
            {
                while ((! p.hops.is_empty) && p.hops[0].lvl < i-1)
                {
                    p.hops.remove_at(0);
                    p.arcs.remove_at(0);
                }
                p.hops.insert(0, v);
                p.arcs.insert(0, arc_id);
            }
            // acyclic rule
            j = 0;
            while (j < m.p_list.size)
            {
                EtpPath p = m.p_list[j];
                bool cycle = false;
                foreach (HCoord g in p.hops)
                {
                    if (g.pos == my_naddr.i_qspn_get_pos(g.lvl))
                    {
                        cycle = true; // the path has done a cycle
                        break;
                    }
                }
                if (cycle)
                {
                    m.p_list.remove_at(j);
                }
                else
                {
                    j++;
                }
            }
            // intrinsic path to v
            EtpPath v_path = new EtpPath();
            v_path.hops = new ArrayList<HCoord>((a, b) => a.equals(b));
            v_path.hops.add(v);
            v_path.arcs = new ArrayList<int>();
            v_path.arcs.add(arc_id);
            v_path.cost = new NullCost();
            v_path.fingerprint = m.fingerprints[i-1];
            v_path.nodes_inside = m.nodes_inside[i-1];
            // ignore_outside is not important here.
            set_ignore_outside_null(v_path);
            m.p_list.add(v_path);
            if (peer_naddr_changed)
            {
                // intrinsic path to old_v
                HCoord old_v = new HCoord(v.lvl, old_peer_naddr.i_qspn_get_pos(v.lvl));
                EtpPath old_v_path = new EtpPath();
                old_v_path.hops = new ArrayList<HCoord>((a, b) => a.equals(b));
                old_v_path.hops.add(old_v);
                old_v_path.arcs = new ArrayList<int>();
                old_v_path.arcs.add(arc_id);
                old_v_path.cost = new DeadCost();
                old_v_path.fingerprint = m.fingerprints[i-1];
                old_v_path.nodes_inside = m.nodes_inside[i-1];
                // ignore_outside is not important here.
                set_ignore_outside_null(old_v_path);
                m.p_list.add(old_v_path);
            }
            // if it is a full etp
            if (is_full)
            {
                ArrayList<NodePath> m_a_set = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
                for (int l = 0; l < levels; l++)
                {
                    foreach (Destination d in destinations[l].values)
                    {
                        foreach (NodePath d_p in d.paths)
                        {
                            if (d_p.path.arcs[0] == arc_id)
                                m_a_set.add(d_p);
                        }
                    }
                }
                foreach (NodePath np in m_a_set)
                {
                    bool present = false;
                    foreach (EtpPath p in m.p_list)
                    {
                        if (np.hops_arcs_equal_etppath(p))
                        {
                            present = true;
                            break;
                        }
                    }
                    if (!present)
                    {
                        EtpPath p0 = new EtpPath();
                        p0.hops = new ArrayList<HCoord>((a, b) => a.equals(b));
                        p0.hops.add_all(np.path.hops);
                        p0.arcs = new ArrayList<int>();
                        p0.arcs.add_all(np.path.arcs);
                        p0.fingerprint = np.path.fingerprint;
                        p0.nodes_inside = np.path.nodes_inside;
                        p0.cost = new DeadCost();
                        // ignore_outside is not important here.
                        set_ignore_outside_null(p0);
                        NodePath np0 = new NodePath(arc, p0);
                        ret.add(np0);
                    }
                }
            }
            // return a collection of NodePath
            foreach (EtpPath p in m.p_list)
            {
                NodePath np = new NodePath(arc, p);
                ret.add(np);
            }
            return ret;
        }

        // Helper: if same dest has multiple paths with different fingerprint, only one is valid.
        // Requires: d is known destination.
        private IQspnFingerprint find_fingerprint(HCoord d)
        {
            // find current valid fingerprint of d
            assert(destinations[d.lvl].has_key(d.pos));
            assert(! destinations[d.lvl][d.pos].paths.is_empty);
            IQspnFingerprint? valid_fp_d = null;
            if (d.lvl > 0)
            {
                foreach (NodePath p in destinations[d.lvl][d.pos].paths)
                {
                    IQspnFingerprint fp_d_p = p.path.fingerprint;
                    if (valid_fp_d == null)
                    {
                        valid_fp_d = fp_d_p;
                    }
                    else
                    {
                        if (! fp_d_p.i_qspn_equals(valid_fp_d))
                            if (fp_d_p.i_qspn_elder_seed(valid_fp_d)) valid_fp_d = fp_d_p;
                    }
                }
            }
            else valid_fp_d = destinations[d.lvl][d.pos].paths[0].path.fingerprint;
            return valid_fp_d;
        }

        private class SignalToEmit : Object
        {
            private int t;
            // 1: path_added
            // 2: path_changed
            // 3: path_removed
            // 4: destination_added
            // 5: destination_removed
            public IQspnNodePath? p {
                get;
                private set;
                default = null;
            }
            public HCoord? h {
                get;
                private set;
                default = null;
            }
            public SignalToEmit.path_added(IQspnNodePath p)
            {
                t = 1;
                this.p = p;
            }
            public SignalToEmit.path_changed(IQspnNodePath p)
            {
                t = 2;
                this.p = p;
            }
            public SignalToEmit.path_removed(IQspnNodePath p)
            {
                t = 3;
                this.p = p;
            }
            public SignalToEmit.destination_added(HCoord h)
            {
                t = 4;
                this.h = h;
            }
            public SignalToEmit.destination_removed(HCoord h)
            {
                t = 5;
                this.h = h;
            }
            public bool is_path_added {
                get {
                    return t == 1;
                }
            }
            public bool is_path_changed {
                get {
                    return t == 2;
                }
            }
            public bool is_path_removed {
                get {
                    return t == 3;
                }
            }
            public bool is_destination_added {
                get {
                    return t == 4;
                }
            }
            public bool is_destination_removed {
                get {
                    return t == 5;
                }
            }
        }
        private class PairFingerprints : Object
        {
            private IQspnFingerprint fp1;
            private IQspnFingerprint fp2;
            public PairFingerprints(IQspnFingerprint fp1, IQspnFingerprint fp2)
            {
                this.fp1 = fp1;
                this.fp2 = fp2;
            }
            public bool equals(PairFingerprints o)
            {
                return fp1.i_qspn_equals(o.fp1) &&
                       fp2.i_qspn_equals(o.fp2);
            }
        }
        // Helper: update my map from a set of paths collected from a set
        // of ETP messages.
        internal void
        update_map(Collection<NodePath> q_set,
                   IQspnArc? a_changed,
                   out Collection<EtpPath> all_paths_set,
                   out Collection<HCoord> b_set)
        {
            // Let z_set[i] be the list of g-nodes of level *i* neighbors of my g-node of level *i*.
            ArrayList<ArrayList<HCoord>> z_set = new ArrayList<ArrayList<HCoord>>();
            for (int i = 0; i < levels; i++) z_set.add(my_gnode_neighbors(i));
            // q_set is the set of new paths that have been detected.
            // all_paths_set will be the set of paths that have been changed in my map
            //  so that we have to send an EtpPath for each of them to our neighbors
            //  in a forwarded EtpMessage.
            // b_set will be the set of g-nodes for which we have to flood a new
            //  ETP because of the rule of first split detection.
            all_paths_set = new ArrayList<EtpPath>();
            b_set = new ArrayList<HCoord>((a, b) => a.equals(b));
            // Group by destination, order keys by ascending level.
            HashMap<HCoord, ArrayList<NodePath>> q_by_dest = new HashMap<HCoord, ArrayList<NodePath>>(
                (a) => {return a.lvl*100+a.pos;},  /* hash_func */
                (a, b) => {return a.equals(b);});  /* equal_func */
            foreach (NodePath np in q_set)
            {
                HCoord d = np.path.hops.last();
                if (! (d in q_by_dest.keys)) q_by_dest[d] = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
                q_by_dest[d].add(np);
            }
            ArrayList<HCoord> sorted_keys = new ArrayList<HCoord>((a, b) => a.equals(b));
            sorted_keys.add_all(q_by_dest.keys);
            sorted_keys.sort((d0, d1) => {
                /*
                 * Return -1 if d0 should be examined before d1:
                 *  that is, if d0 has a level lower than d1;
                 *  or it has the same level 'l' AND
                 *  the shortest path to d0 has fewer hops of level 'l'
                 *  than the shortest path to d1.
                 * Return +1 if d1 should be examined before d0.
                 * Else, return 0.
                 */
                if (d0.lvl < d1.lvl) return -1;
                if (d0.lvl > d1.lvl) return 1;
                int l = d0.lvl;
                ArrayList<NodePath> qd0_set = q_by_dest[d0];
                qd0_set.sort((np1, np2) => {
                    // np1 > np2 <=> return +1
                    IQspnCost c1 = np1.cost;
                    IQspnCost c2 = np2.cost;
                    return c1.i_qspn_compare_to(c2);
                });
                NodePath best_d0 = qd0_set[0];
                int hops_in_l_d0 = 0;
                foreach (HCoord h in best_d0.path.hops) if (h.lvl == l) hops_in_l_d0++;
                ArrayList<NodePath> qd1_set = q_by_dest[d1];
                qd1_set.sort((np1, np2) => {
                    // np1 > np2 <=> return +1
                    IQspnCost c1 = np1.cost;
                    IQspnCost c2 = np2.cost;
                    return c1.i_qspn_compare_to(c2);
                });
                NodePath best_d1 = qd1_set[0];
                int hops_in_l_d1 = 0;
                foreach (HCoord h in best_d1.path.hops) if (h.lvl == l) hops_in_l_d1++;
                if (hops_in_l_d0 < hops_in_l_d1) return -1;
                if (hops_in_l_d0 > hops_in_l_d1) return 1;
                return 0;
            });
            foreach (HCoord d in sorted_keys)
            {
                ArrayList<NodePath> qd_set = q_by_dest[d];
                ArrayList<NodePath> md_set = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
                if (destinations[d.lvl].has_key(d.pos))
                {
                    Destination dd = destinations[d.lvl][d.pos];
                    md_set.add_all(dd.paths);
                }
                ArrayList<IQspnFingerprint> f1 = new ArrayList<IQspnFingerprint>((a, b) => a.i_qspn_equals(b));
                if (d.lvl > 0)
                    foreach (NodePath np in md_set)
                        if (! (np.path.fingerprint in f1))
                            f1.add(np.path.fingerprint);
                ArrayList<NodePath> od_set = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
                ArrayList<NodePath> vd_set = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
                ArrayList<SignalToEmit> sd = new ArrayList<SignalToEmit>();
                foreach (NodePath p1 in md_set)
                {
                    NodePath? p2 = null;
                    foreach (NodePath p_test in qd_set)
                    {
                        if (p_test.hops_arcs_equal(p1))
                        {
                            p2 = p_test;
                            break;
                        }
                    }
                    if (p2 != null)
                    {
                        if ((! p1.path.fingerprint.i_qspn_equals(p2.path.fingerprint))
                            ||
                            (p1.path.cost.i_qspn_important_variation(p2.path.cost))
                            ||
                            ((p1.path.nodes_inside * 1.1 < p2.path.nodes_inside) || (p1.path.nodes_inside * 0.9 > p2.path.nodes_inside)))
                        {
                            qd_set.remove(p2);
                            od_set.add(p2);
                            vd_set.add(p2);
                        }
                        else
                        {
                            qd_set.remove(p2);
                            od_set.add(p1);
                            if (a_changed != null && p1.arc.i_qspn_equals(a_changed))
                                vd_set.add(p1);
                        }
                    }
                    else
                    {
                        od_set.add(p1);
                        if (a_changed != null && p1.arc.i_qspn_equals(a_changed))
                            vd_set.add(p1);
                    }
                }
                od_set.add_all(qd_set);
                // sort od, then remove paths non-disjoint
                od_set.sort((np1, np2) => {
                    // np1 > np2 <=> return +1
                    IQspnCost c1 = np1.cost;
                    IQspnCost c2 = np2.cost;
                    return c1.i_qspn_compare_to(c2);
                });
                HashMap<HCoord, int> num_nodes_inside = new HashMap<HCoord, int>(
                    (a) => {return a.lvl*100+a.pos;},  /* hash_func */
                    (a, b) => {return a.equals(b);});  /* equal_func */
                int od_i = 0;
                while (od_i < od_set.size)
                {
                    NodePath p = od_set[od_i];
                    bool toremove = false;
                    for (int p_i = 0; p_i < p.path.hops.size-1; p_i++)
                    {
                        HCoord h = p.path.hops[p_i];
                        if (destinations[h.lvl].has_key(h.pos))
                        {
                            num_nodes_inside[h] = destinations[h.lvl][h.pos].nodes_inside;
                        }
                        else
                        {
                            toremove = true;
                            debug(@"Ignoring a path to ($(d.lvl), $(d.pos)) because I do not know yet hop ($(h.lvl), $(h.pos)).");
                            break;
                        }
                    }
                    if (toremove) od_set.remove_at(od_i);
                    else od_i++;
                }
                ArrayList<IQspnFingerprint> fd = new ArrayList<IQspnFingerprint>((a, b) => a.i_qspn_equals(b));
                ArrayList<NodePath> rd = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
                ArrayList<HCoord> vnd = new ArrayList<HCoord>((a, b) => a.equals(b));
                foreach (IQspnArc a in my_arcs) if (arc_to_naddr[a] != null)
                {
                    HCoord v = my_naddr.i_qspn_get_coord_by_address(arc_to_naddr[a]);
                    if (! (v in vnd)) vnd.add(v);
                }
                ArrayList<HCoord> z1d = new ArrayList<HCoord>((a, b) => a.equals(b));
                for (int i = 0; i < d.lvl; i++)
                {
                    foreach (HCoord g in z_set[i])
                    {
                        z1d.add(g);
                    }
                }
                double mch_ratio = max_common_hops_ratio;
                // find mch_ratio optimized for d, if we already know something about d.
                if (destinations[d.lvl].has_key(d.pos) && is_bootstrap_complete())
                {
                    Destination dd = destinations[d.lvl][d.pos];
                    int size = dd.nodes_inside;
                    ArrayList<IQspnArc> avail_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
                    Gee.List<IQspnNodePath> paths;
                    try {
                        paths = get_paths_to(d);
                    } catch (QspnBootstrapInProgressError e) {assert_not_reached();}
                    foreach (IQspnNodePath path in paths)
                    {
                        IQspnArc arc_path = path.i_qspn_get_arc();
                        if (! (arc_path in avail_arcs)) avail_arcs.add(arc_path);
                    }
                    int numgw = avail_arcs.size;
                    mch_ratio = get_mch_ratio(size, numgw);
                }
                foreach (NodePath p1 in od_set)
                {
                    if (p1.cost.i_qspn_is_dead()) break;
                    bool mandatory = false;
                    if (! (p1.path.fingerprint in fd))
                    {
                        mandatory = true;
                        fd.add(p1.path.fingerprint);
                    }
                    int g_i = 0;
                    while (g_i < vnd.size)
                    {
                        HCoord g = vnd[g_i];
                        if (! (g in p1.path.hops))
                        {
                            vnd.remove_at(g_i);
                            mandatory = true;
                        }
                        else
                        {
                            g_i++;
                        }
                    }
                    g_i = 0;
                    while (g_i < z1d.size)
                    {
                        HCoord g = z1d[g_i];
                        if (g in p1.path.hops)
                        {
                            z1d.remove_at(g_i);
                            mandatory = true;
                        }
                        else
                        {
                            g_i++;
                        }
                    }
                    if (mandatory)
                    {
                        rd.add(p1);
                    }
                    else if (rd.size < max_paths)
                    {
                        bool insert = true;
                        foreach (NodePath p2 in rd)
                        {
                            double total_hops = 0.0;
                            double common_hops = 0.0;
                            for (int g2_i = 0; g2_i < p2.path.hops.size-1; g2_i++)
                            {
                                HCoord g2 = p2.path.hops[g2_i];
                                int arc_in_g2 = p2.path.arcs[g2_i];
                                int arc_out_g2 = p2.path.arcs[g2_i+1];
                                double n_nodes = Math.floor(1.5 * Math.sqrt(num_nodes_inside[g2]));
                                total_hops += n_nodes;
                                if (g2 in p1.path.hops)
                                {
                                    if (arc_in_g2 in p1.path.arcs)
                                    {
                                        if (arc_out_g2 in p1.path.arcs) common_hops += n_nodes;
                                        else common_hops += Math.ceil(0.5 * n_nodes);
                                    }
                                    else
                                    {
                                        if (arc_out_g2 in p1.path.arcs) common_hops += Math.ceil(0.5 * n_nodes);
                                        else common_hops += 0.0;
                                    }
                                }
                            }
                            if (d.lvl > 0 && destinations[d.lvl].has_key(d.pos))
                            {
                                int num_nodes_inside_d = destinations[d.lvl][d.pos].nodes_inside;
                                double n_nodes = Math.floor(0.75 * Math.sqrt(num_nodes_inside_d));
                                if (n_nodes > 0.0) n_nodes -= 1.0;
                                if (n_nodes > 0.0)
                                {
                                    int arc_in_d = p2.path.arcs[p2.path.hops.size-1];
                                    total_hops += n_nodes;
                                    if (arc_in_d in p1.path.arcs)
                                    {
                                        common_hops += n_nodes;
                                    }
                                    else
                                    {
                                        common_hops += 0.0;
                                    }
                                }
                            }
                            if (total_hops > 0.0 && common_hops / total_hops > mch_ratio)
                            {
                                insert = false;
                                break;
                            }
                        }
                        if (insert)
                        {
                            rd.add(p1);
                        }
                    }
                }
                od_set = rd;
                // find current valid fingerprint of d
                IQspnFingerprint? valid_fp_d = null;
                if (d.lvl > 0)
                {
                    foreach (NodePath p in od_set)
                    {
                        IQspnFingerprint fp_d_p = p.path.fingerprint;
                        if (valid_fp_d == null)
                        {
                            valid_fp_d = fp_d_p;
                        }
                        else
                        {
                            if (! fp_d_p.i_qspn_equals(valid_fp_d))
                                if (fp_d_p.i_qspn_elder_seed(valid_fp_d)) valid_fp_d = fp_d_p;
                        }
                    }
                }
                // populate collections
                foreach (NodePath p in od_set)
                {
                    if (! (p in md_set))
                    {
                        IQspnFingerprint fp_d_p = p.path.fingerprint;
                        all_paths_set.add(prepare_path_for_sending(p));
                        if (d.lvl == 0)
                        {
                            sd.add(new SignalToEmit.path_added(get_ret_path(p)));
                        }
                        else
                        {
                            if (fp_d_p.i_qspn_equals(valid_fp_d))
                            {
                                sd.add(new SignalToEmit.path_added(get_ret_path(p)));
                                p.exposed = true;
                            }
                        }
                    }
                }
                foreach (NodePath p in md_set)
                {
                    IQspnFingerprint fp_d_p = p.path.fingerprint;
                    if (! (p in od_set))
                    {
                        EtpPath pp = prepare_path_for_sending(p);
                        pp.cost = new DeadCost();
                        all_paths_set.add(pp);
                        if (d.lvl == 0)
                        {
                            sd.add(new SignalToEmit.path_removed(get_ret_path(p)));
                        }
                        else
                        {
                            if (p.exposed)
                            {
                                sd.add(new SignalToEmit.path_removed(get_ret_path(p)));
                            }
                        }
                    }
                    else
                    {
                        NodePath p1 = od_set[od_set.index_of(p)];
                        if (p in vd_set)
                        {
                            all_paths_set.add(prepare_path_for_sending(p1));
                            if (d.lvl == 0)
                            {
                                sd.add(new SignalToEmit.path_changed(get_ret_path(p1)));
                            }
                            else
                            {
                                if (p.exposed)
                                {
                                    if (fp_d_p.i_qspn_equals(valid_fp_d))
                                    {
                                        sd.add(new SignalToEmit.path_changed(get_ret_path(p1)));
                                        p1.exposed = true;
                                    }
                                    else
                                    {
                                        sd.add(new SignalToEmit.path_removed(get_ret_path(p)));
                                    }
                                }
                                else
                                {
                                    if (fp_d_p.i_qspn_equals(valid_fp_d))
                                    {
                                        sd.add(new SignalToEmit.path_added(get_ret_path(p1)));
                                        p1.exposed = true;
                                    }
                                }
                            }
                        }
                    }
                }
                if (md_set.is_empty && !od_set.is_empty)
                {
                    sd.insert(0, new SignalToEmit.destination_added(d));
                }
                if (!md_set.is_empty && od_set.is_empty)
                {
                    sd.add(new SignalToEmit.destination_removed(d));
                }

                // update memory
                if (od_set.is_empty)
                {
                    if (destinations[d.lvl].has_key(d.pos))
                        destinations[d.lvl].unset(d.pos);
                }
                else
                {
                    destinations[d.lvl][d.pos] = new Destination(d, od_set);
                }
                // signals
                foreach (SignalToEmit s in sd)
                {
                    if (s.is_destination_added)
                        destination_added(s.h);
                    else if (s.is_path_added)
                        path_added(s.p);
                    else if (s.is_path_changed)
                        path_changed(s.p);
                    else if (s.is_path_removed)
                        path_removed(s.p);
                    else if (s.is_destination_removed)
                        destination_removed(s.h);
                }
                // check fingerprints
                if (d.lvl > 0)
                {
                    if (destinations[d.lvl].has_key(d.pos))
                    {
                        Destination _d = destinations[d.lvl][d.pos];
                        ArrayList<NodePath> _d_paths = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
                        _d_paths.add_all(_d.paths);
                        ArrayList<IQspnFingerprint> f2 = new ArrayList<IQspnFingerprint>((a, b) => a.i_qspn_equals(b));
                        foreach (NodePath np in _d_paths)
                            if (! (np.path.fingerprint in f2))
                                f2.add(np.path.fingerprint);
                        if (f2.size > 1)
                        {
                            // first detection of a split?
                            foreach (IQspnFingerprint fp in f2)
                            {
                                if (! (fp in f1))
                                {
                                    // prepare to propagate the information back.
                                    if (! (d in b_set)) b_set.add(d);
                                    break;
                                }
                            }
                            // wait the threshold, then signal the split
                            IQspnFingerprint? fp_eldest = null;
                            foreach (IQspnFingerprint fp in f2)
                            {
                                if (fp_eldest == null || fp.i_qspn_elder_seed(fp_eldest))
                                    fp_eldest = fp;
                            }
                            NodePath? bp_eldest = null;
                            foreach (NodePath np in _d_paths)
                            {
                                if (np.path.fingerprint.i_qspn_equals(fp_eldest))
                                {
                                    if (bp_eldest == null || bp_eldest.cost.i_qspn_compare_to(np.cost) > 0)
                                        bp_eldest = np;
                                }
                            }
                            f2.remove(fp_eldest);
                            foreach (IQspnFingerprint fp in f2)
                            {
                                NodePath? bp = null;
                                foreach (NodePath np in _d_paths)
                                {
                                    if (np.path.fingerprint.i_qspn_equals(fp))
                                    {
                                        if (bp == null || bp.cost.i_qspn_compare_to(np.cost) > 0)
                                            bp = np;
                                    }
                                }
                                SignalSplitTasklet ts = new SignalSplitTasklet();
                                ts.mgr = this;
                                ts.fp_eldest = fp_eldest;
                                ts.fp = fp;
                                ts.bp_eldest = bp_eldest;
                                ts.bp = bp;
                                ts.d = d;
                                tasklet.spawn(ts);
                            }
                        }
                    }
                }
            }
        }
        private void finalize_paths(Collection<EtpPath> all_paths_set)
        {
            foreach (EtpPath p in all_paths_set) set_ignore_outside_for_sending(this, p);
        }
        private class SignalSplitTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public IQspnFingerprint fp_eldest;
            public IQspnFingerprint fp;
            public NodePath bp_eldest;
            public NodePath bp;
            public HCoord d;
            public void * func()
            {
                mgr.signal_split(fp_eldest, fp, bp_eldest, bp, d);
                return null;
            }
        }
        private void signal_split(
                IQspnFingerprint fp_eldest,
                IQspnFingerprint fp,
                NodePath bp_eldest,
                NodePath bp,
                HCoord d)
        {
            PairFingerprints pair = new PairFingerprints(fp_eldest, fp);
            if (pair in pending_gnode_split) return;
            pending_gnode_split.add(pair);
            int threshold_msec =
                threshold_calculator
                .i_qspn_calculate_threshold
                (get_ret_path(bp_eldest),
                 get_ret_path(bp));
            tasklet.ms_wait(threshold_msec);
            pending_gnode_split.remove(pair);
            if (destinations[d.lvl].has_key(d.pos))
            {
                Destination _d = destinations[d.lvl][d.pos];
                bool present = false;
                foreach (NodePath np in _d.paths)
                {
                    if (np.path.fingerprint.i_qspn_equals(fp_eldest))
                    {
                        present = true;
                        break;
                    }
                }
                if (present)
                {
                    foreach (IQspnArc a in my_arcs) if (arc_to_naddr[a] != null)
                    {
                        HCoord v = my_naddr.i_qspn_get_coord_by_address(arc_to_naddr[a]);
                        if (v.equals(d))
                        {
                            foreach (NodePath np in _d.paths)
                            {
                                if (np.arc.i_qspn_equals(a))
                                {
                                    if (np.path.fingerprint.i_qspn_equals(fp))
                                        gnode_splitted(a, d, fp);
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Helper: get mch_ratio based on size of destination and
        //  number of available gateways
        double get_mch_ratio(int size, int numgw)
        {
            double l;
            if (numgw == 1) l = 0.45;
            else if (numgw == 2) l = 0.35;
            else if (numgw == 3) l = 0.27;
            else if (numgw == 4) l = 0.20;
            else if (numgw == 5) l = 0.15;
            else if (numgw == 6) l = 0.12;
            else if (numgw == 7) l = 0.10;
            else l = 0.08;
            double e = max_common_hops_ratio * l;
            double g;
            if (size < 10) g = 1.0;
            else if (size < 25) g = 0.9;
            else if (size < 75) g = 0.8;
            else if (size < 250) g = 0.6;
            else if (size < 750) g = 0.3;
            else if (size < 3000) g = 0.1;
            else g = 0.0001;
            return (max_common_hops_ratio - e) * g + e;
        }

        // Helper: Start, in a few seconds, a new flood of ETP because
        //  a gnode split has been detected for the first time.
        internal void spawn_flood_first_detection_split(Collection<HCoord> b_set)
        {
            FirstDetectionSplitTasklet ts = new FirstDetectionSplitTasklet();
            ts.mgr = this;
            ts.b_set = b_set;
            tasklet.spawn(ts);
        }
        private class FirstDetectionSplitTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public Collection<HCoord> b_set;
            public void * func()
            {
                mgr.start_flood_first_detection_split(b_set);
                return null;
            }
        }
        internal void start_flood_first_detection_split(Collection<HCoord> b_set)
        {
            tasklet.ms_wait(500);
            var etp_paths = new ArrayList<EtpPath>();
            foreach (HCoord g in b_set)
            {
                if (destinations[g.lvl].has_key(g.pos))
                {
                    Destination d = destinations[g.lvl][g.pos];
                    foreach (NodePath np in d.paths)
                    {
                        EtpPath p = prepare_path_for_sending(np);
                        set_ignore_outside_for_sending(this, p);
                        etp_paths.add(p);
                    }
                }
            }
            if (etp_paths.is_empty) return;
            debug("Sending ETP to all");
            send_etp_multi(this, prepare_new_etp(this, etp_paths), get_arcs_broadcast_all());
        }

        // Helper: update my clusters data, based on my current map, and tell
        //  if there has been a change. Also, in that case emit signals.
        private void update_clusters(out bool changes_in_my_gnodes)
        {
            // ArrayList<IQspnFingerprint> my_fingerprints;
            // ArrayList<int> my_nodes_inside;
            changes_in_my_gnodes = false;
            // for level 1
            {
                bool is_null_eldership = false;
                if (my_naddr.i_qspn_get_pos(0) >= gsizes[0])
                {
                    my_nodes_inside[0] = 0;
                    is_null_eldership = true;
                }
                Gee.List<IQspnFingerprint> fp_set = new ArrayList<IQspnFingerprint>((a, b) => a.i_qspn_equals(b));
                int nn_tot = 0;
                foreach (Destination d in destinations[0].values)
                {
                    NodePath? best_p = null;
                    foreach (NodePath p in d.paths)
                    {
                        if (best_p == null)
                        {
                            best_p = p;
                        }
                        else
                        {
                            if (p.cost.i_qspn_compare_to(best_p.cost) < 0)
                            {
                                best_p = p;
                            }
                        }
                    }
                    assert(best_p != null); // must not exist in 'destinations' one with empty 'paths'
                    fp_set.add(best_p.path.fingerprint);
                    nn_tot += 1;
                }
                IQspnFingerprint new_fp = my_fingerprints[0].i_qspn_construct(fp_set, is_null_eldership);
                IQspnFingerprint old_fp = my_fingerprints[1];
                my_fingerprints[1] = new_fp;
                if (! new_fp.i_qspn_equals(old_fp))
                {
                    changes_in_my_gnodes = true;
                    changed_fp(1);
                }
                int new_nn = my_nodes_inside[0] + nn_tot;
                if (new_nn != my_nodes_inside[1])
                {
                    my_nodes_inside[1] = new_nn;
                    changes_in_my_gnodes = true;
                    changed_nodes_inside(1);
                }
            }
            // for upper levels
            for (int i = 2; i <= levels; i++)
            {
                bool is_null_eldership = false;
                if (my_naddr.i_qspn_get_pos(i-1) >= gsizes[i-1])
                {
                    my_nodes_inside[i-1] = 0;
                    is_null_eldership = true;
                }
                Gee.List<IQspnFingerprint> fp_set = new ArrayList<IQspnFingerprint>((a, b) => a.i_qspn_equals(b));
                int nn_tot = 0;
                foreach (Destination d in destinations[i-1].values)
                {
                    IQspnFingerprint? fp_d = null;
                    int nn_d = -1;
                    NodePath? best_p = null;
                    foreach (NodePath p in d.paths)
                    {
                        IQspnFingerprint fp_d_p = p.path.fingerprint;
                        int nn_d_p = p.path.nodes_inside;
                        if (fp_d == null)
                        {
                            fp_d = fp_d_p;
                            nn_d = nn_d_p;
                            best_p = p;
                        }
                        else
                        {
                            if (! fp_d.i_qspn_equals(fp_d_p))
                            {
                                if (! fp_d.i_qspn_elder_seed(fp_d_p))
                                {
                                    fp_d = fp_d_p;
                                    nn_d = nn_d_p;
                                    best_p = p;
                                }
                            }
                            else
                            {
                                if (p.cost.i_qspn_compare_to(best_p.cost) < 0)
                                {
                                    nn_d = nn_d_p;
                                    best_p = p;
                                }
                            }
                        }
                    }
                    fp_set.add(fp_d);
                    nn_tot += nn_d;
                }
                IQspnFingerprint new_fp = my_fingerprints[i-1].i_qspn_construct(fp_set, is_null_eldership);
                IQspnFingerprint old_fp = my_fingerprints[i];
                my_fingerprints[i] = new_fp;
                if (! new_fp.i_qspn_equals(old_fp))
                {
                    changes_in_my_gnodes = true;
                    changed_fp(i);
                }
                int new_nn = my_nodes_inside[i-1] + nn_tot;
                int old_nn = my_nodes_inside[i];
                my_nodes_inside[i] = new_nn;
                if (new_nn != old_nn)
                {
                    changes_in_my_gnodes = true;
                    changed_nodes_inside(i);
                }
            }
        }

        // Helper: my g-node neighbors of level i.
        ArrayList<HCoord> my_gnode_neighbors(int i)
        {
            int j = levels;
            /* Let *x_set* contain each g-node *x* of level from *i* to *j* - 1 that I have as a destination in my map
             *  (that is, x ∈ g<sub>i+1</sub>(n) ∪ ... ∪ g<sub>j</sub>(n))
             */
            ArrayList<Destination> x_set = new ArrayList<Destination>();
            for (int l = i; l < j; l++)
            {
                x_set.add_all(destinations[l].values);
            }
            /* Let *y_set* contain each g-node *y* of level *i* neighbor of g<sub>i</sub>(n) that I have as a hop in my map
             *  (that is, y ∈ 𝛤<sub>i</sub>(g<sub>i</sub>(n)), y ∈ g<sub>i+1</sub>(n))
             */
            ArrayList<HCoord> y_set = new ArrayList<HCoord>((a, b) => a.equals(b));
            foreach (Destination x in x_set)
            {
                foreach (NodePath np in x.paths)
                {
                    HCoord y = np.path.hops[0];
                    if (y.lvl == i)
                    {
                        if (! (y in y_set)) y_set.add(y);
                        continue;
                    }
                    for (int i_np = 1; i_np < np.path.hops.size; i_np++)
                    {
                        HCoord y_prev = np.path.hops[i_np - 1];
                        y = np.path.hops[i_np];
                        if (y.lvl == i && y_prev.lvl < i)
                        {
                            if (! (y in y_set)) y_set.add(y);
                            break;
                        }
                    }
                }
            }
            return y_set;
        }

        /** Provides a collection of known destinations
          */
        public Gee.List<HCoord> get_known_destinations(int lvl) throws QspnBootstrapInProgressError
        {
            assert(lvl < levels);
            if (lvl >= guest_gnode_level)
                throw new QspnBootstrapInProgressError.GENERIC(@"I am still in bootstrap at level $(guest_gnode_level).");
            var ret = new ArrayList<HCoord>((a, b) => a.equals(b));
            foreach (Destination d in destinations[lvl].values)
                ret.add(d.dest);
            return ret;
        }

        /** Is this a known destination
          */
        public bool is_known_destination(HCoord d) throws QspnBootstrapInProgressError
        {
            assert(d.lvl < levels);
            int lvl = d.lvl;
            if (lvl >= guest_gnode_level)
                throw new QspnBootstrapInProgressError.GENERIC(@"I am still in bootstrap at level $(guest_gnode_level).");
            return destinations[lvl].has_key(d.pos);
        }

        /** Get fingerprint of a known destination
          */
        public IQspnFingerprint get_fingerprint_of_known_destination(HCoord d) throws QspnBootstrapInProgressError
        {
            assert(is_known_destination(d));
            return find_fingerprint(d);
        }

        /** Provides a collection of known paths to a destination
          */
        public Gee.List<IQspnNodePath> get_paths_to(HCoord d) throws QspnBootstrapInProgressError
        {
            assert(d.lvl < levels);
            if (d.lvl >= guest_gnode_level)
                throw new QspnBootstrapInProgressError.GENERIC(@"I am still in bootstrap at level $(guest_gnode_level).");
            var ret = new ArrayList<IQspnNodePath>();
            if (d.lvl < levels && destinations[d.lvl].has_key(d.pos))
            {
                // prepare known valid paths
                if (d.lvl == 0)
                {
                    foreach (NodePath p in destinations[d.lvl][d.pos].paths)
                    {
                        ret.add(get_ret_path(p));
                    }
                }
                else
                {
                    IQspnFingerprint? valid_fp_d = find_fingerprint(d);
                    foreach (NodePath p in destinations[d.lvl][d.pos].paths)
                    {
                        IQspnFingerprint fp_d_p = p.path.fingerprint;
                        // check current valid fingerprint of d
                        if (fp_d_p.i_qspn_equals(valid_fp_d))
                            ret.add(get_ret_path(p));
                    }
                }
            }
            return ret;
        }

        /** Gives the estimate of the number of nodes that are inside my g-node
          */
        public int get_nodes_inside(int level) throws QspnBootstrapInProgressError
        {
            assert(level <= levels);
            if (level >= guest_gnode_level+1)
                throw new QspnBootstrapInProgressError.GENERIC(@"I am still in bootstrap at level $(guest_gnode_level).");
            return my_nodes_inside[level];
        }

        /** Gives the fingerprint of my g-node
          */
        public IQspnFingerprint get_fingerprint(int level) throws QspnBootstrapInProgressError
        {
            assert(level <= levels);
            if (level >= guest_gnode_level+1)
                throw new QspnBootstrapInProgressError.GENERIC(@"I am still in bootstrap at level $(guest_gnode_level).");
            return my_fingerprints[level];
        }

        /** Informs whether the node has completed bootstrap
          */
        public bool is_bootstrap_complete()
        {
            return guest_gnode_level == levels;
        }

        /** Gives the list of current arcs
          */
        public Gee.List<IQspnArc> current_arcs()
        {
            var ret = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            ret.add_all(my_arcs);
            return ret;
        }

        /** Gives the Netsukuku-address of the peer at one of my arcs
          */
        public IQspnNaddr? get_naddr_for_arc(IQspnArc arc)
        {
            if (arc in my_arcs) return arc_to_naddr[arc];
            return null;
        }

        /** Make this identity a ''connectivity'' one.
          */
        public void make_connectivity(int connectivity_from_level,
                                      int connectivity_to_level,
                                      ChangeNaddrDelegate update_naddr)
        {
            assert(connectivity_from_level <= connectivity_to_level);
            assert(connectivity_to_level <= levels);
            assert(connectivity_from_level > 0);
            int old_id = my_naddr.i_qspn_get_pos(connectivity_from_level-1);
            assert(old_id < gsizes[connectivity_from_level-1]);
            // Gather arcs that are internal to connectivity_from_level-1. Put in `internal_arcs`.
            ArrayList<IQspnArc> internal_arcs = new ArrayList<IQspnArc>();
            foreach (IQspnArc arc in my_arcs)
             if (arc_to_naddr[arc] != null)
             if (my_naddr.i_qspn_get_coord_by_address(arc_to_naddr[arc]).lvl < connectivity_from_level-1)
                internal_arcs.add(arc);
            // Apply `update_naddr` to `my_naddr`.
            my_naddr = (IQspnMyNaddr)update_naddr(my_naddr);
            // Apply `update_naddr` to `arc_to_naddr` for each internal arc.
            foreach (IQspnArc arc in internal_arcs)
                arc_to_naddr[arc] = update_naddr(arc_to_naddr[arc]);
            this.connectivity_from_level = connectivity_from_level;
            this.connectivity_to_level = connectivity_to_level;
            int new_id = my_naddr.i_qspn_get_pos(connectivity_from_level-1);
            assert(new_id >= gsizes[connectivity_from_level-1]);
            // Re-evaluate informations on our g-nodes.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // Send a ETP in few moments to all neighbors outside 'connectivity_from_level' - 1
            //  in which we say we dont have any more a path to old_id.
            PublishConnectivityTasklet ts = new PublishConnectivityTasklet();
            ts.mgr = this;
            ts.delay = 50;
            ts.old_lvl = connectivity_from_level - 1;
            ts.old_pos = old_id;
            tasklet.spawn(ts);
        }
        private class PublishConnectivityTasklet : Object, ITaskletSpawnable
        {
            public weak QspnManager mgr;
            public int delay;
            public int old_pos;
            public int old_lvl;
            public void * func()
            {
                tasklet.ms_wait(delay);
                publish_connectivity(mgr, old_pos, old_lvl);
                return null;
            }
        }

        /** Exit the current network with my g-node of level `lvl`.
          */
        public void exit_network(int lvl)
        {
            // remove paths
            for (int l = lvl; l < levels; l++)
            {
                var dest_to_remove = new ArrayList<Destination>();
                dest_to_remove.add_all(destinations[l].values);
                foreach (Destination d in dest_to_remove)
                {
                    destinations[d.dest.lvl].unset(d.dest.pos);
                    foreach (NodePath np in d.paths)
                    {
                        path_removed(get_ret_path(np));
                    }
                    destination_removed(d.dest);
                }
            }
            // Re-evaluate informations on our g-nodes.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // remove arcs
            ArrayList<IQspnArc> arcs_to_remove = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc arc in my_arcs)
            {
                if (arc_to_naddr[arc] == null) continue;
                int arc_lvl = my_naddr.i_qspn_get_coord_by_address(arc_to_naddr[arc]).lvl;
                if (arc_lvl >= lvl) arcs_to_remove.add(arc);
            }
            foreach (IQspnArc arc in arcs_to_remove)
            {
                arc_remove(arc);
                arc_removed(arc);
            }
        }

        /** Remove outer arcs from this connectivity identity.
          */
        public void remove_outer_arcs()
        {
            assert(! is_main_identity);
            ArrayList<IQspnArc> arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            arcs.add_all(my_arcs);
            foreach (IQspnArc arc in arcs)
            {
                // This is the connectivity identity: we should have the peer_naddr for all the internal arcs.
                bool remove = false;
                if (arc_to_naddr[arc] == null)
                {
                    remove = true;
                }
                else
                {
                    // Check the neighbor address.
                    IQspnNaddr addr = arc_to_naddr[arc];
                    int lvl = my_naddr.i_qspn_get_coord_by_address(addr).lvl;
                    if (lvl >= connectivity_to_level) remove = true;
                }
                if (remove)
                {
                    arc_remove(arc);
                    arc_removed(arc);
                }
            }
        }

        /** Check if this connectivity identity can be removed without causing
          * the split of its g-nodes.
          */
        public bool check_connectivity()
        {
            // Requires: a lock has been acquired on all g-nodes this identity
            //  belongs to at level from connectivity_from_level to connectivity_to_level.
            assert(! is_main_identity);
            assert(connectivity_to_level >= connectivity_from_level);
            assert(connectivity_to_level <= levels);
            int i = connectivity_from_level - 1;
            int j = connectivity_to_level;
            /* Search a level *i* where my g<sub>i</sub>(n) (that is, the g-node of
             *  level *i* where n belongs) has some neighbor (g-nodes of level *i*)
             *  inside g<sub>i+1</sub>(n)
             */
            while (true)
            {
                if (j <= i) return true;
                // private ArrayList<HashMap<int, Destination>> destinations;
                HashMap<int, Destination> destinations_i = destinations[i];
                if (! destinations_i.is_empty) break;
                i++;
            }
            /* Let *x_set* contain each g-node *x* of level from *i* to *j* - 1 that I have as a destination in my map
             *  (that is, x ∈ g<sub>i+1</sub>(n) ∪ ... ∪ g<sub>j</sub>(n))
             */
            ArrayList<Destination> x_set = new ArrayList<Destination>();
            for (int l = i; l < j; l++)
            {
                x_set.add_all(destinations[l].values);
            }
            /* Let *y_set* contain each g-node *y* of level *i* neighbor of g<sub>i</sub>(n) that I have as a hop in my map
             *  (that is, y ∈ 𝛤<sub>i</sub>(g<sub>i</sub>(n)), y ∈ g<sub>i+1</sub>(n))
             */
            ArrayList<HCoord> y_set = new ArrayList<HCoord>((a, b) => a.equals(b));
            foreach (Destination x in x_set)
            {
                foreach (NodePath np in x.paths)
                {
                    HCoord y = np.path.hops[0];
                    if (y.lvl == i)
                    {
                        if (! (y in y_set)) y_set.add(y);
                        continue;
                    }
                    for (int i_np = 1; i_np < np.path.hops.size; i_np++)
                    {
                        HCoord y_prev = np.path.hops[i_np - 1];
                        y = np.path.hops[i_np];
                        if (y.lvl == i && y_prev.lvl < i)
                        {
                            if (! (y in y_set)) y_set.add(y);
                            break;
                        }
                    }
                }
            }
            // For each destination *x* in *x_set*
            foreach (Destination x in x_set)
            {
                // For each g-gateway *y* in *y_set*
                foreach (HCoord y in y_set)
                {
                    if (! x.dest.equals(y))
                    {
                        bool path_found = false;
                        foreach (NodePath np in x.paths)
                        {
                            if (y in np.path.hops)
                            {
                                path_found = true;
                                break;
                            }
                        }
                        if (!path_found) return false;
                    }
                }
            }
            return true;
        }

        /** Prepare to remove this connectivity g-node.
          */
        public void prepare_destroy()
        {
            assert(! is_main_identity);
            int i = connectivity_from_level - 1;
            ArrayList<IQspnArc> internal_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc arc in my_arcs)
            {
                // This is the connectivity identity: we should have the peer_naddr for all the internal arcs.
                if (arc_to_naddr[arc] == null) continue;
                int lvl = my_naddr.i_qspn_get_coord_by_address(arc_to_naddr[arc]).lvl;
                if (lvl < i) internal_arcs.add(arc);
            }
            IQspnManagerStub stub_send_to_internal =
                    stub_factory.i_qspn_get_broadcast(
                    internal_arcs,
                    // If a neighbor doesnt send its ACK repeat the message via tcp
                    new MissingArcPrepareDestroy(this));
            try {
                stub_send_to_internal.got_prepare_destroy();
            } catch (DeserializeError e) {
                // a broadcast will never get a return value nor an error
                assert_not_reached();
            } catch (StubError e) {
                critical(@"QspnManager.prepare_destroy: StubError in broadcast sending to internal_arcs: $(e.message)");
            }
        }

        /** Signal the imminent removal of this identity (connectivity or not).
          */
        public void destroy()
        {
            // Could be also connectivity_from_level == 0.
            int i = connectivity_from_level - 1;
            ArrayList<IQspnArc> outer_w_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc arc in my_arcs)
            {
                if (arc_to_naddr[arc] == null) continue;
                int lvl = my_naddr.i_qspn_get_coord_by_address(arc_to_naddr[arc]).lvl;
                if (lvl >= i) outer_w_arcs.add(arc);
            }
            IQspnManagerStub stub_send_to_outer =
                    stub_factory.i_qspn_get_broadcast(
                    outer_w_arcs,
                    // If a neighbor doesnt send its ACK repeat the message via tcp
                    new MissingArcDestroy(this));
            try {
                stub_send_to_outer.got_destroy();
            } catch (DeserializeError e) {
                // a broadcast will never get a return value nor an error
                assert_not_reached();
            } catch (StubError e) {
                critical(@"QspnManager.destroy: StubError in broadcast sending to outer_w_arcs: $(e.message)");
            }
        }

        /* Remotable methods
         */
        internal class Timer : Object
        {
            private TimeVal start;
            private long msec_ttl;
            public Timer(long msec_ttl)
            {
                start = TimeVal();
                start.get_current_time();
                this.msec_ttl = msec_ttl;
            }

            private long get_lap()
            {
                TimeVal lap = TimeVal();
                lap.get_current_time();
                long sec = lap.tv_sec - start.tv_sec;
                long usec = lap.tv_usec - start.tv_usec;
                if (usec < 0)
                {
                    usec += 1000000;
                    sec--;
                }
                return sec*1000000 + usec;
            }

            public bool is_expired()
            {
                return get_lap() > msec_ttl*1000;
            }
        }

        public IQspnEtpMessage
        get_full_etp(IQspnAddress requesting_address,
                     CallerInfo? _rpc_caller=null)
        throws QspnNotAcceptedError, QspnBootstrapInProgressError
        {
            if (!bootstrap_complete) throw new QspnBootstrapInProgressError.GENERIC("I am still in bootstrap.");

            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from this arc.
            IQspnArc? arc = null;
            Timer t = new Timer(arc_timeout);
            while (true)
            {
                foreach (IQspnArc _arc in my_arcs)
                {
                    if (_arc.i_qspn_comes_from(rpc_caller))
                    {
                        arc = _arc;
                        break;
                    }
                }
                if (arc != null) break;
                if (t.is_expired()) break;
                tasklet.ms_wait(10);
            }
            if (arc == null) throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");

            if (! (requesting_address is IQspnNaddr))
            {
                // The module only knows this class that implements IQspnAddress, so this
                //  should not happen. But the rest of the code, who knows? So to be sure
                //  we check. If it is the case remove the arc.
                arc_remove(arc);
                warning(@"Qspn: RPC:get_full_etp: requesting_address is not IQspnNaddr");
                // emit signal
                arc_removed(arc);
                tasklet.exit_tasklet(null);
            }
            IQspnNaddr requesting_naddr = (IQspnNaddr) requesting_address;
            arc_to_naddr[arc] = requesting_naddr;

            HCoord b = my_naddr.i_qspn_get_coord_by_address(requesting_naddr);
            var etp_paths = new ArrayList<EtpPath>();
            for (int l = b.lvl; l < levels; l++) foreach (Destination d in destinations[l].values)
            {
                foreach (NodePath np in d.paths)
                {
                    bool found = false;
                    foreach (HCoord h in np.path.hops)
                    {
                        if (h.equals(b)) found = true;
                        if (found) break;
                    }
                    if (!found)
                    {
                        EtpPath p = prepare_path_for_sending(np);
                        set_ignore_outside_for_sending(this, p);
                        etp_paths.add(p);
                    }
                }
            }
            debug("Sending ETP on request");
            var ret = prepare_new_etp(this, etp_paths);
            assert(check_outgoing_message(ret, my_naddr));
            return ret;
        }

        public void send_etp(IQspnEtpMessage m, bool is_full, CallerInfo? _rpc_caller=null) throws QspnNotAcceptedError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from this arc.
            IQspnArc? arc = null;
            Timer t = new Timer(arc_timeout);
            while (true)
            {
                foreach (IQspnArc _arc in my_arcs)
                {
                    if (_arc.i_qspn_comes_from(rpc_caller))
                    {
                        arc = _arc;
                        break;
                    }
                }
                if (arc != null) break;
                if (t.is_expired()) break;
                tasklet.ms_wait(10);
            }
            if (arc == null) throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");

            if (! (arc in my_arcs)) return;
            int arc_id = 0;
            try {
                arc_id = try_retrieve_arc_id(arc);
            } catch (ArcRemovedError e) {
                // shouldn't happen here: just verified the arc is in my_arcs.
                assert_not_reached();
            }
            debug("An incoming ETP is received");
            if (m == null)
            {
                arc_remove(arc);
                warning(@"Qspn: RPC:send_etp: m is <null>");
                // emit signal
                arc_removed(arc);
                tasklet.exit_tasklet(null);
            }
            if (! (m is EtpMessage))
            {
                // The module only knows this class that implements IQspnEtpMessage, so this
                //  should not happen. But the rest of the code, who knows? So to be sure
                //  we check. If it is the case, remove the arc.
                arc_remove(arc);
                warning(@"Qspn: RPC:send_etp: m is not EtpMessage, but $(m.get_type().name())");
                // emit signal
                arc_removed(arc);
                tasklet.exit_tasklet(null);
            }
            EtpMessage etp = (EtpMessage) m;
            if (! check_incoming_message(etp, my_naddr))
            {
                // We check the correctness of a message from another node.
                // If the message is junk, remove the arc.
                arc_remove(arc);
                warning(@"Qspn: RPC:send_etp: check_incoming_message not passed");
                // emit signal
                arc_removed(arc);
                tasklet.exit_tasklet(null);
            }

            bool must_exit_bootstrap_phase = false;
            // If it is during bootstrap:
            if (!bootstrap_complete)
            {
                // Check the sender.
                int lvl = my_naddr.i_qspn_get_coord_by_address(etp.node_address).lvl;
                if (lvl >= guest_gnode_level)
                {
                    // The sender is outside my hooking gnode. Ignore it.
                    return;
                }
                else
                {
                    // The sender is inside my hooking gnode.
                    // Check the destinations.
                    bool has_path_to_into_gnode = false;
                    foreach (EtpPath etp_path in etp.p_list)
                    {
                        int this_lvl = etp_path.hops.last().lvl;
                        if (this_lvl == host_gnode_level - 1)
                        {
                            has_path_to_into_gnode = true;
                            break;
                        }
                    }
                    if (! has_path_to_into_gnode)
                    {
                        // The ETP hasn't any destination outside my hooking gnode. Ignore it.
                        return;
                    }
                    else
                    {
                        // The ETP has a destination outside my hooking gnode and inside the gnode we hook into.
                        must_exit_bootstrap_phase = true;
                    }
                }
            }

            debug("Processing incoming ETP");
            // Revise the paths in it.
            Gee.List<NodePath> q;
            try
            {
                q = revise_etp(etp, arc, arc_id, is_full);
            }
            catch (AcyclicError e)
            {
                // Ignore this message
                return;
            }
            // Update my map. Collect changed paths.
            Collection<EtpPath> all_paths_set;
            Collection<HCoord> b_set;
            update_map(q, null,
                       out all_paths_set,
                       out b_set);
            finalize_paths(all_paths_set);
            // If needed, spawn a new flood for the first detection of a gnode split.
            if (! b_set.is_empty)
                spawn_flood_first_detection_split(b_set);
            // Re-evaluate informations on our g-nodes.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);

            if (must_exit_bootstrap_phase)
            {
                // now exit bootstrap, process all arcs, send full ETP to all.
                exit_bootstrap_phase();
                // No forward is needed.
                return;
            }

            // forward?
            if (((! all_paths_set.is_empty) ||
                changes_in_my_gnodes) &&
                my_arcs.size > 1 /*at least another neighbor*/ )
            {
                debug("Forward ETP to all but the sender");
                send_etp_multi(this, prepare_fwd_etp(this, all_paths_set, etp), get_arcs_broadcast_all_but_one(arc));
            }
        }

        public void got_prepare_destroy(CallerInfo? _rpc_caller=null)
        {
            // Verify that I am a ''connectivity'' identity.
            if (is_main_identity) tasklet.exit_tasklet(null);
            // TODO check that the order came from the Coordinator
            // Propagate order
            prepare_destroy();
            // Wait 10 sec
            tasklet.ms_wait(10000);
            // Emit signal to remove this identity.
            remove_identity();
        }

        public void got_destroy(CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from this arc.
            IQspnArc? arc = null;
            Timer t = new Timer(arc_timeout);
            while (true)
            {
                foreach (IQspnArc _arc in my_arcs)
                {
                    if (_arc.i_qspn_comes_from(rpc_caller))
                    {
                        arc = _arc;
                        break;
                    }
                }
                if (arc != null) break;
                if (t.is_expired()) break;
                tasklet.ms_wait(10);
            }
            if (arc == null) tasklet.exit_tasklet(null);

            // remove the arc
            arc_remove(arc);
            arc_removed(arc);
        }

        ~QspnManager()
        {
            stop_operations();
        }
    }
}
