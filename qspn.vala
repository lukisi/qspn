/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2014-2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
    public interface IQspnNaddr : Object, IQspnAddress
    {
        public abstract int i_qspn_get_levels();
        public abstract int i_qspn_get_gsize(int level);
        public abstract int i_qspn_get_pos(int level);
    }

    public interface IQspnMyNaddr : Object, IQspnNaddr
    {
        public abstract HCoord i_qspn_get_coord_by_address(IQspnNaddr dest);
    }

    public interface IQspnFingerprint : Object
    {
        public abstract bool i_qspn_equals(IQspnFingerprint other);
        public abstract int i_qspn_get_level();
        public abstract IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingerprints);
        public abstract bool i_qspn_elder_seed(IQspnFingerprint other);
    }

    public interface IQspnCost : Object
    {
        public abstract int i_qspn_compare_to(IQspnCost other);
        public abstract IQspnCost i_qspn_add_segment(IQspnCost other);
        public abstract bool i_qspn_important_variation(IQspnCost new_cost);
        public abstract bool i_qspn_is_dead();
        public abstract bool i_qspn_is_null();
    }

    // Cost: Zero.
    internal class NullCost : Object, IQspnCost
    {
        public int i_qspn_compare_to(IQspnCost other)
        {
            if (other is NullCost) return 0;
            return -1;
        }

        public IQspnCost i_qspn_add_segment(IQspnCost other)
        {
            return other;
        }

        public bool i_qspn_important_variation(IQspnCost new_cost)
        {
            if (new_cost is NullCost) return false;
            return true;
        }

        public bool i_qspn_is_null()
        {
            return true;
        }

        public bool i_qspn_is_dead()
        {
            return false;
        }
    }

    // Cost: Infinity.
    internal class DeadCost : Object, IQspnCost
    {
        public int i_qspn_compare_to(IQspnCost other)
        {
            if (other is DeadCost) return 0;
            return 1;
        }

        public IQspnCost i_qspn_add_segment(IQspnCost other)
        {
            return this;
        }

        public bool i_qspn_important_variation(IQspnCost new_cost)
        {
            if (new_cost is DeadCost) return false;
            return true;
        }

        public bool i_qspn_is_null()
        {
            return false;
        }

        public bool i_qspn_is_dead()
        {
            return true;
        }
    }

    public interface IQspnArc : Object
    {
        public abstract IQspnCost i_qspn_get_cost();
        public abstract IQspnNaddr i_qspn_get_naddr();
        public abstract bool i_qspn_equals(IQspnArc other);
        public abstract bool i_qspn_comes_from(CallerInfo rpc_caller);
    }

    internal class EtpMessage : Object, Json.Serializable, IQspnEtpMessage
    {
        public IQspnNaddr node_address {get; set;}
        public Gee.List<IQspnFingerprint> fingerprints {get; set;}
        public Gee.List<int> nodes_inside {get; set;}
        public Gee.List<HCoord> hops {get; set;}
        public Gee.List<EtpPath> p_list {get; set;}

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "node_address":
            case "node-address":
                try {
                    @value = deserialize_i_qspn_naddr(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "fingerprints":
                try {
                    @value = deserialize_list_i_qspn_fingerprint(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "nodes_inside":
            case "nodes-inside":
                try {
                    @value = deserialize_list_int(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "hops":
                try {
                    @value = deserialize_list_hcoord(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "p_list":
            case "p-list":
                try {
                    @value = deserialize_list_etp_path(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "node_address":
            case "node-address":
                return serialize_i_qspn_naddr((IQspnNaddr)@value);
            case "fingerprints":
                return serialize_list_i_qspn_fingerprint((Gee.List<IQspnFingerprint>)@value);
            case "nodes_inside":
            case "nodes-inside":
                return serialize_list_int((Gee.List<int>)@value);
            case "hops":
                return serialize_list_hcoord((Gee.List<HCoord>)@value);
            case "p_list":
            case "p-list":
                return serialize_list_etp_path((Gee.List<EtpPath>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }
    }

    internal class EtpPath : Object, Json.Serializable
    {
        public Gee.List<HCoord> hops {get; set;}
        public Gee.List<int> arcs {get; set;}
        public IQspnCost cost {get; set;}
        public IQspnFingerprint fingerprint {get; set;}
        public int nodes_inside {get; set;}
        public Gee.List<bool> ignore_outside {get; set;}

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "hops":
                try {
                    @value = deserialize_list_hcoord(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "arcs":
                try {
                    @value = deserialize_list_int(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "cost":
                try {
                    @value = deserialize_i_qspn_cost(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "fingerprint":
                try {
                    @value = deserialize_i_qspn_fingerprint(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "nodes_inside":
            case "nodes-inside":
                try {
                    @value = deserialize_int(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "ignore_outside":
            case "ignore-outside":
                try {
                    @value = deserialize_list_bool(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "hops":
                return serialize_list_hcoord((Gee.List<HCoord>)@value);
            case "arcs":
                return serialize_list_int((Gee.List<int>)@value);
            case "cost":
                return serialize_i_qspn_cost((IQspnCost)@value);
            case "fingerprint":
                return serialize_i_qspn_fingerprint((IQspnFingerprint)@value);
            case "nodes_inside":
            case "nodes-inside":
                return serialize_int((int)@value);
            case "ignore_outside":
            case "ignore-outside":
                return serialize_list_bool((Gee.List<bool>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }
    }

    internal class NodePath : Object
    {
        public NodePath(IQspnArc arc, EtpPath path)
        {
            this.arc = arc;
            this.path = path;
            exposed = false;
        }
        public IQspnArc arc;
        public EtpPath path;
        public bool exposed;
        private IQspnCost _cost;
        public IQspnCost cost {
            get {
                _cost = arc.i_qspn_get_cost().i_qspn_add_segment(path.cost);
                return _cost;
            }
        }
        public bool hops_arcs_equal(NodePath q)
        {
            return hops_arcs_equal_etppath(q.path);
        }
        public bool hops_arcs_equal_etppath(EtpPath p)
        {
            Gee.List<HCoord> my_hops_list = path.hops;
            Gee.List<HCoord> p_hops_list = p.hops;
            if (my_hops_list.size != p_hops_list.size) return false;
            for (int i = 0; i < my_hops_list.size; i++)
                if (! (my_hops_list[i].equals(p_hops_list[i]))) return false;
            Gee.List<int> my_arcs_list = path.arcs;
            Gee.List<int> p_arcs_list = p.arcs;
            if (my_arcs_list.size != p_arcs_list.size) return false;
            for (int i = 0; i < my_arcs_list.size; i++)
                if (my_arcs_list[i] != p_arcs_list[i]) return false;
            return true;
        }
    }

    public interface IQspnHop : Object
    {
        public abstract int i_qspn_get_arc_id();
        public abstract HCoord i_qspn_get_hcoord();
    }

    public interface IQspnNodePath : Object
    {
        public abstract IQspnArc i_qspn_get_arc();
        public abstract Gee.List<IQspnHop> i_qspn_get_hops();
        public abstract IQspnCost i_qspn_get_cost();
        public abstract int i_qspn_get_nodes_inside();
        public abstract bool equals(IQspnNodePath other);
    }

    internal class RetHop : Object, IQspnHop
    {
        public int arc_id;
        public HCoord hcoord;

        /* Interface */
        public int i_qspn_get_arc_id() {return arc_id;}
        public HCoord i_qspn_get_hcoord() {return hcoord;}
    }

    internal class RetPath : Object, IQspnNodePath
    {
        public IQspnArc arc;
        public ArrayList<IQspnHop> hops;
        public IQspnCost cost;
        public int nodes_inside;

        /* Interface */
        public IQspnArc i_qspn_get_arc() {return arc;}
        public Gee.List<IQspnHop> i_qspn_get_hops() {return hops;}
        public IQspnCost i_qspn_get_cost() {return cost;}
        public int i_qspn_get_nodes_inside() {return nodes_inside;}
        public bool equals(IQspnNodePath other)
        {
            if (arc.i_qspn_equals(other.i_qspn_get_arc()))
            {
                Gee.List<IQspnHop> other_hops = other.i_qspn_get_hops();
                if (other_hops.size != hops.size) return false;
                for (int i = 0; i < hops.size; i++)
                {
                    IQspnHop hop = hops[i];
                    IQspnHop other_hop = other_hops[i];
                    if (hop.i_qspn_get_arc_id() != other_hop.i_qspn_get_arc_id()) return false;
                }
                return true;
            }
            return false;
        }
    }

    public interface IQspnThresholdCalculator : Object
    {
        public abstract int i_qspn_calculate_threshold(IQspnNodePath p1, IQspnNodePath p2);
    }

    public interface IQspnMissingArcHandler : Object
    {
        public abstract void i_qspn_missing(IQspnArc arc);
    }

    public interface IQspnStubFactory : Object
    {
        public abstract IQspnManagerStub
                        i_qspn_get_broadcast(
                            Gee.List<IQspnArc> arcs,
                            IQspnMissingArcHandler? missing_handler=null
                        );
        public abstract IQspnManagerStub
                        i_qspn_get_tcp(
                            IQspnArc arc,
                            bool wait_reply=true
                        );
    }

    internal class Destination : Object
    {
        public Destination(HCoord dest, Gee.List<NodePath> paths)
        {
            assert(! paths.is_empty);
            this.dest = dest;
            this.paths = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
            this.paths.add_all(paths);
        }
        public HCoord dest;
        public ArrayList<NodePath> paths;

        private IQspnFingerprint? fpd;
        private int nnd;
        private NodePath? best_p;
        public void evaluate()
        {
            fpd = null;
            nnd = -1;
            best_p = null;
            foreach (NodePath p in paths)
            {
                IQspnFingerprint fpdp = p.path.fingerprint;
                int nndp = p.path.nodes_inside;
                if (fpd == null)
                {
                    fpd = fpdp;
                    nnd = nndp;
                    best_p = p;
                }
                else
                {
                    if (dest.lvl == 0)
                    {
                        if (p.cost.i_qspn_compare_to(best_p.cost) < 0)
                        {
                            fpd = fpdp;
                            nnd = nndp;
                            best_p = p;
                        }
                    }
                    else
                    {
                        if (! fpd.i_qspn_equals(fpdp))
                        {
                            if (! fpd.i_qspn_elder_seed(fpdp))
                            {
                                fpd = fpdp;
                                nnd = nndp;
                                best_p = p;
                            }
                        }
                        else
                        {
                            if (p.cost.i_qspn_compare_to(best_p.cost) < 0)
                            {
                                nnd = nndp;
                                best_p = p;
                            }
                        }
                    }
                }
            }
        }

        public NodePath best_path {
            get {
                evaluate();
                return best_p;
            }
        }

        public int nodes_inside {
            get {
                evaluate();
                return nnd;
            }
        }

        public IQspnFingerprint fingerprint {
            get {
                evaluate();
                return fpd;
            }
        }

        public Destination copy()
        {
            HCoord destination_copy_dest = new HCoord(this.dest.lvl, this.dest.pos);
            ArrayList<NodePath> destination_copy_paths = new ArrayList<NodePath>();
            foreach (NodePath np in this.paths)
            {
                // np.path is serializable
                try {
                    destination_copy_paths.add(
                        new NodePath(
                            np.arc,
                            deserialize_etp_path(serialize_etp_path(np.path))
                            )
                        );
                } catch (HelperDeserializeError e) {
                    assert_not_reached();
                }
            }
            Destination destination_copy = new Destination(
                destination_copy_dest,
                destination_copy_paths
                );
            return destination_copy;
        }
    }

    internal errordomain AcyclicError {
        GENERIC
    }

    internal ITasklet tasklet;
    public class QspnManager : Object, IQspnManagerSkeleton
    {
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
        private static int max_paths;
        private static double max_common_hops_ratio;
        private static int arc_timeout;
        private static IQspnThresholdCalculator threshold_calculator;

        private IQspnMyNaddr my_naddr;
        private ArrayList<IQspnArc> my_arcs;
        private HashMap<int, IQspnArc> id_arc_map;
        private ArrayList<IQspnFingerprint> my_fingerprints;
        private ArrayList<int> my_nodes_inside;
        private IQspnStubFactory stub_factory;
        private int connectivity_from_level;
        private int connectivity_to_level;
        private int levels;
        private int[] gsizes;
        private bool bootstrap_complete;
        private int hooking_gnode_level;
        private int into_gnode_level;
        private ITaskletHandle? periodical_update_tasklet = null;
        private ArrayList<IQspnArc> queued_arcs;
        private ArrayList<PairFingerprints> pending_gnode_split;
        // This collection can be accessed by index (level) and then by iteration on the
        //  values. This is useful when we want to iterate on a certain level.
        //  In addition we can specify a level and then refer by index to the
        //  position. This is useful when we want to remove one item.
        private ArrayList<HashMap<int, Destination>> destinations;

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

        /* 3 types of constructor */
        public QspnManager.create_net(IQspnMyNaddr my_naddr,
                           IQspnFingerprint my_fingerprint,
                           IQspnStubFactory stub_factory
                           )
        {
            this.my_naddr = my_naddr;
            // This is a definitive address, not a ''connectivity'' one.
            connectivity_from_level = 0;
            connectivity_to_level = 0;
            this.stub_factory = stub_factory;
            pending_gnode_split = new ArrayList<PairFingerprints>((a, b) => a.equals(b));
            // empty set of arcs
            my_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            id_arc_map = new HashMap<int, IQspnArc>();
            // find parameters of the network
            levels = my_naddr.i_qspn_get_levels();
            gsizes = new int[levels];
            for (int l = 0; l < levels; l++) gsizes[l] = my_naddr.i_qspn_get_gsize(l);
            // Only the level 0 fingerprint is given. The other ones
            // will be constructed when the node has completed bootstrap.
            this.my_fingerprints = new ArrayList<IQspnFingerprint>();
            this.my_nodes_inside = new ArrayList<int>();
            // Fingerprint at level 0.
            my_fingerprints.add(my_fingerprint);
            // Nodes_inside at level 0.
            my_nodes_inside.add(1);
            for (int l = 1; l <= levels; l++)
            {
                // At start build fingerprint at level l with fingerprint at
                // level l-1 and an empty set.
                my_fingerprints.add(my_fingerprints[l-1]
                        .i_qspn_construct(new ArrayList<IQspnFingerprint>()));
                // The same with the number of nodes inside our g-node.
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
            hooking_gnode_level = levels;
            // Start a tasklet where we signal we have completed the bootstrap,
            // after a small wait, so that the signal actually is emitted after the costructor returns.
            BootstrapCompleteTasklet ts = new BootstrapCompleteTasklet();
            ts.mgr = this;
            tasklet.spawn(ts);
        }
        private class BootstrapCompleteTasklet : Object, ITaskletSpawnable
        {
            public QspnManager mgr;
            public void * func()
            {
                tasklet.ms_wait(1);
                mgr.qspn_bootstrap_complete();
                return null;
            }
        }

        public QspnManager.enter_net(IQspnMyNaddr my_naddr,
                           Gee.List<IQspnArc> my_arcs,
                           IQspnFingerprint my_fingerprint,
                           IQspnStubFactory stub_factory,
                           int hooking_gnode_level,
                           int into_gnode_level,
                           QspnManager previous_identity
                           )
        {
            this.my_naddr = my_naddr;
            // This might be a definitive address, or a ''connectivity'' one.
            connectivity_from_level = previous_identity.connectivity_from_level;
            connectivity_to_level = previous_identity.connectivity_to_level;
            this.stub_factory = stub_factory;
            pending_gnode_split = new ArrayList<PairFingerprints>((a, b) => a.equals(b));
            // all the arcs
            this.my_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            id_arc_map = new HashMap<int, IQspnArc>();
            foreach (IQspnArc arc in my_arcs)
            {
                // Check data right away
                IQspnCost c = arc.i_qspn_get_cost();
                assert(c != null);

                // generate ID for the arc
                int arc_id = 0;
                while (arc_id == 0 || id_arc_map.has_key(arc_id))
                {
                    arc_id = Random.int_range(0, int.MAX);
                }
                // memorize
                assert(! (arc in this.my_arcs));
                this.my_arcs.add(arc);
                id_arc_map[arc_id] = arc;
            }
            // find parameters of the network
            levels = my_naddr.i_qspn_get_levels();
            gsizes = new int[levels];
            for (int l = 0; l < levels; l++) gsizes[l] = my_naddr.i_qspn_get_gsize(l);
            assert(into_gnode_level <= levels);
            assert(hooking_gnode_level < into_gnode_level);
            // Prepare empty map, then import paths from ''previous_identity''.
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int l = 0; l < levels; l++) destinations.add(
                new HashMap<int, Destination>());
            for (int l = 0; l < hooking_gnode_level; l++)
            {
                foreach (int pos in previous_identity.destinations[l].keys)
                {
                    Destination destination = previous_identity.destinations[l][pos];
                    Destination destination_copy = destination.copy();
                    destinations[l][pos] = destination_copy;
                }
            }
            // Only the level 0 fingerprint is given.
            // The lower levels up to 'into_gnode_level' - 1 are immediately constructed
            //  from the imported map.
            // The higher levels will be constructed when the node has completed bootstrap.
            this.my_fingerprints = new ArrayList<IQspnFingerprint>();
            this.my_nodes_inside = new ArrayList<int>();
            // Fingerprint at level 0.
            my_fingerprints.add(my_fingerprint);
            // Nodes_inside at level 0. If this is a ''connectivity'' address we say we have 0 ''real'' nodes.
            if (connectivity_from_level > 0) my_nodes_inside.add(0);
            else my_nodes_inside.add(1);
            for (int l = 1; l <= levels; l++)
            {
                // At start build fingerprint at level l with fingerprint at
                // level l-1 and an empty set.
                my_fingerprints.add(my_fingerprints[l-1]
                        .i_qspn_construct(new ArrayList<IQspnFingerprint>()));
                // The same with the number of nodes inside our g-node.
                my_nodes_inside.add(my_nodes_inside[l-1]);
            }
            // The lower levels up to 'into_gnode_level' - 1 are now constructed.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // register an internal handler of my own signal bootstrap_complete:
            qspn_bootstrap_complete.connect(on_bootstrap_complete);
            // With this type of constructor we are not bootstrap_complete.
            bootstrap_complete = false;
            this.hooking_gnode_level = hooking_gnode_level;
            this.into_gnode_level = into_gnode_level;
            BootstrapPhaseTasklet ts = new BootstrapPhaseTasklet();
            ts.mgr = this;
            tasklet.spawn(ts);
        }

        public QspnManager.migration(IQspnMyNaddr my_naddr,
                           Gee.List<IQspnArc> my_arcs,
                           IQspnFingerprint my_fingerprint,
                           IQspnStubFactory stub_factory,
                           int hooking_gnode_level,
                           int into_gnode_level,
                           QspnManager previous_identity
                           )
        {
            this.my_naddr = my_naddr;
            // This might be a definitive address, or a ''connectivity'' one.
            connectivity_from_level = previous_identity.connectivity_from_level;
            connectivity_to_level = previous_identity.connectivity_to_level;
            this.stub_factory = stub_factory;
            pending_gnode_split = new ArrayList<PairFingerprints>((a, b) => a.equals(b));
            // all the arcs
            this.my_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            id_arc_map = new HashMap<int, IQspnArc>();
            foreach (IQspnArc arc in my_arcs)
            {
                // Check data right away
                IQspnCost c = arc.i_qspn_get_cost();
                assert(c != null);

                // generate ID for the arc
                int arc_id = 0;
                while (arc_id == 0 || id_arc_map.has_key(arc_id))
                {
                    arc_id = Random.int_range(0, int.MAX);
                }
                // memorize
                assert(! (arc in this.my_arcs));
                this.my_arcs.add(arc);
                id_arc_map[arc_id] = arc;
            }
            // find parameters of the network
            levels = my_naddr.i_qspn_get_levels();
            gsizes = new int[levels];
            for (int l = 0; l < levels; l++) gsizes[l] = my_naddr.i_qspn_get_gsize(l);
            assert(into_gnode_level <= levels);
            assert(hooking_gnode_level < into_gnode_level);
            // Prepare empty map, then import paths from ''previous_identity''.
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int l = 0; l < levels; l++) destinations.add(
                new HashMap<int, Destination>());
            for (int l = 0; l < hooking_gnode_level; l++)
            {
                foreach (int pos in previous_identity.destinations[l].keys)
                {
                    Destination destination = previous_identity.destinations[l][pos];
                    Destination destination_copy = destination.copy();
                    destinations[l][pos] = destination_copy;
                }
            }
            // Only the level 0 fingerprint is given.
            // The lower levels up to 'into_gnode_level' - 1 are immediately constructed
            //  from the imported map.
            // The higher levels will be constructed when the node has completed bootstrap.
            this.my_fingerprints = new ArrayList<IQspnFingerprint>();
            this.my_nodes_inside = new ArrayList<int>();
            // Fingerprint at level 0.
            my_fingerprints.add(my_fingerprint);
            // Nodes_inside at level 0. If this is a ''connectivity'' address we say we have 0 ''real'' nodes.
            if (connectivity_from_level > 0) my_nodes_inside.add(0);
            else my_nodes_inside.add(1);
            for (int l = 1; l <= levels; l++)
            {
                // At start build fingerprint at level l with fingerprint at
                // level l-1 and an empty set.
                my_fingerprints.add(my_fingerprints[l-1]
                        .i_qspn_construct(new ArrayList<IQspnFingerprint>()));
                // The same with the number of nodes inside our g-node.
                my_nodes_inside.add(my_nodes_inside[l-1]);
            }
            // The lower levels up to 'into_gnode_level' - 1 are now constructed.
            bool changes_in_my_gnodes;
            update_clusters(out changes_in_my_gnodes);
            // register an internal handler of my own signal bootstrap_complete:
            qspn_bootstrap_complete.connect(on_bootstrap_complete);
            // With this type of constructor we are not bootstrap_complete.
            bootstrap_complete = false;
            this.hooking_gnode_level = hooking_gnode_level;
            this.into_gnode_level = into_gnode_level;
            BootstrapPhaseTasklet ts = new BootstrapPhaseTasklet();
            ts.mgr = this;
            tasklet.spawn(ts);
        }

        private class BootstrapPhaseTasklet : Object, ITaskletSpawnable
        {
            public QspnManager mgr;
            public void * func()
            {
                mgr.bootstrap_phase();
                return null;
            }
        }
        private void bootstrap_phase()
        {
            int i = hooking_gnode_level;
            int j = into_gnode_level;
            queued_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc arc in my_arcs)
            {
                IQspnNaddr addr = arc.i_qspn_get_naddr();
                int lvl = my_naddr.i_qspn_get_coord_by_address(addr).lvl;
                if (lvl >= i && lvl < j) queued_arcs.add(arc);
            }
            while (! queued_arcs.is_empty && ! bootstrap_complete)
            {
                IQspnArc arc = queued_arcs.remove_at(0);
                EtpMessage? etp;
                bool bootstrap_in_progress;
                bool bad_answer;
                bool bad_link;
                retrieve_full_etp(arc, out etp, out bootstrap_in_progress, out bad_answer, out bad_link);
                if (bootstrap_in_progress) continue;
                if (bad_answer)
                {
                    arc_remove(arc);
                    arc_removed(arc, bad_link);
                    continue;
                }
                // Process etp. No forward is needed.
                int arc_id = get_arc_id(arc);
                assert(arc_id >= 0);
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
            hooking_gnode_level = levels;
            qspn_bootstrap_complete();
            // Process all arcs.
            queued_arcs.clear();
            foreach (IQspnArc arc in my_arcs)
            {
                EtpMessage? etp;
                bool bootstrap_in_progress;
                bool bad_answer;
                bool bad_link;
                retrieve_full_etp(arc, out etp, out bootstrap_in_progress, out bad_answer, out bad_link);
                if (bootstrap_in_progress) continue;
                if (bad_answer)
                {
                    arc_remove(arc);
                    arc_removed(arc, bad_link);
                    continue;
                }
                // Process etp. No forward is needed.
                int arc_id = get_arc_id(arc);
                assert(arc_id >= 0);
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
            publish_full_etp();
            tasklet.ms_wait(1000);
            presence_notified();
        }

        private void retrieve_full_etp(IQspnArc arc, out EtpMessage? etp,
         out bool bootstrap_in_progress,
         out bool bad_answer, out bool bad_link)
        {
            bootstrap_in_progress = false;
            bad_answer = false;
            bad_link = false;
            etp = null;
            IQspnManagerStub stub_get_etp =
                    stub_factory.i_qspn_get_tcp(arc);
            IQspnEtpMessage? resp = null;
            try {
                resp = stub_get_etp.get_full_etp(my_naddr);
            }
            catch (QspnBootstrapInProgressError e) {
                bootstrap_in_progress = true;
                return;
            }
            catch (StubError e) {
                bad_answer = true;
                bad_link = true;
                return;
            }
            catch (DeserializeError e) {
                bad_answer = true;
                return;
            }
            catch (QspnNotAcceptedError e) {
                bad_answer = true;
                return;
            }
            if (! (resp is EtpMessage))
            {
                bad_answer = true;
                return;
            }
            etp = (EtpMessage) resp;
            if (! check_incoming_message(etp))
            {
                bad_answer = true;
                return;
            }
            return;
        }

        // Helper: get id of arc
        private int get_arc_id(IQspnArc arc)
        {
            foreach (int id in id_arc_map.keys)
            {
                if (id_arc_map[id].i_qspn_equals(arc))
                {
                    return id;
                }
            }
            return -1;
        }
        // Helper: get arcs for a broadcast message to all.
        private Gee.List<IQspnArc> get_arcs_broadcast_all()
        {
            var ret = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            ret.add_all(my_arcs);
            return ret;
        }
        // Helper: get arcs for a broadcast message to all but one.
        private Gee.List<IQspnArc> get_arcs_broadcast_all_but_one(IQspnArc arc)
        {
            var ret = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc one in my_arcs) if (! arc.i_qspn_equals(one))
                ret.add(one);
            return ret;
        }

        private void stop_operations()
        {
            if (periodical_update_tasklet != null)
                periodical_update_tasklet.kill();
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
            public QspnManager mgr;
            public void * func()
            {
                mgr.periodical_update();
            }
        }

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
                    assert(mgr.check_outgoing_message(m));
                    stub.send_etp(m, is_full);
                }
                catch (QspnNotAcceptedError e) {
                    // we're not in its arcs; remove and emit signal
                    mgr.arc_remove(arc);
                    // emit signal
                    mgr.arc_removed(arc);
                }
                catch (StubError e) {
                    // remove failed arc and emit signal
                    mgr.arc_remove(arc);
                    // emit signal
                    mgr.arc_removed(arc, true);
                }
                catch (DeserializeError e) {
                    warning(@"MissingArcSendEtp: Got Deserialize error: $(e.message)");
                    // remove failed arc and emit signal
                    mgr.arc_remove(arc);
                    // emit signal
                    mgr.arc_removed(arc);
                }
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
            public QspnManager mgr;
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
                arc_id = Random.int_range(0, int.MAX);
            }
            // memorize
            my_arcs.add(arc);
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
            bool bad_link;
            retrieve_full_etp(arc, out etp, out bootstrap_in_progress, out bad_answer, out bad_link);
            if (bootstrap_in_progress) return; // Give up. The neighbor will start a flood when its bootstrap is complete.
            if (bad_answer)
            {
                arc_remove(arc);
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
                EtpMessage new_etp = prepare_fwd_etp(all_paths_set,
                                                     etp);
                IQspnManagerStub stub_send_to_others =
                        stub_factory.i_qspn_get_broadcast(
                        get_arcs_broadcast_all_but_one(arc),
                        // If a neighbor doesnt send its ACK repeat the message via tcp
                        new MissingArcSendEtp(this, new_etp, false));
                debug("Forward ETP to all but the new arc");
                try {
                    assert(check_outgoing_message(new_etp));
                    stub_send_to_others.send_etp(new_etp, false);
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
                    critical(@"QspnManager.arc_add: StubError in send to broadcast except arc $(arc_id): $(e.message)");
                }
            }

            // create a new etp for arc
            EtpMessage full_etp = prepare_full_etp();
            IQspnManagerStub stub_send_to_arc =
                    stub_factory.i_qspn_get_tcp(arc);
            debug("Sending ETP to new arc");
            try {
                assert(check_outgoing_message(full_etp));
                stub_send_to_arc.send_etp(full_etp, true);
            }
            catch (QspnNotAcceptedError e) {
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
            catch (StubError e) {
                arc_remove(arc);
                // emit signal
                arc_removed(arc, true);
                return;
            }
            catch (DeserializeError e) {
                warning(@"tasklet_arc_add calling send_etp: Got Deserialize error: $(e.message)");
                // remove failed arc and emit signal
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
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
            public QspnManager mgr;
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
            int changed_arc_id = get_arc_id(changed_arc);
            assert(changed_arc_id >= 0);
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
                gather_full_etp_set(my_arcs, (arc, bad_link) => {
                    // remove failed arcs and emit signal
                    arc_remove(arc);
                    // emit signal
                    arc_removed(arc, bad_link);
                });
            // Got ETPs. Revise the paths in each of them.
            Gee.List<NodePath> q = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
            foreach (PairArcEtp pair in results)
            {
                int arc_id = get_arc_id(pair.a);
                assert(arc_id >= 0);
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
                EtpMessage new_etp = prepare_new_etp(all_paths_set);
                IQspnManagerStub stub_send_to_all =
                        stub_factory.i_qspn_get_broadcast(
                        get_arcs_broadcast_all(),
                        // If a neighbor doesnt send its ACK repeat the message via tcp
                        new MissingArcSendEtp(this, new_etp, false));
                debug("Sending ETP to all");
                try {
                    assert(check_outgoing_message(new_etp));
                    stub_send_to_all.send_etp(new_etp, false);
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
                    critical(@"QspnManager.arc_is_changed: StubError in send to broadcast to all: $(e.message)");
                }
            }
        }

        public void arc_remove(IQspnArc removed_arc)
        {
            // Check data right away
            IQspnCost c = removed_arc.i_qspn_get_cost();
            assert(c != null);

            ArcRemoveTasklet ts = new ArcRemoveTasklet();
            ts.mgr = this;
            ts.removed_arc = removed_arc;
            tasklet.spawn(ts);
        }
        private class ArcRemoveTasklet : Object, ITaskletSpawnable
        {
            public QspnManager mgr;
            public IQspnArc removed_arc;
            public void * func()
            {
                mgr.tasklet_arc_remove(removed_arc);
                return null;
            }
        }
        private void tasklet_arc_remove(IQspnArc removed_arc)
        {
            // From outside the module is notified that this arc of mine
            // has been removed.
            // Or, either, the module itself wants to remove this arc (possibly
            // because it failed to send a message).
            if (!(removed_arc in my_arcs))
            {
                warning("QspnManager.arc_remove: not in my arcs.");
                return;
            }

            // during bootstrap remove the arc from queued_arcs and then return
            if (!bootstrap_complete)
            {
                if (removed_arc in queued_arcs) queued_arcs.remove(removed_arc);
                return;
            }

            // First, remove the arc...
            int arc_id = get_arc_id(removed_arc);
            assert(arc_id >= 0);
            my_arcs.remove(removed_arc);
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
                        EtpPath p = prepare_path_step_1(np);
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
            // Then do the same as when arc is changed and remember to add paths_to_add_to_all_paths
            // gather ETP from all of my arcs
            Collection<PairArcEtp> results =
                gather_full_etp_set(my_arcs, (arc, bad_link) => {
                    // remove failed arcs and emit signal
                    arc_remove(arc);
                    // emit signal
                    arc_removed(arc, bad_link);
                });
            // Got ETPs. Revise the paths in each of them.
            Gee.List<NodePath> q = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
            foreach (PairArcEtp pair in results)
            {
                int arc_m_id = get_arc_id(pair.a);
                assert(arc_m_id >= 0);
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
                EtpMessage new_etp = prepare_new_etp(all_paths_set);
                IQspnManagerStub stub_send_to_all =
                        stub_factory.i_qspn_get_broadcast(
                        get_arcs_broadcast_all(),
                        // If a neighbor doesnt send its ACK repeat the message via tcp
                        new MissingArcSendEtp(this, new_etp, false));
                debug("Sending ETP to all");
                try {
                    assert(check_outgoing_message(new_etp));
                    stub_send_to_all.send_etp(new_etp, false);
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
                    critical(@"QspnManager.arc_remove: StubError in send to broadcast to all: $(e.message)");
                }
            }
        }

        // Helper: get IQspnNodePath from NodePath
        private RetPath get_ret_path(NodePath np)
        {
            EtpPath p = np.path;
            IQspnArc arc = np.arc;
            RetPath r = new RetPath();
            r.arc = arc;
            r.hops = new ArrayList<IQspnHop>();
            for (int j = 0; j < p.arcs.size; j++)
            {
                HCoord h = p.hops[j];
                int arc_id = p.arcs[j];
                RetHop hop = new RetHop();
                hop.arc_id = arc_id;
                hop.hcoord = h;
                r.hops.add(hop);
            }
            r.cost = p.cost.i_qspn_add_segment(arc.i_qspn_get_cost());
            r.nodes_inside = p.nodes_inside;
            return r;
        }

        // Helper: path to send in a ETP
        private EtpPath prepare_path_step_1(NodePath np)
        {
            EtpPath p = new EtpPath();
            p.hops = new ArrayList<HCoord>((a, b) => a.equals(b));
            p.hops.add_all(np.path.hops);
            p.arcs = new ArrayList<int>();
            p.arcs.add_all(np.path.arcs);
            p.fingerprint = np.path.fingerprint;
            p.nodes_inside = np.path.nodes_inside;
            p.cost = np.cost;
            return p;
        }
        private void prepare_path_step_2(EtpPath p)
        {
            // Set values for ignore_outside.
            p.ignore_outside = new ArrayList<bool>();
            p.ignore_outside.add(false);
            for (int i = 1; i < levels; i++)
            {
                if (p.hops.last().lvl >= i)
                {
                    int j = 0;
                    while (true)
                    {
                        if (p.hops[j].lvl >= i) break;
                        j++;
                    }
                    int d_lvl = p.hops[j].lvl;
                    int d_pos = p.hops[j].pos;
                    assert(destinations.size > d_lvl);
                    if (! destinations[d_lvl].has_key(d_pos))
                    {
                        if (p.cost.i_qspn_is_dead())
                        {
                            p.ignore_outside.add(false);
                            continue;
                        }
                        else assert_not_reached();
                    }
                    Destination d = destinations[d_lvl][d_pos];
                    NodePath? best_to_arc = null;
                    foreach (NodePath q in d.paths)
                    {
                        if (q.path.arcs.last() == p.arcs[j])
                        {
                            if (best_to_arc == null)
                            {
                                best_to_arc = q;
                            }
                            else
                            {
                                if (q.cost.i_qspn_compare_to(best_to_arc.cost) < 0)
                                {
                                    best_to_arc = q;
                                }
                            }
                        }
                    }
                    if (best_to_arc == null)
                    {
                        p.ignore_outside.add(false);
                    }
                    else
                    {
                        bool same = false;
                        if (best_to_arc.path.hops.size == j+1)
                        {
                            same = true;
                            for (int k = 0; k < j; k++)
                            {
                                if (!(best_to_arc.path.hops[k].equals(p.hops[k])) || 
                                    best_to_arc.path.arcs[k] != p.arcs[k])
                                {
                                    same = false;
                                    break;
                                }
                            }
                        }
                        p.ignore_outside.add(!same);
                    }
                }
                else
                {
                    p.ignore_outside.add(true);
                }
            }
        }

        // Helper: revise an ETP, correct its id_list and the paths inside it.
        //  The ETP has been already checked with check_incoming_message.
        private Gee.List<NodePath> revise_etp(EtpMessage m, IQspnArc arc, int arc_id, bool is_full) throws AcyclicError
        {
            ArrayList<NodePath> ret = new ArrayList<NodePath>((a, b) => a.hops_arcs_equal(b));
            HCoord v = my_naddr.i_qspn_get_coord_by_address(m.node_address);
            int i = v.lvl + 1;
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
            v_path.ignore_outside = new ArrayList<bool>();
            for (j = 0; j < levels; j++) v_path.ignore_outside.add(false);
            m.p_list.add(v_path);
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

        // Helper: prepare new ETP
        private EtpMessage prepare_new_etp
        (Collection<EtpPath> all_paths_set,
         Gee.List<HCoord>? etp_hops=null)
        {
            EtpMessage ret = new EtpMessage();
            ret.p_list = new ArrayList<EtpPath>();
            foreach (EtpPath p in all_paths_set)
            {
                ret.p_list.add(p);
            }
            ret.node_address = my_naddr;
            ret.fingerprints = new ArrayList<IQspnFingerprint>();
            ret.fingerprints.add_all(my_fingerprints);
            ret.nodes_inside = new ArrayList<int>();
            ret.nodes_inside.add_all(my_nodes_inside);
            ret.hops = new ArrayList<HCoord>((a, b) => a.equals(b));
            if (etp_hops != null) ret.hops.add_all(etp_hops);
            return ret;
        }

        // Helper: prepare full ETP
        private EtpMessage prepare_full_etp()
        {
            var etp_paths = new ArrayList<EtpPath>();
            for (int l = 0; l < levels; l++)
            {
                foreach (Destination d in destinations[l].values)
                {
                    foreach (NodePath np in d.paths)
                    {
                        EtpPath p = prepare_path_step_1(np);
                        prepare_path_step_2(p);
                        etp_paths.add(p);
                    }
                }
            }
            return prepare_new_etp(etp_paths);
        }

        // Helper: prepare forward ETP
        private EtpMessage prepare_fwd_etp
        (Collection<EtpPath> all_paths_set,
         EtpMessage m)
        {
            // The message 'm' has been revised, so that m.hops has the 'exit_gnode'
            //  at the beginning.
            return prepare_new_etp(all_paths_set,
                                   m.hops);
        }

        // Helper: gather ETP from a set of arcs
        private class PairArcEtp : Object {
            public PairArcEtp(EtpMessage m, IQspnArc a)
            {
                this.m = m;
                this.a = a;
            }
            public EtpMessage m;
            public IQspnArc a;
        }
        private class GatherEtpSetData : Object
        {
            public ArrayList<ITaskletHandle> tasks;
            public ArrayList<IQspnArc> arcs;
            public ArrayList<IQspnManagerStub> stubs;
            public ArrayList<PairArcEtp> results;
            public IQspnNaddr my_naddr;
            public unowned FailedArcHandler failed_arc_handler;
        }
        private delegate void FailedArcHandler(IQspnArc failed_arc, bool bad_link);
        private Collection<PairArcEtp>
        gather_full_etp_set(Collection<IQspnArc> arcs, FailedArcHandler failed_arc_handler)
        {
            // Work in parallel then join
            // Prepare (one instance for this run) an object work for the tasklets
            GatherEtpSetData work = new GatherEtpSetData();
            work.tasks = new ArrayList<ITaskletHandle>();
            work.arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            work.stubs = new ArrayList<IQspnManagerStub>();
            work.results = new ArrayList<PairArcEtp>();
            work.my_naddr = my_naddr;
            work.failed_arc_handler = failed_arc_handler;
            int i = 0;
            foreach (IQspnArc arc in arcs)
            {
                var stub = stub_factory.i_qspn_get_tcp(arc);
                work.arcs.add(arc);
                work.stubs.add(stub);
                GetFullEtpTasklet ts = new GetFullEtpTasklet();
                ts.mgr = this;
                ts.work = work;
                ts.i = i++;
                ITaskletHandle t = tasklet.spawn(ts, /*joinable*/ true);
                work.tasks.add(t);
            }
            // join
            foreach (ITaskletHandle t in work.tasks) t.join();
            return work.results;
        }
        private class GetFullEtpTasklet : Object, ITaskletSpawnable
        {
            public QspnManager mgr;
            public GatherEtpSetData work;
            public int i;
            public void * func()
            {
                mgr.tasklet_get_full_etp(work, i);
                return null;
            }
        }
        private void tasklet_get_full_etp(GatherEtpSetData work, int i)
        {
            IQspnManagerStub stub = work.stubs[i];
            IQspnEtpMessage? resp = null;
            try {
                int arc_id = get_arc_id(work.arcs[i]);
                debug(@"Requesting ETP from arc $(arc_id)");
                resp = stub.get_full_etp(work.my_naddr);
            }
            catch (QspnBootstrapInProgressError e) {
                debug("Got QspnBootstrapInProgressError. Give up.");
                // Give up this tasklet. The neighbor will start a flood when its bootstrap is complete.
                return;
            }
            catch (StubError e) {
                debug("Got StubError. Remove arc.");
                // failed arc
                work.failed_arc_handler(work.arcs[i], true);
                return;
            }
            catch (QspnNotAcceptedError e) {
                debug("Got NotAcceptedError. Remove arc.");
                // failed arc
                work.failed_arc_handler(work.arcs[i], false);
                return;
            }
            catch (DeserializeError e) {
                debug("Got DeserializeError. Remove arc.");
                // failed arc
                work.failed_arc_handler(work.arcs[i], false);
                return;
            }
            if (! (resp is EtpMessage))
            {
                debug("Got wrong class. Remove arc.");
                // The module only knows this class that implements IQspnEtpMessage, so this
                //  should not happen. But the rest of the code, who knows? So to be sure
                //  we check. If it is the case, remove the arc.
                work.failed_arc_handler(work.arcs[i], false);
                return;
            }
            EtpMessage m = (EtpMessage) resp;
            if (!check_incoming_message(m))
            {
                debug("Got bad parameters. Remove arc.");
                // We check the correctness of a message from another node.
                // If the message is junk, remove the arc.
                work.failed_arc_handler(work.arcs[i], false);
                return;
            }

            debug("Got one.");
            PairArcEtp res = new PairArcEtp(m, work.arcs[i]);
            work.results.add(res);
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
                publish_full_etp();
            }
        }

        // Helper: check that an incoming ETP is valid:
        // The address MUST have the same topology parameters as mine.
        // The address MUST NOT be the same as mine.
        private bool check_incoming_message(EtpMessage m)
        {
            if (m.node_address.i_qspn_get_levels() != levels) return false;
            bool not_same = false;
            for (int l = 0; l < levels; l++)
            {
                if (m.node_address.i_qspn_get_gsize(l) != gsizes[l]) return false;
                if (m.node_address.i_qspn_get_pos(l) != my_naddr.i_qspn_get_pos(l)) not_same = true;
            }
            if (! not_same) return false;
            return check_any_message(m);
        }
        // Helper: check that an outgoing ETP is valid:
        // The address MUST be mine.
        private bool check_outgoing_message(EtpMessage m)
        {
            if (m.node_address.i_qspn_get_levels() != levels) return false;
            bool not_same = false;
            for (int l = 0; l < levels; l++)
            {
                if (m.node_address.i_qspn_get_gsize(l) != gsizes[l]) return false;
                if (m.node_address.i_qspn_get_pos(l) != my_naddr.i_qspn_get_pos(l)) not_same = true;
            }
            if (not_same) return false;
            return check_any_message(m);
        }
        // Helper: check that an ETP (both incoming or outgoing) is valid:
        // For each path p in P:
        //  . For i = p.hops.last().lvl+1 TO levels-1:
        //    . p.ignore_outside[i] must be true
        //  . p.fingerprint must be valid for p.hops.last().lvl
        //  . p.arcs.size MUST be the same of p.hops.size.
        //  . For each HCoord g in p.hops:
        //    . g.lvl has to be between 0 and levels-1
        //    . g.lvl has to grow only
        //    . g.pos has to be between 0 and gsize(g.lvl)-1
        // With the main hops list of the ETP:
        //  . For each HCoord g in hops:
        //    . g.lvl has to be between 0 and levels-1
        //    . g.lvl has to grow only
        //    . g.pos has to be between 0 and gsize(g.lvl)-1
        private bool check_any_message(EtpMessage m)
        {
            if (! check_tplist(m.hops)) return false;
            foreach (EtpPath p in m.p_list)
            {
                for (int i = p.hops.last().lvl+1; i < levels; i++)
                    if (! p.ignore_outside[i]) return false;
                if (p.fingerprint.i_qspn_get_level() != p.hops.last().lvl) return false;
                if (p.hops.size != p.arcs.size) return false;
                if (! check_tplist(p.hops)) return false;
            }
            return true;
        }
        private bool check_tplist(Gee.List<HCoord> hops)
        {
            int curlvl = 0;
            foreach (HCoord c in hops)
            {
                if (c.lvl < curlvl) return false;
                if (c.lvl >= levels) return false;
                curlvl = c.lvl;
                if (c.pos < 0) return false;
                if (c.pos >= gsizes[c.lvl]) return false;
            }
            return true;
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
                foreach (IQspnArc a in my_arcs)
                {
                    HCoord v = my_naddr.i_qspn_get_coord_by_address(a.i_qspn_get_naddr());
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
                        all_paths_set.add(prepare_path_step_1(p));
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
                        EtpPath pp = prepare_path_step_1(p);
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
                            all_paths_set.add(prepare_path_step_1(p));
                            if (d.lvl == 0)
                            {
                                sd.add(new SignalToEmit.path_changed(get_ret_path(p)));
                            }
                            else
                            {
                                if (p.exposed)
                                {
                                    if (fp_d_p.i_qspn_equals(valid_fp_d))
                                    {
                                        sd.add(new SignalToEmit.path_changed(get_ret_path(p)));
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
                                        sd.add(new SignalToEmit.path_added(get_ret_path(p)));
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
            foreach (EtpPath p in all_paths_set) prepare_path_step_2(p);
        }
        private class SignalSplitTasklet : Object, ITaskletSpawnable
        {
            public QspnManager mgr;
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
                    foreach (IQspnArc a in my_arcs)
                    {
                        HCoord v = my_naddr.i_qspn_get_coord_by_address(a.i_qspn_get_naddr());
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
            public QspnManager mgr;
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
                        EtpPath p = prepare_path_step_1(np);
                        prepare_path_step_2(p);
                        etp_paths.add(p);
                    }
                }
            }
            if (etp_paths.is_empty) return;
            EtpMessage new_etp = prepare_new_etp(etp_paths);
            IQspnManagerStub stub_send_to_all =
                    stub_factory.i_qspn_get_broadcast(
                    get_arcs_broadcast_all(),
                    // If a neighbor doesnt send its ACK repeat the message via tcp
                    new MissingArcSendEtp(this, new_etp, false));
            debug("Sending ETP to all");
            try {
                assert(check_outgoing_message(new_etp));
                stub_send_to_all.send_etp(new_etp, false);
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
                critical(@"QspnManager.flood_first_detection_split: StubError in send to broadcast to all: $(e.message)");
            }
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
                IQspnFingerprint new_fp = my_fingerprints[0].i_qspn_construct(fp_set);
                if (! new_fp.i_qspn_equals(my_fingerprints[1]))
                {
                    my_fingerprints[1] = new_fp;
                    changes_in_my_gnodes = true;
                    changed_fp(1);
                }
                int new_nn = 1 + nn_tot;
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
                IQspnFingerprint new_fp = my_fingerprints[i-1].i_qspn_construct(fp_set);
                if (! new_fp.i_qspn_equals(my_fingerprints[i]))
                {
                    my_fingerprints[i] = new_fp;
                    changes_in_my_gnodes = true;
                    changed_fp(i);
                }
                int new_nn = my_nodes_inside[i-1] + nn_tot;
                if (new_nn != my_nodes_inside[i])
                {
                    my_nodes_inside[i] = new_nn;
                    changes_in_my_gnodes = true;
                    changed_nodes_inside(i);
                }
            }
        }

        // Helper: publish full ETP to all
        private void publish_full_etp()
        {
            // Prepare full ETP and send to all my neighbors.
            EtpMessage full_etp = prepare_full_etp();
            IQspnManagerStub stub_send_to_all =
                    stub_factory.i_qspn_get_broadcast(
                    get_arcs_broadcast_all(),
                    // If a neighbor doesnt send its ACK repeat the message via tcp
                    new MissingArcSendEtp(this, full_etp, true));
            debug("Sending ETP to all");
            try {
                assert(check_outgoing_message(full_etp));
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
        public Gee.List<HCoord> get_known_destinations() throws QspnBootstrapInProgressError
        {
            if (!bootstrap_complete) throw new QspnBootstrapInProgressError.GENERIC("I am still in bootstrap.");
            var ret = new ArrayList<HCoord>((a, b) => a.equals(b));
            for (int l = 0; l < levels; l++)
                foreach (Destination d in destinations[l].values)
                    ret.add(d.dest);
            return ret;
        }

        /** Provides a collection of known paths to a destination
          */
        public Gee.List<IQspnNodePath> get_paths_to(HCoord d) throws QspnBootstrapInProgressError
        {
            if (!bootstrap_complete) throw new QspnBootstrapInProgressError.GENERIC("I am still in bootstrap.");
            var ret = new ArrayList<IQspnNodePath>();
            if (d.lvl < levels && destinations[d.lvl].has_key(d.pos))
            {
                // find current valid fingerprint of d
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
                // prepare known valid paths
                foreach (NodePath p in destinations[d.lvl][d.pos].paths)
                {
                    IQspnFingerprint fp_d_p = p.path.fingerprint;
                    if (d.lvl == 0)
                    {
                        ret.add(get_ret_path(p));
                    }
                    else
                    {
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
            if (!bootstrap_complete) throw new QspnBootstrapInProgressError.GENERIC("I am still in bootstrap.");
            return my_nodes_inside[level];
        }

        /** Gives the fingerprint of my g-node
          */
        public IQspnFingerprint get_fingerprint(int level) throws QspnBootstrapInProgressError
        {
            if (!bootstrap_complete) throw new QspnBootstrapInProgressError.GENERIC("I am still in bootstrap.");
            return my_fingerprints[level];
        }

        /** Informs whether the node has completed bootstrap
          */
        public bool is_bootstrap_complete()
        {
            return hooking_gnode_level == levels;
        }

        /** Gives the list of current arcs
          */
        public Gee.List<IQspnArc> current_arcs()
        {
            var ret = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            ret.add_all(my_arcs);
            return ret;
        }

        /** Make this identity a ''connectivity'' one.
          */
        public void make_connectivity(int connectivity_from_level,
                                      int connectivity_to_level,
                                      IQspnMyNaddr new_naddr,
                                      IQspnFingerprint new_fp)
        {
            assert(connectivity_from_level <= connectivity_to_level);
            assert(connectivity_to_level <= levels);
            assert(connectivity_from_level > 0);
            int old_id = my_naddr.i_qspn_get_pos(connectivity_from_level-1);
            assert(old_id < gsizes[connectivity_from_level-1]);
            this.connectivity_from_level = connectivity_from_level;
            this.connectivity_to_level = connectivity_to_level;
            my_naddr = new_naddr;
            int new_id = my_naddr.i_qspn_get_pos(connectivity_from_level-1);
            assert(new_id >= gsizes[connectivity_from_level-1]);
            // Fingerprint at level 0.
            my_fingerprints.remove_at(0);
            my_fingerprints.insert(0, new_fp);
            // Nodes_inside at level 0. This is a ''connectivity'' address, we say we have 0 ''real'' nodes.
            my_nodes_inside.remove_at(0);
            my_nodes_inside.insert(0, 0);
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
            public QspnManager mgr;
            public int delay;
            public int old_pos;
            public int old_lvl;
            public void * func()
            {
                tasklet.ms_wait(delay);
                mgr.publish_connectivity(old_pos, old_lvl);
                return null;
            }
        }
        private void publish_connectivity(int old_pos, int old_lvl)
        {
            // Send a full ETP to all neighbors outside 'old_lvl'.
            // We should just say that we have no more to old_pos, but it's
            //  not possible to identify this path in a EtpMessage, since it
            //  would have no hops.
            EtpMessage etp = prepare_full_etp();
            int i = old_lvl;
            ArrayList<IQspnArc> outer_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc arc in my_arcs)
            {
                int lvl = my_naddr.i_qspn_get_coord_by_address(arc.i_qspn_get_naddr()).lvl;
                if (lvl >= i) outer_arcs.add(arc);
            }
            IQspnManagerStub stub_send_to_outer =
                    stub_factory.i_qspn_get_broadcast(
                    outer_arcs,
                    // If a neighbor doesnt send its ACK repeat the message via tcp
                    new MissingArcSendEtp(this, etp, true));
            try {
                assert(check_outgoing_message(etp));
                stub_send_to_outer.send_etp(etp, true);
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

        /** This identity now has a ''real'' position at level 'into_gnode_level' - 1.
          */
        public void make_real(IQspnMyNaddr new_naddr)
        {
            my_naddr = new_naddr;
            if (bootstrap_complete)
            {
                // Send a void ETP to all neighbors outside 'hooking_gnode_level'.
                EtpMessage etp = prepare_new_etp(new ArrayList<EtpPath>());
                int i = hooking_gnode_level;
                ArrayList<IQspnArc> outer_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
                foreach (IQspnArc arc in my_arcs)
                {
                    int lvl = my_naddr.i_qspn_get_coord_by_address(arc.i_qspn_get_naddr()).lvl;
                    if (lvl >= i) outer_arcs.add(arc);
                }
                IQspnManagerStub stub_send_to_outer =
                        stub_factory.i_qspn_get_broadcast(
                        outer_arcs,
                        // If a neighbor doesnt send its ACK repeat the message via tcp
                        new MissingArcSendEtp(this, etp, false));
                try {
                    assert(check_outgoing_message(etp));
                    stub_send_to_outer.send_etp(etp, false);
                } catch (QspnNotAcceptedError e) {
                    // a broadcast will never get a return value nor an error
                    assert_not_reached();
                } catch (DeserializeError e) {
                    // a broadcast will never get a return value nor an error
                    assert_not_reached();
                } catch (StubError e) {
                    critical(@"QspnManager.make_real: StubError in broadcast sending: $(e.message)");
                }
            }
        }

        /** Remove outer arcs from this connectivity identity.
          */
        public void remove_outer_arcs()
        {
            assert(connectivity_to_level > 0);
            ArrayList<IQspnArc> arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            arcs.add_all(my_arcs);
            foreach (IQspnArc arc in arcs)
            {
                // Check the neighbor address.
                IQspnNaddr addr = arc.i_qspn_get_naddr();
                int lvl = my_naddr.i_qspn_get_coord_by_address(addr).lvl;
                if (lvl >= connectivity_to_level)
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
            assert(connectivity_from_level > 0);
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
            assert(connectivity_from_level > 0);
            int i = connectivity_from_level - 1;
            ArrayList<IQspnArc> internal_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc arc in my_arcs)
            {
                int lvl = my_naddr.i_qspn_get_coord_by_address(arc.i_qspn_get_naddr()).lvl;
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
                        mgr.stub_factory.i_qspn_get_tcp(arc);
                try {
                    stub.got_prepare_destroy();
                }
                catch (StubError e) {
                    // remove failed arc and emit signal
                    mgr.arc_remove(arc);
                    // emit signal
                    mgr.arc_removed(arc, true);
                }
                catch (DeserializeError e) {
                    warning(@"MissingArcPrepareDestroy: Got Deserialize error: $(e.message)");
                    // remove failed arc and emit signal
                    mgr.arc_remove(arc);
                    // emit signal
                    mgr.arc_removed(arc);
                }
            }
        }

        /** Signal the imminent removal of this identity (connectivity or not).
          */
        public void destroy()
        {
            // Could be also connectivity_from_level == 0.
            int i = connectivity_from_level - 1;
            ArrayList<IQspnArc> outer_arcs = new ArrayList<IQspnArc>((a, b) => a.i_qspn_equals(b));
            foreach (IQspnArc arc in my_arcs)
            {
                int lvl = my_naddr.i_qspn_get_coord_by_address(arc.i_qspn_get_naddr()).lvl;
                if (lvl >= i) outer_arcs.add(arc);
            }
            IQspnManagerStub stub_send_to_outer =
                    stub_factory.i_qspn_get_broadcast(
                    outer_arcs,
                    // If a neighbor doesnt send its ACK repeat the message via tcp
                    new MissingArcDestroy(this));
            try {
                stub_send_to_outer.got_destroy();
            } catch (DeserializeError e) {
                // a broadcast will never get a return value nor an error
                assert_not_reached();
            } catch (StubError e) {
                critical(@"QspnManager.destroy: StubError in broadcast sending to outer_arcs: $(e.message)");
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
                        mgr.stub_factory.i_qspn_get_tcp(arc);
                try {
                    stub.got_destroy();
                }
                catch (StubError e) {
                    // remove failed arc and emit signal
                    mgr.arc_remove(arc);
                    // emit signal
                    mgr.arc_removed(arc, true);
                }
                catch (DeserializeError e) {
                    warning(@"MissingArcDestroy: Got Deserialize error: $(e.message)");
                    // remove failed arc and emit signal
                    mgr.arc_remove(arc);
                    // emit signal
                    mgr.arc_removed(arc);
                }
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
                tasklet.ms_wait(arc_timeout / 10);
            }
            if (arc == null) throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");

            if (! (requesting_address is IQspnNaddr))
            {
                // The module only knows this class that implements IQspnAddress, so this
                //  should not happen. But the rest of the code, who knows? So to be sure
                //  we check. If it is the case remove the arc.
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                tasklet.exit_tasklet(null);
            }
            IQspnNaddr requesting_naddr = (IQspnNaddr) requesting_address;

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
                        EtpPath p = prepare_path_step_1(np);
                        prepare_path_step_2(p);
                        etp_paths.add(p);
                    }
                }
            }
            debug("Sending ETP on request");
            var ret = prepare_new_etp(etp_paths);
            assert(check_outgoing_message(ret));
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
                tasklet.ms_wait(arc_timeout / 10);
            }
            if (arc == null) throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");

            if (! (arc in my_arcs)) return;
            debug("An incoming ETP is received");
            if (! (m is EtpMessage))
            {
                // The module only knows this class that implements IQspnEtpMessage, so this
                //  should not happen. But the rest of the code, who knows? So to be sure
                //  we check. If it is the case, remove the arc.
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
            EtpMessage etp = (EtpMessage) m;
            if (! check_incoming_message(etp))
            {
                debug("Got bad parameters. Remove incoming arc.");
                // We check the correctness of a message from another node.
                // If the message is junk, remove the arc.
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }

            bool must_exit_bootstrap_phase = false;
            // If it is during bootstrap:
            if (!bootstrap_complete)
            {
                // Check the sender.
                IQspnNaddr addr = arc.i_qspn_get_naddr();
                int lvl = my_naddr.i_qspn_get_coord_by_address(addr).lvl;
                if (lvl >= hooking_gnode_level)
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
                        if (this_lvl == into_gnode_level - 1)
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
            int arc_id = get_arc_id(arc);
            assert(arc_id >= 0);
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
                EtpMessage new_etp = prepare_fwd_etp(all_paths_set,
                                                     etp);
                IQspnManagerStub stub_send_to_others =
                        stub_factory.i_qspn_get_broadcast(
                        get_arcs_broadcast_all_but_one(arc),
                        // If a neighbor doesnt send its ACK repeat the message via tcp
                        new MissingArcSendEtp(this, new_etp, false));
                debug("Forward ETP to all but the sender");
                try {
                    assert(check_outgoing_message(new_etp));
                    stub_send_to_others.send_etp(new_etp, false);
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
                    critical(@"QspnManager.send_etp: StubError in send to broadcast except arc $(arc_id): $(e.message)");
                }
            }
        }

        public void got_prepare_destroy(CallerInfo? _rpc_caller=null)
        {
            // Verify that I am a ''connectivity'' identity.
            if (connectivity_from_level == 0) tasklet.exit_tasklet(null);
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
                tasklet.ms_wait(arc_timeout / 10);
            }
            if (arc == null) tasklet.exit_tasklet(null);

            // remove the arc
            arc_remove(arc);
            arc_removed(arc);
        }

        ~QspnManager()
        {
            print("~QspnManager()\n");
            stop_operations();
        }
    }
}
