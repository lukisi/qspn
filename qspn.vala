using Gee;
using zcd;
using Tasklets;

namespace Netsukuku
{
    // in ntkd-rpc  IQspnPath

    internal class NodePath : Object
    {
        public IQspnArc first_hop;
        public IQspnPath path;
    }

    internal class RetPath : Object, IQspnNodePath
    {
        public IQspnPartialNaddr destination;
        public IQspnArc first_hop;
        public ArrayList<IQspnPartialNaddr> following_hops;
        public IQspnREM cost;
        public int nodes_inside;

        /* Interface */
        public IQspnPartialNaddr i_qspn_get_destination() {return destination;}
        public IQspnArc i_qspn_get_first_hop() {return first_hop;}
        public Gee.List<IQspnPartialNaddr> i_qspn_get_following_hops() {return following_hops;}
        public IQspnREM i_qspn_get_cost() {return cost;}
        public int i_qspn_get_nodes_inside() {return nodes_inside;}
    }

    internal class Destination : Object
    {
        public HCoord dest;
        public ArrayList<NodePath> paths;
    }

    class TaskletWork : Object
    {
        public ArrayList<Tasklet> tasks;
        public ArrayList<IQspnArc> arcs;
        public ArrayList<IAddressManagerRootDispatcher> disps;
        public IQspnNaddr my_naddr;
        public ArrayList<IQspnEtp> results;
        public ArrayList<IQspnArc> toremove;
        public TaskletWork(IQspnNaddr my_naddr)
        {
            tasks = new ArrayList<Tasklet>();
            arcs = new ArrayList<IQspnArc>();
            disps = new ArrayList<IAddressManagerRootDispatcher>();
            results = new ArrayList<IQspnEtp>();
            toremove = new ArrayList<IQspnArc>();
            this.my_naddr = my_naddr;
        }
    }

    public interface IQspnEtpFactory : Object
    {
        public abstract IQspnPath i_qspn_create_path
                                    (Gee.List<HCoord> hops,
                                    IQspnFingerprint fp,
                                    int nodes_inside,
                                    IQspnREM cost);
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

        private IQspnNodeData my_node_id;
        private int max_paths;
        private double max_disjoint_ratio;
        private ArrayList<IQspnArc> my_arcs;
        private ArrayList<IQspnFingerprint> my_fingerprints;
        private INeighborhoodArcToStub arc_to_stub;
        private IQspnFingerprintManager fingerprint_manager;
        private IQspnEtpFactory etp_factory;
        private int levels;
        private IQspnMyNaddr my_naddr;
        private bool mature;
        // This collection can be indexed by level and then by iteration on the
        //  values. This is useful when we want to iterate on a certain level.
        //  In addition we can specify a level and then refer by index to the
        //  position. This is useful when we want to remove one item.
        private ArrayList<HashMap<int, Destination>> destinations;

        public QspnManager(IQspnNodeData my_node_id,
                           int max_paths,
                           double max_disjoint_ratio,
                           Gee.List<IQspnArc> my_arcs,
                           IQspnFingerprint my_fingerprint,
                           INeighborhoodArcToStub arc_to_stub,
                           IQspnFingerprintManager fingerprint_manager,
                           IQspnEtpFactory etp_factory
                           )
        {
            this.my_node_id = my_node_id;
            this.max_paths = max_paths;
            this.max_disjoint_ratio = max_disjoint_ratio;
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
            // Only the level 0 fingerprint is given. The other ones
            // will be constructed when the node is mature.
            this.my_fingerprints = new ArrayList<IQspnFingerprint>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.i_qspn_equals(b);
                }
            );
            my_fingerprints.add(my_fingerprint); // level 0 fingerprint
            // find levels of the network
            my_naddr = this.my_node_id.i_qspn_get_naddr_as_mine();
            levels = my_naddr.i_qspn_get_levels();
            // prepare empty map
            destinations = new ArrayList<HashMap<int, Destination>>();
            for (int i = 0; i < levels; i++) destinations.add(
                new HashMap<int, Destination>());
            // mature if alone
            if (this.my_arcs.is_empty)
            {
                mature = true;
                qspn_mature();
            }
            else
            {
                mature = false;
                // start in a tasklet the request of an ETP from all neighbors.
                Tasklet.tasklet_callback(
                    (t) => {
                        (t as QspnManager).get_first_etps();
                    },
                    this
                );
            }
        }

        // The module is notified if an arc is added/changed/removed
        public void arc_add(IQspnArc arc)
        {
            // TODO
        }

        public void arc_remove(IQspnArc arc)
        {
            // TODO
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
        public signal void path_added(IQspnPath p);
        // A path to a destination has changed.
        public signal void path_changed(IQspnPath p);
        // A path (might be the last) to a destination has been deleted.
        public signal void path_removed(IQspnPath p);
        // A gnode has splitted and the part reachable by this path MUST migrate.
        public signal void gnode_splitted(IQspnPath p);

        private void get_first_etps()
        {
            // Work in parallel then join
            // Prepare work for n tasklets
            TaskletWork work = new TaskletWork(my_naddr);
            int i = 0;
            foreach (IQspnArc arc in my_arcs)
            {
                var disp =
                    arc_to_stub.i_neighborhood_get_tcp((arc as INeighborhoodArc));
                work.arcs.add(arc);
                work.disps.add(disp);
                Tasklet t = Tasklet.tasklet_callback(
                    (t_work, t_i) => {
                        TaskletWork _work = t_work as TaskletWork;
                        int _i = (t_i as SerializableInt).i;
                        try
                        {
                            IAddressManagerRootDispatcher _disp = _work.disps[_i];
                            IQspnEtp etp = disp.qspn_manager.get_full_etp(_work.my_naddr);
                            _work.results.add(etp);
                        }
                        catch (RPCError e)
                        {
                            _work.toremove.add(_work.arcs[_i]);
                        }
                    },
                    work,
                    new SerializableInt(i++)
                );
                work.tasks.add(t);
            }
            // join
            foreach (Tasklet t in work.tasks) t.join();
            // remove failed arcs and emit signal
            foreach (IQspnArc arc in work.toremove)
            {
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
            }
            // on everything fail signal fatal error
            if (work.results.is_empty)
            {
                failed_hook();
            }
            else
            {
                foreach (IQspnEtp etp in work.results)
                {
                    // TODO update my map
                    
                }
                mature = true;
                qspn_mature();
            }
        }

        /** Provides a collection of known paths to a destination
         */
        public Gee.List<IQspnPath> get_paths_to(HCoord d)
        {
            var ret = new ArrayList<IQspnNodePath>();
            if (d.lvl < levels && destinations[d.lvl].has_key(d.pos))
            {
                foreach (NodePath p in destinations[d.lvl][d.pos].paths)
                {
                    RetPath r = new RetPath();
                    r.destination = my_node_id.i_qspn_get_naddr_as_mine().i_qspn_get_address_by_coord(d);
                    r.first_hop = p.first_hop;
                    r.following_hops = new ArrayList<IQspnPartialNaddr>();
                    r.following_hops.add_all(p.path.i_qspn_get_following_hops());
                    r.cost = p.path.i_qspn_get_cost();
                    r.nodes_inside = p.path.i_qspn_get_nodes_inside();
                    ret.add(r);
                }
            }
            return ret;
        }

        /* Remotable methods
         */

        public IQspnEtp get_full_etp(IQspnNaddr my_naddr)
        {
            // TODO
            return null;
        }
    }

}
