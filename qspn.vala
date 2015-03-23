/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2014-2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
using zcd;
using Tasklets;

namespace Netsukuku
{
    public interface IQspnNaddr : Object, IQspnAddress
    {
        public abstract int i_qspn_get_levels();
        public abstract int i_qspn_get_gsize(int level);
        public abstract int i_qspn_get_pos(int level);
    }

    public interface IQspnMyNaddr : Object, IQspnNaddr
    {
        public abstract IQspnPartialNaddr i_qspn_get_address_by_coord(HCoord dest);
        public abstract HCoord i_qspn_get_coord_by_address(IQspnNaddr dest);
    }

    public interface IQspnPartialNaddr : Object, IQspnNaddr
    {
        public abstract int i_qspn_get_level_of_gnode();
    }

    public interface IQspnFingerprint : Object
    {
        public abstract bool i_qspn_equals(IQspnFingerprint other);
        public abstract bool i_qspn_elder(IQspnFingerprint other);
        public abstract int i_qspn_level_todo_delete {get;}
        public abstract IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingers);
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
    internal class NullCost : Object, IQspnCost, ISerializable
    {
        public Variant serialize_to_variant()
        {
            return 0;
        }

        public void deserialize_from_variant(Variant v) throws SerializerError
        {
        }

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
    internal class DeadCost : Object, IQspnCost, ISerializable
    {
        public Variant serialize_to_variant()
        {
            return 0;
        }

        public void deserialize_from_variant(Variant v) throws SerializerError
        {
        }

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
        public abstract bool i_qspn_comes_from(zcd.CallerInfo rpc_caller);
    }

    internal class EtpMessage : Object, ISerializable, IQspnEtpMessage
    {
        public IQspnNaddr node_address;
        public Gee.List<IQspnFingerprint> fingerprints;
        public Gee.List<int> nodes_inside;
        public Gee.List<HCoord> hops;
        public Gee.List<EtpPath> p_list;

        // TODO costruttore

        public Variant serialize_to_variant()
        {
            assert(node_address is ISerializable);
            Variant v0 = Serializer.uchar_array_to_variant((node_address as ISerializable).serialize());

            ListISerializable lst1 = new ListISerializable.with_backer((Gee.List<ISerializable>)fingerprints);
            Variant v1 = lst1.serialize_to_variant();

            int[] ai = nodes_inside.to_array();
            Variant v2 = Serializer.int_array_to_variant(ai);

            ListISerializable lst3 = new ListISerializable.with_backer(hops);
            Variant v3 = lst3.serialize_to_variant();

            ListISerializable lst4 = new ListISerializable.with_backer(p_list);
            Variant v4 = lst4.serialize_to_variant();

            Variant vret = Serializer.tuple_to_variant_5(v0, v1, v2, v3, v4);
            return vret;
        }

        public void deserialize_from_variant(Variant v) throws SerializerError
        {
            Variant v0;
            Variant v1;
            Variant v2;
            Variant v3;
            Variant v4;
            Serializer.variant_to_tuple_5(v, out v0, out v1, out v2, out v3, out v4);

            ISerializable ret = ISerializable.deserialize(Serializer.variant_to_uchar_array(v0));
            if (! (ret is IQspnNaddr))
            {
                throw new SerializerError.GENERIC(
                    "Deserialization returned a '" +
                    ret.get_type().name() +
                    "' which is not a 'IQspnNaddr'"
                );
            }
            node_address = ret as IQspnNaddr;

            ListISerializable lst1 = (ListISerializable)Object.new(typeof(ListISerializable));
            lst1.deserialize_from_variant(v1);
            fingerprints = (Gee.List<IQspnFingerprint>)lst1.backed;

            nodes_inside = new ArrayList<int>();
            int[] ai = Serializer.variant_to_int_array(v0);
            nodes_inside.add_all_array(ai);

            ListISerializable lst3 = (ListISerializable)Object.new(typeof(ListISerializable));
            lst3.deserialize_from_variant(v3);
            hops = (Gee.List<HCoord>)lst3.backed;

            ListISerializable lst4 = (ListISerializable)Object.new(typeof(ListISerializable));
            lst4.deserialize_from_variant(v4);
            p_list = (Gee.List<EtpPath>)lst4.backed;
        }

    }

    internal class EtpPath : Object, ISerializable
    {
        public Gee.List<HCoord> hops;
        public IQspnCost cost;
        public IQspnFingerprint fingerprint;
        public int nodes_inside;

        // TODO costruttore

        public Variant serialize_to_variant()
        {
            ListISerializable lst0 = new ListISerializable.with_backer(hops);
            Variant v0 = lst0.serialize_to_variant();

            assert(cost is ISerializable);
            Variant v1 = Serializer.uchar_array_to_variant((cost as ISerializable).serialize());

            assert(fingerprint is ISerializable);
            Variant v2 = Serializer.uchar_array_to_variant((fingerprint as ISerializable).serialize());

            Variant v3 = Serializer.int_to_variant(nodes_inside);

            Variant vret = Serializer.tuple_to_variant_4(v0, v1, v2, v3);
            return vret;
        }

        public void deserialize_from_variant(Variant v) throws SerializerError
        {
            Variant v0;
            Variant v1;
            Variant v2;
            Variant v3;
            Serializer.variant_to_tuple_4(v, out v0, out v1, out v2, out v3);

            ListISerializable lst0 = (ListISerializable)Object.new(typeof(ListISerializable));
            lst0.deserialize_from_variant(v0);
            hops = (Gee.List<HCoord>)lst0.backed;

            ISerializable ret = ISerializable.deserialize(Serializer.variant_to_uchar_array(v1));
            if (! (ret is IQspnCost))
            {
                throw new SerializerError.GENERIC(
                    "Deserialization returned a '" +
                    ret.get_type().name() +
                    "' which is not a 'IQspnCost'"
                );
            }
            cost = ret as IQspnCost;

            ISerializable ret2 = ISerializable.deserialize(Serializer.variant_to_uchar_array(v2));
            if (! (ret2 is IQspnFingerprint))
            {
                throw new SerializerError.GENERIC(
                    "Deserialization returned a '" +
                    ret2.get_type().name() +
                    "' which is not a 'IQspnFingerprint'"
                );
            }
            fingerprint = ret2 as IQspnFingerprint;

            nodes_inside = Serializer.variant_to_int(v3);
        }

    }

    internal class NodePath : Object
    {
        public NodePath(IQspnArc arc, EtpPath path)
        {
            this.arc = arc;
            this.path = path;
        }
        public IQspnArc arc;
        public EtpPath path;
        public bool hops_are_equal(NodePath q)
        {
            if (! q.arc.i_qspn_equals(arc)) return false;
            Gee.List<HCoord> mylist = path.hops;
            Gee.List<HCoord> qlist = q.path.hops;
            if (mylist.size != qlist.size) return false;
            for (int i = 0; i < mylist.size; i++)
                if (! (mylist[i].equals(qlist[i]))) return false;
            return true;
        }
    }

    public interface IQspnNodePath : Object
    {
        public abstract IQspnArc i_qspn_get_arc();
        public abstract Gee.List<IQspnPartialNaddr> i_qspn_get_hops();
        public abstract IQspnCost i_qspn_get_cost();
        public abstract int i_qspn_get_nodes_inside();
    }

    internal class RetPath : Object, IQspnNodePath
    {
        public IQspnArc arc;
        public ArrayList<IQspnPartialNaddr> hops;
        public IQspnCost cost;
        public int nodes_inside;

        /* Interface */
        public IQspnArc i_qspn_get_arc() {return arc;}
        public Gee.List<IQspnPartialNaddr> i_qspn_get_hops() {return hops;}
        public IQspnCost i_qspn_get_cost() {return cost;}
        public int i_qspn_get_nodes_inside() {return nodes_inside;}
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
        public abstract IAddressManagerRootDispatcher
                        i_qspn_get_broadcast(
                            IQspnMissingArcHandler? missing_handler=null,
                            IQspnArc? ignore_neighbor=null
                        );
        public abstract IAddressManagerRootDispatcher
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
            this.paths = new ArrayList<NodePath>();
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
                    if (! fpd.i_qspn_equals(fpdp))
                    {
                        if (! fpd.i_qspn_elder(fpdp))
                        {
                            fpd = fpdp;
                            nnd = nndp;
                            best_p = p;
                        }
                    }
                    else
                    {
                        IQspnCost p_cost = p.path.cost
                            .i_qspn_add_segment(p.arc.i_qspn_get_cost());
                        IQspnCost best_p_cost = best_p.path.cost
                            .i_qspn_add_segment(best_p.arc.i_qspn_get_cost());
                        if (p_cost.i_qspn_compare_to(best_p_cost) < 0)
                        {
                            nnd = nndp;
                            best_p = p;
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
    }

    public class QspnManager : Object,
                               IQspnManager
    {
        public static void init()
        {
            // Register serializable types
            // typeof(Xxx).class_peek();
        }

        private IQspnMyNaddr my_naddr;
        private int max_paths;
        private double max_common_hops_ratio;
        private int arc_timeout;
        private ArrayList<IQspnArc> my_arcs;
        private ArrayList<IQspnFingerprint> my_fingerprints;
        private ArrayList<int> my_nodes_inside;
        private IQspnThresholdCalculator threshold_calculator;
        private IQspnStubFactory stub_factory;
        private int levels;
        private int[] gsizes;
        private bool mature;
        private Tasklet? periodical_update_tasklet = null;
        private ArrayList<QueuedEvent> queued_events;
        // This collection can be accessed by index (level) and then by iteration on the
        //  values. This is useful when we want to iterate on a certain level.
        //  In addition we can specify a level and then refer by index to the
        //  position. This is useful when we want to remove one item.
        private ArrayList<HashMap<int, Destination>> destinations;

        public QspnManager(IQspnMyNaddr my_naddr,
                           int max_paths,
                           double max_common_hops_ratio,
                           int arc_timeout,
                           Gee.List<IQspnArc> my_arcs,
                           IQspnFingerprint my_fingerprint,
                           IQspnThresholdCalculator threshold_calculator,
                           IQspnStubFactory stub_factory
                           )
        {
            this.my_naddr = my_naddr;
            this.max_paths = max_paths;
            this.max_common_hops_ratio = max_common_hops_ratio;
            this.arc_timeout = arc_timeout;
            this.threshold_calculator = threshold_calculator;
            this.stub_factory = stub_factory;
            // all the arcs
            this.my_arcs = new ArrayList<IQspnArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.i_qspn_equals(b);
                }
            );
            foreach (IQspnArc arc in my_arcs)
            {
                // Check data right away
                IQspnCost c = arc.i_qspn_get_cost();
                assert(c != null);

                this.my_arcs.add(arc);
            }
            // find parameters of the network
            levels = my_naddr.i_qspn_get_levels();
            gsizes = new int[levels];
            for (int l = 0; l < levels; l++) gsizes[l] = my_naddr.i_qspn_get_gsize(l);
            // Only the level 0 fingerprint is given. The other ones
            // will be constructed when the node is mature.
            this.my_fingerprints = new ArrayList<IQspnFingerprint>();
            this.my_nodes_inside = new ArrayList<int>();
            my_fingerprints.add(my_fingerprint); // level 0 fingerprint
            my_nodes_inside.add(1); // level 0 nodes_inside
            for (int lvl = 1; lvl <= levels; lvl++)
            {
                // At start build fingerprint at level lvl with fingerprint at
                // level lvl-1 and an empty set.
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

        internal class MissingArcSendEtp : Object, IQspnMissingArcHandler
        {
            public MissingArcSendEtp(QspnManager qspnman, IQspnEtpMessage m)
            {
                this.qspnman = qspnman;
                this.m = m;
            }
            public QspnManager qspnman;
            public IQspnEtpMessage m;
            public void i_qspn_missing(IQspnArc arc)
            {
                IAddressManagerRootDispatcher disp =
                        qspnman.stub_factory.i_qspn_get_tcp(arc);
                debug("Sending reliable ETP to missing arc");
                try {
                    disp.qspn_manager.send_etp(m);
                }
                catch (QspnNotAcceptedError e) {
                    // we're not in its arcs; remove and emit signal
                    qspnman.arc_remove(arc);
                    // emit signal
                    qspnman.arc_removed(arc);
                }
                catch (RPCError e) {
                    // remove failed arc and emit signal
                    qspnman.arc_remove(arc);
                    // emit signal
                    qspnman.arc_removed(arc);
                }
            }
        }

        private class QueuedEvent : Object
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
            public QueuedEvent.etp_received(IQspnEtpMessage etp, IQspnArc arc)
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
            public IQspnEtpMessage etp;
        }

        // The module is notified if an arc is added/changed/removed
        public void arc_add(IQspnArc arc)
        {
            // Check data right away
            IQspnCost c = arc.i_qspn_get_cost();
            assert(c != null);

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
                    stub_factory.i_qspn_get_tcp(arc);
            EtpMessage? etp = null;
            try {
                while (true)
                {
                    try {
                        debug("Requesting ETP from new arc");
                        IQspnEtpMessage resp = disp_get_etp.qspn_manager.get_full_etp(my_naddr);
                        if (! (resp is EtpMessage))
                        {
                            // The module only knows this class that implements IQspnEtpMessage, so this
                            //  should not happen. But the rest of the code, who knows? So to be sure
                            //  we check. If it is the case remove the arc.
                            arc_remove(arc);
                            // emit signal
                            arc_removed(arc);
                            return;
                        }
                        etp = (EtpMessage) resp;
                        break;
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
            catch (QspnNotAcceptedError e) {
                // remove failed arc and emit signal
                arc_remove(arc);
                // emit signal
                arc_removed(arc);
                return;
            }
            // Got ETP from new neighbor/arc. preprocess... TODO.


            // create a new etp for arc ... TODO.
            EtpMessage full_etp = null;



            IAddressManagerRootDispatcher disp_send_to_arc =
                    stub_factory.i_qspn_get_tcp(arc);
            debug("Sending ETP to new arc");
            try {
                disp_send_to_arc.qspn_manager.send_etp(full_etp);
            }
            catch (QspnNotAcceptedError e) {
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
            // Check data right away
            IQspnCost c = changed_arc.i_qspn_get_cost();
            assert(c != null);

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
            // Process ETPs and update my map. preprocess... TODO.



            // create a new etp for all. TODO
            // if...
            EtpMessage new_etp = null;



            IAddressManagerRootDispatcher disp_send_to_all =
                    stub_factory.i_qspn_get_broadcast(
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

        public void arc_remove(IQspnArc removed_arc)
        {
            // Check data right away
            IQspnCost c = removed_arc.i_qspn_get_cost();
            assert(c != null);

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
            for (int l = 0; l < levels; l++) foreach (Destination d in destinations[l].values)
            {
                int i = 0;
                while (i < d.paths.size)
                {
                    NodePath np = d.paths[i];
                    if (np.arc.i_qspn_equals(removed_arc))
                    {
                        d.paths.remove_at(i);
                        np.path.cost = new DeadCost();
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
            // Then do the same as when arc is changed and remember to add path_to_add_to_changed_paths: ...TODO



            EtpMessage new_etp = null;



            IAddressManagerRootDispatcher disp_send_to_all =
                    stub_factory.i_qspn_get_broadcast(
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
        public signal void gnode_splitted(IQspnNodePath p);

        // Helper: get IQspnNodePath from NodePath
        private RetPath get_ret_path(NodePath np)
        {
            EtpPath p = np.path;
            IQspnArc arc = np.arc;
            RetPath r = new RetPath();
            r.arc = arc;
            r.hops = new ArrayList<IQspnPartialNaddr>();
            foreach (HCoord h in p.hops)
                r.hops.add(my_naddr.i_qspn_get_address_by_coord(h));
            r.cost = p.cost.i_qspn_add_segment(arc.i_qspn_get_cost());
            r.nodes_inside = p.nodes_inside;
            return r;
        }

        // Helper: prepare new ETP
        private EtpMessage prepare_new_etp(Collection<NodePath> node_paths, Gee.List<HCoord>? tp_list=null)
        {
            EtpMessage ret = new EtpMessage();
            ret.p_list = new ArrayList<EtpPath>();
            foreach (NodePath np in node_paths)
            {
                EtpPath p = new EtpPath();
                p.hops = new ArrayList<HCoord>();
                p.hops.add_all(np.path.hops);
                p.fingerprint = np.path.fingerprint;
                p.nodes_inside = np.path.nodes_inside;
                p.cost = np.arc.i_qspn_get_cost().i_qspn_add_segment(np.path.cost);
                ret.p_list.add(p);
            }
            ret.node_address = my_naddr;
            ret.fingerprints = new ArrayList<IQspnFingerprint>();
            ret.fingerprints.add_all(my_fingerprints);
            ret.nodes_inside = new ArrayList<int>();
            ret.nodes_inside.add_all(my_nodes_inside);
            ret.hops = new ArrayList<HCoord>();
            if (tp_list != null) ret.hops.add_all(tp_list);
            return ret;
        }

        // Helper: prepare full ETP
        private EtpMessage prepare_full_etp()
        {
            var node_paths = new ArrayList<NodePath>();
            for (int l = 0; l < levels; l++)
                foreach (Destination d in destinations[l].values)
                    node_paths.add_all(d.paths);
            return prepare_new_etp(node_paths);
        }

        // Helper: prepare forward ETP
        private EtpMessage prepare_fwd_etp(EtpMessage m, Collection<NodePath> node_paths)
        {
            // The message 'm' has been pre-processed, so that m.hops has the 'exit_gnode'
            //  at the beginning.
            return prepare_new_etp(node_paths, m.hops);
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
                var disp = stub_factory.i_qspn_get_tcp(arc);
                work.arcs.add(arc);
                work.disps.add(disp);
                Tasklet t = Tasklet.tasklet_callback(
                    (_work, _i) => {
                        GatherEtpSetData t_work = _work as GatherEtpSetData;
                        int t_i = (_i as SerializableInt).i;
                        try
                        {
                            IAddressManagerRootDispatcher t_disp = t_work.disps[t_i];
                            IQspnEtpMessage resp = t_disp.qspn_manager.get_full_etp(t_work.my_naddr);
                            if (resp is EtpMessage)
                            {
                                EtpMessage m = (EtpMessage) resp;
                                PairArcEtp res = new PairArcEtp(m, t_work.arcs[t_i]);
                                t_work.results.add(res);
                            }
                            else
                            {
                                // The module only knows this class that implements IQspnEtpMessage, so this
                                //  should not happen. But the rest of the code, who knows? So to be sure
                                //  we check. If it is the case remove the arc.
                                t_work.failed_arc_handler(t_work.arcs[t_i]);
                            }
                        }
                        catch (QspnNotMatureError e)
                        {
                            // ignore
                        }
                        catch (QspnNotAcceptedError e)
                        {
                            t_work.failed_arc_handler(t_work.arcs[t_i]);
                        }
                        catch (RPCError e)
                        {
                            t_work.failed_arc_handler(t_work.arcs[t_i]);
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
            return work.results;
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
                // This instance of QspnManager will be discarded
                stop_operations();
            }
            else
            {
                debug("Processing ETP set");
                var q_set = new ArrayList<NodePath>();
                foreach (PairArcEtp pair_arc_etp in results)
                {
                    // ... preprocess_etp();
                    // TODO
                }
                
                // if...
                // TODO



                // prepare ETP and send to all my neighbors.
                EtpMessage full_etp = prepare_full_etp();
                IAddressManagerRootDispatcher disp_send_to_all =
                        stub_factory.i_qspn_get_broadcast(
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
                mature = true;
                qspn_mature();
                // Process queued events if any.
                foreach (QueuedEvent ev in queued_events)
                {
                    if (ev.type == 1) arc_add(ev.arc);
                    if (ev.type == 2) arc_is_changed(ev.arc);
                    if (ev.type == 3) arc_remove(ev.arc);
                    if (ev.type == 4) got_etp_from_arc(ev.etp, ev.arc);
                }
            }
        }

        /** Periodically update full
          */
        private void periodical_update()
        {
            while (true)
            {
                ms_wait(600000); // 10 minutes
                EtpMessage full_etp = prepare_full_etp();
                IAddressManagerRootDispatcher disp_send_to_all =
                        stub_factory.i_qspn_get_broadcast(
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

        // Helper: check that an ETP is valid:
        // The address MUST have the same topology parameters as mine.
        // The address MUST NOT be the same as mine.
        // For each TP-List tpl (that is the main and that of each path in P):
        //  . For each HCoord in tpl.hops:
        //    . lvl has to be between 0 and levels-1
        //    . lvl has to grow only
        //    . pos has to be between 0 and gsize(lvl)-1
        private bool check_network_parameters(EtpMessage m)
        {
            if (m.node_address.i_qspn_get_levels() != levels) return false;
            bool not_same = false;
            for (int l = 0; l < levels; l++)
            {
                if (m.node_address.i_qspn_get_gsize(l) != gsizes[l]) return false;
                if (m.node_address.i_qspn_get_pos(l) != my_naddr.i_qspn_get_pos(l)) not_same = true;
            }
            if (! not_same) return false;
            if (! check_tplist(m.hops)) return false;
            foreach (EtpPath p in m.p_list)
                if (! check_tplist(p.hops)) return false;
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

        // Helper: pre-process received ETP to make it valid for me.
        // It returns a collection, possibly empty, of paths which are valid
        // from this node.
        private Collection<NodePath> preprocess_etp(EtpMessage m, IQspnArc a)
        {
            ArrayList<NodePath> ret = new ArrayList<NodePath>();
            if (check_network_parameters(m))
            {
                HCoord exit_gnode = my_naddr.
                        i_qspn_get_coord_by_address(
                        m.node_address);
                int i = exit_gnode.lvl+1;
                // grouping rule for m.hops
                while (m.hops.size > 0)
                    if (m.hops[0].lvl < i-1)
                        m.hops.remove_at(0);
                m.hops.insert(0, exit_gnode);
                // acyclic rule for m.hops
                bool cycle = false;
                foreach (HCoord h in m.hops)
                    if (h.pos == my_naddr.i_qspn_get_pos(h.lvl))
                    {
                        cycle = true;
                        break;
                    }
                if (! cycle)
                {
                    int j = 0;
                    while (j < m.p_list.size)
                    {
                        EtpPath p = m.p_list[j];
                        if (p.hops.last().lvl < i-1)
                            m.p_list.remove_at(j);
                        else
                            j++;
                    }
                    j = 0;
                    while (j < m.p_list.size)
                    {
                        EtpPath p = m.p_list[j];
                        // grouping rule for p.hops
                        while (p.hops.size > 0)
                            if (p.hops[0].lvl < i-1)
                                p.hops.remove_at(0);
                        p.hops.insert(0, exit_gnode);
                        // acyclic rule for p.hops
                        cycle = false;
                        foreach (HCoord h in m.hops)
                            if (h.pos == my_naddr.i_qspn_get_pos(h.lvl))
                            {
                                cycle = true;
                                break;
                            }
                        if (cycle)
                            m.p_list.remove_at(j);
                        else
                            j++;
                    }
                    EtpPath new_p = new EtpPath();
                    new_p.hops = new ArrayList<HCoord>();
                    new_p.hops.add(exit_gnode);
                    new_p.cost = new NullCost();
                    new_p.fingerprint = m.fingerprints[i-1];
                    new_p.nodes_inside = m.nodes_inside[i-1];
                    m.p_list.add(new_p);
                    foreach (EtpPath p in m.p_list)
                        ret.add(new NodePath(a, p));
                }
                else
                {
                    // dropped because of acyclic rule
                    debug("Cyclic ETP dropped");
                }
            }
            else
            {
                // malformed ETP
                log_warn("ETP malformed");
            }
            return ret;
        }

        private class SignalToEmit : Object
        {
            public int t;
            // 1: path_added
            // 2: path_changed
            // 3: path_removed
            // 4: destination_added
            // 5: destination_removed
            public IQspnNodePath? p;
            public IQspnPartialNaddr? d;
        }
        // Helper: update my map from a set of paths collected from a set
        // of ETP messages.
        internal void
        update_map(Collection<NodePath> q_set,
                   IQspnArc? a_changed,
                   out Collection<NodePath> p_set,
                   out Collection<HCoord> b_set)
        {
            // q_set is the set of new paths that have been detected.
            // p_set will be the set of paths that have been changed in my map
            //  so that we have to send them to our neighbors as a forwarded ETP.
            // b_set will be the set of g-nodes for which we have to flood a new
            //  ETP because of the rule of first split detection.
            p_set = new ArrayList<NodePath>();
            b_set = new ArrayList<HCoord>();
            // Group by destination
            HashMap<HCoord, ArrayList<NodePath>> q_by_dest = new HashMap<HCoord, ArrayList<NodePath>>(
                (a) => {return a.lvl*100+a.pos;},  /* hash_func */
                (a, b) => {return a.equals(b);});  /* equal_func */
            foreach (NodePath np in q_set)
            {
                HCoord d = np.path.hops.last();
                if (! (d in q_by_dest.keys)) q_by_dest[d] = new ArrayList<NodePath>();
                q_by_dest[d].add(np);
            }
            foreach (HCoord d in q_by_dest.keys)
            {
                ArrayList<NodePath> qd_set = q_by_dest[d];
                ArrayList<NodePath> md_set = new ArrayList<NodePath>();
                if (destinations[d.lvl].has_key(d.pos))
                {
                    Destination dd = destinations[d.lvl][d.pos];
                    md_set.add_all(dd.paths);
                }
                ArrayList<IQspnFingerprint> f1 = new ArrayList<IQspnFingerprint>((a, b) => {return a.i_qspn_equals(b);});
                foreach (NodePath np in md_set)
                    if (! (np.path.fingerprint in f1))
                        f1.add(np.path.fingerprint);
                ArrayList<NodePath> od_set = new ArrayList<NodePath>();
                ArrayList<NodePath> vd_set = new ArrayList<NodePath>();
                ArrayList<SignalToEmit> sd = new ArrayList<SignalToEmit>();
                foreach (NodePath p1 in md_set)
                {
                    NodePath? p2 = null;
                    foreach (NodePath p_test in qd_set)
                    {
                        if (p_test.hops_are_equal(p1))
                        {
                            p2 = p_test;
                            break;
                        }
                    }
                    if (p2 != null)
                    {
                        bool apply = false;
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
                od_set.sort((np1, np2) => {
                    // np1 > np2 <=> return +1
                    IQspnCost c1 = np1.arc.i_qspn_get_cost().i_qspn_add_segment(np1.path.cost);
                    IQspnCost c2 = np2.arc.i_qspn_get_cost().i_qspn_add_segment(np2.path.cost);
                    return c1.i_qspn_compare_to(c2);
                });
                HashMap<HCoord, int> num_nodes_inside = new HashMap<HCoord, int>(
                    (a) => {return a.lvl*100+a.pos;},  /* hash_func */
                    (a, b) => {return a.equals(b);});  /* equal_func */
                int od_i = 0;
                while (od_i < od_set.size)
                {
                    NodePath p = od_set[od_i];
                    for (int p_i = 0; p_i < p.path.hops.size-1; p_i++)
                    {
                        HCoord h = p.path.hops[p_i];
                        if (destinations[h.lvl].has_key(h.pos))
                        {
                            num_nodes_inside[h] = destinations[h.lvl][h.pos].nodes_inside;
                            od_i++;
                        }
                        else
                        {
                            od_set.remove_at(od_i);
                        }
                    }
                }
                ArrayList<IQspnFingerprint> fd = new ArrayList<IQspnFingerprint>((a, b) => {return a.i_qspn_equals(b);});
                ArrayList<NodePath> rd = new ArrayList<NodePath>();
                ArrayList<HCoord> vnd = new ArrayList<HCoord>((a, b) => {return a.equals(b);});
                foreach (IQspnArc a in my_arcs)
                {
                    HCoord v = my_naddr.i_qspn_get_coord_by_address(a.i_qspn_get_naddr());
                    if (! (v in vnd)) vnd.add(v);
                }
                
            }
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

        public IQspnEtpMessage
        get_full_etp(IQspnAddress requesting_address,
                     zcd.CallerInfo? _rpc_caller=null)
        throws QspnNotAcceptedError, QspnNotMatureError
        {
            if (!mature) throw new QspnNotMatureError.GENERIC("I am not mature.");

            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from this arc.
            IQspnArc? arc = null;
            Tasklets.Timer t = new Tasklets.Timer(arc_timeout);
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
                ms_wait(arc_timeout / 10);
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
                throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");
            }
            IQspnNaddr requesting_naddr = (IQspnNaddr) requesting_address;

            HCoord b = my_naddr.i_qspn_get_coord_by_address(requesting_naddr);
            var node_paths = new ArrayList<NodePath>();
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
                    if (!found) node_paths.add(np);
                }
            }
            debug("Sending ETP on request");
            return prepare_new_etp(node_paths);
        }

        public void send_etp(IQspnEtpMessage m, zcd.CallerInfo? _rpc_caller=null) throws QspnNotAcceptedError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from this arc.
            IQspnArc? arc = null;
            Tasklets.Timer t = new Tasklets.Timer(arc_timeout);
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
                ms_wait(arc_timeout / 10);
            }
            if (arc == null) throw new QspnNotAcceptedError.GENERIC("You are not in my arcs.");

            got_etp_from_arc(m, arc);
        }
        
        private void got_etp_from_arc(IQspnEtpMessage m, IQspnArc arc)
        {
            if (!mature)
            {
                queued_events.add(new QueuedEvent.etp_received(m, arc));
                return;
            }
            if (! (arc in my_arcs)) return;
            debug("Processing ETP");
            // preprocess, update... TODO.
        }
    }

    // Defining extern functions.
    // Do not make them 'public', because they are not exposed by this
    // module (convenience library), but instead the module use them
    // as they are provided by the core app.
    extern void log_warn(string msg);
    extern void log_error(string msg);
}
