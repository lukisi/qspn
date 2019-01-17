using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    interface IIdentityAwareMissingArcHandler : Object
    {
        public abstract void missing(IdentityData identity_data, IdentityArc identity_arc);
    }

    class StubFactory : Object
    {
        public StubFactory()
        {
        }

        public IAddressManagerStub
        get_stub_identity_aware_unicast(
            /*INeighborhoodArc arc*/ string my_dev, string send_pathname,
            IdentityData identity_data,
            NodeID unicast_node_id,
            bool wait_reply=true)
        {
            NodeID source_node_id = identity_data.nodeid;
            IdentityAwareSourceID source_id = new IdentityAwareSourceID(source_node_id);
            IdentityAwareUnicastID unicast_id = new IdentityAwareUnicastID(unicast_node_id);
            string my_dev_mac = fake_random_mac(pid, my_dev);
            NeighbourSrcNic src_nic = new NeighbourSrcNic(my_dev_mac);
            return get_addr_stream_system(send_pathname, source_id, unicast_id, src_nic, wait_reply);
        }

        public IAddressManagerStub
        get_stub_identity_aware_unicast_from_ia(IdentityArc ia, bool wait_reply=true)
        {
            string my_dev = ia.arc.my_nic.dev;
            string send_pathname = @"conn_$(ia.arc.peer_linklocal)";
            IdentityData identity_data = ia.identity_data;
            NodeID unicast_node_id = ia.peer_nodeid;
            return get_stub_identity_aware_unicast(my_dev, send_pathname, identity_data, unicast_node_id, wait_reply);
        }

        public IAddressManagerStub
        get_stub_identity_aware_broadcast(
            string my_dev,
            IdentityData identity_data,
            Gee.List<NodeID> broadcast_node_id_set,
            IIdentityAwareMissingArcHandler? identity_missing_handler=null)
        {
            NodeID source_node_id = identity_data.nodeid;
            IdentityAwareSourceID source_id = new IdentityAwareSourceID(source_node_id);
            IdentityAwareBroadcastID broadcast_id = new IdentityAwareBroadcastID(broadcast_node_id_set);
            string my_dev_mac = fake_random_mac(pid, my_dev);
            NeighbourSrcNic src_nic = new NeighbourSrcNic(my_dev_mac);
            string send_pathname = @"send_$(pid)_$(my_dev)";

            IAckCommunicator? ack_com = null;
            if (identity_missing_handler != null)
            {
                NodeMissingArcHandlerForIdentityAware node_missing_handler
                    = new NodeMissingArcHandlerForIdentityAware(identity_missing_handler, identity_data);
                ack_com = new AcknowledgementsCommunicator(this, my_dev, node_missing_handler);
            }

            return get_addr_datagram_system(send_pathname, source_id, broadcast_id, src_nic, ack_com);
        }

        private /*Gee.List<INeighborhoodArc>*/ Gee.List<PseudoArc> get_current_arcs_for_broadcast(string my_dev)
        {
            var ret = new ArrayList<PseudoArc>();
            foreach (PseudoArc arc in arc_list)
                if (arc.my_nic.dev == my_dev)
                    ret.add(arc);
            return ret;
        }

        class NodeMissingArcHandlerForIdentityAware : Object
        {
            public NodeMissingArcHandlerForIdentityAware(IIdentityAwareMissingArcHandler identity_missing_handler, IdentityData identity_data)
            {
                this.identity_missing_handler = identity_missing_handler;
                this.identity_data = identity_data;
            }
            private IIdentityAwareMissingArcHandler identity_missing_handler;
            private weak IdentityData identity_data;

            public void missing(PseudoArc arc)
            {
                // from a pseudo INeighborhoodArc get a list of identity_arcs
                foreach (IdentityArc ia in identity_data.identity_arcs)
                {
                    // Does `ia` lay on this pseudo INeighborhoodArc?
                    if (ia.arc == arc)
                    {
                        // each identity_arc in its tasklet:
                        ActOnMissingTasklet ts = new ActOnMissingTasklet();
                        ts.identity_missing_handler = identity_missing_handler;
                        ts.identity_data = identity_data;
                        ts.ia = ia;
                        tasklet.spawn(ts);
                    }
                }
            }

            private class ActOnMissingTasklet : Object, ITaskletSpawnable
            {
                public IIdentityAwareMissingArcHandler identity_missing_handler;
                public IdentityData identity_data;
                public IdentityArc ia;
                public void * func()
                {
                    identity_missing_handler.missing(identity_data, ia);
                    return null;
                }
            }
        }

        /* The instance of this class is created when the stub factory is invoked to
         * obtain a stub for a message in broadcast on dev my_dev.
         */
        private class AcknowledgementsCommunicator : Object, IAckCommunicator
        {
            public StubFactory stub_factory;
            public string my_dev;
            public NodeMissingArcHandlerForIdentityAware node_missing_handler;
            public Gee.List<PseudoArc> lst_expected;

            public AcknowledgementsCommunicator(
                                StubFactory stub_factory,
                                string my_dev,
                                NodeMissingArcHandlerForIdentityAware node_missing_handler)
            {
                this.stub_factory = stub_factory;
                this.my_dev = my_dev;
                this.node_missing_handler = node_missing_handler;
                lst_expected = stub_factory.get_current_arcs_for_broadcast(my_dev);
            }

            public void process_src_nics_list(Gee.List<ISrcNic> src_nics_list) // Gee.List<string> responding_macs
            {
                // intersect with current ones now
                Gee.List<PseudoArc> lst_expected_now = stub_factory.get_current_arcs_for_broadcast(my_dev);
                ArrayList<PseudoArc> lst_expected_intersect = new ArrayList<PseudoArc>();
                foreach (var el in lst_expected)
                    if (el in lst_expected_now)
                        lst_expected_intersect.add(el);
                lst_expected = lst_expected_intersect;
                // prepare a list of missed arcs.
                var lst_missed = new ArrayList<PseudoArc>();
                foreach (PseudoArc expected in lst_expected)
                {
                    string expected_peer_mac = expected.peer_mac;
                    bool expected_peer_mac_in_src_nics_list = false;
                    foreach (ISrcNic src_nic in src_nics_list)
                    {
                        assert(src_nic is NeighbourSrcNic);
                        if (((NeighbourSrcNic)src_nic).mac == expected_peer_mac)
                        {
                            expected_peer_mac_in_src_nics_list = true;
                            break;
                        }
                    }
                    if (! expected_peer_mac_in_src_nics_list)
                        lst_missed.add(expected);
                }
                // foreach missed arc launch in a tasklet
                // the 'missing' callback.
                foreach (PseudoArc missed in lst_missed)
                {
                    // each neighborhood_arc in its tasklet:
                    ActOnMissingTasklet ts = new ActOnMissingTasklet();
                    ts.node_missing_handler = node_missing_handler;
                    ts.missed = missed;
                    tasklet.spawn(ts);
                }
            }

            private class ActOnMissingTasklet : Object, ITaskletSpawnable
            {
                public NodeMissingArcHandlerForIdentityAware node_missing_handler;
                public PseudoArc missed;
                public void * func()
                {
                    node_missing_handler.missing(missed);
                    return null;
                }
            }
        }
    }
}
