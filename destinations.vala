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

        public Destination copy(ChangeFingerprintDelegate update_internal_fingerprints)
        {
            HCoord destination_copy_dest = new HCoord(this.dest.lvl, this.dest.pos);
            ArrayList<NodePath> destination_copy_paths = new ArrayList<NodePath>();
            foreach (NodePath np in this.paths)
            {
                // np.path is serializable
                EtpPath np_path;
                try {
                    np_path = deserialize_etp_path(serialize_etp_path(np.path));
                } catch (HelperDeserializeError e) {
                    assert_not_reached();
                }
                np_path.fingerprint = update_internal_fingerprints(np_path.fingerprint);
                destination_copy_paths.add(new NodePath(np.arc, np_path));
            }
            Destination destination_copy = new Destination(
                destination_copy_dest,
                destination_copy_paths
                );
            return destination_copy;
        }
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
}
