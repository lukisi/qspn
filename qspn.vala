using Gee;
using Tasklets;

namespace Netsukuku
{
    internal class Path : Object
    {
        public IQspnArc first_hop;
        public ArrayList<IQspnPartialNaddr> following_hops;
        public IQspnREM cost;
        public IQspnFingerprint fp;
        public int nodes_inside;
    }

    internal class RetPath : Object, IQspnPath
    {
        public IQspnPartialNaddr destination;
        public IQspnArc first_hop;
        public ArrayList<IQspnPartialNaddr> following_hops;
        public IQspnREM cost;
        public int nodes_inside;

        /* Interface */
        public IQspnPartialNaddr get_destination() {return destination;}
        public IQspnArc get_first_hop() {return first_hop;}
        public Gee.List<IQspnPartialNaddr> get_following_hops() {return following_hops;}
        public IQspnREM get_cost() {return cost;}
        public int get_nodes_inside() {return nodes_inside;}
    }

    internal class Destination : Object
    {
        public HCoord dest;
        public ArrayList<Path> paths;
    }

    public class QspnManager : Object
    {
        private IQspnNodeData my_node_id;
        private int max_paths;
        private double max_disjoint_ratio;
        private ArrayList<IQspnArc> my_arcs;
        private ArrayList<IQspnFingerprint> my_fingerprints;
        private IArcToStub arc_to_stub;
        private IQspnFingerprintManager fingerprint_manager;
        private int levels;
        // This collection can be indexed by level and then by iteration on the
        //  values. This is useful when we want to iterate on a certain level.
        //  In addition we can specify a level and then refer by index to the
        //  position. This is useful when we want to remove one item.
        private ArrayList<HashMap<int, Destination>> destinations;

        public QspnManager(IQspnNodeData my_node_id,
                           int max_paths,
                           double max_disjoint_ratio,
                           Gee.List<IQspnArc> my_arcs,
                           Gee.List<IQspnFingerprint> my_fingerprints,
                           IArcToStub arc_to_stub,
                           IQspnFingerprintManager fingerprint_manager
                           )
        {
            this.my_node_id = my_node_id;
            this.max_paths = max_paths;
            this.max_disjoint_ratio = max_disjoint_ratio;
            this.arc_to_stub = arc_to_stub;
            this.fingerprint_manager = fingerprint_manager;
            this.my_arcs = new ArrayList<IQspnArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.equals(b);
                }
            );
            foreach (IQspnArc arc in my_arcs) this.my_arcs.add(arc);
            this.my_fingerprints = new ArrayList<IQspnFingerprint>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.equals(b);
                }
            );
            foreach (IQspnFingerprint fingerprint in my_fingerprints)
                this.my_fingerprints.add(fingerprint);
            // find levels of the network
            levels = this.my_node_id.get_naddr().get_levels();
            // prepare empty map
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int i = 0; i < levels; i++) destinations.add(
                new HashMap<int, Destination>());
            // 
        }

        // The gnode (or node) is now known on the network and the first path towards
        //  it is now available to this node.
        public signal void destination_added(IQspnPartialNaddr d);
        // The gnode (or node) has been removed from the network and the last path
        //  towards it has been deleted from this node.
        public signal void destination_removed(IQspnPartialNaddr d);
        // A new path (might be the first) to a destination has been found.
        public signal void path_added(IQspnPath p);
        // A path to a destination has changed.
        public signal void path_changed(IQspnPath p);
        // A path (might be the last) to a destination has been deleted.
        public signal void path_removed(IQspnPath p);
        // A gnode has splitted and the part reachable by this path MUST migrate.
        public signal void gnode_splitted(IQspnPath p);

        /** Provides a collection of known paths to a destination
         */
        public Gee.List<IQspnPath> get_paths_to(HCoord d)
        {
            var ret = new ArrayList<IQspnPath>();
            if (d.lvl < levels && destinations[d.lvl].has_key(d.pos))
            {
                foreach (Path p in destinations[d.lvl][d.pos].paths)
                {
                    RetPath r = new RetPath();
                    r.destination = my_node_id.get_naddr_as_mine().get_address_by_coord(d);
                    r.first_hop = p.first_hop;
                    r.following_hops = new ArrayList<IQspnPartialNaddr>();
                    r.following_hops.add_all(p.following_hops);
                    r.cost = p.cost;
                    r.nodes_inside = p.nodes_inside;
                    ret.add(r);
                }
            }
            return ret;
        }
    }

}
