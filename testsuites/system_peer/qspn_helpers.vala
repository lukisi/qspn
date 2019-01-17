using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    class QspnStubFactory : Object, IQspnStubFactory
    {
        public QspnStubFactory(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public IQspnManagerStub
                        i_qspn_get_broadcast(
                            Gee.List<IQspnArc> arcs,
                            IQspnMissingArcHandler? missing_handler=null
                        )
        {
            if(arcs.is_empty) return new QspnManagerStubVoid();
            ArrayList<NodeID> broadcast_node_id_set = new ArrayList<NodeID>();
            foreach (IQspnArc arc in arcs)
            {
                QspnArc _arc = (QspnArc)arc;
                broadcast_node_id_set.add(_arc.destid);
            }
            Gee.List<IAddressManagerStub> addr_list = new ArrayList<IAddressManagerStub>();
            foreach (string my_dev in pseudonic_map.keys)
            {
                MissingArcHandlerForQspn? identity_missing_handler = null;
                if (missing_handler != null)
                {
                    identity_missing_handler = new MissingArcHandlerForQspn(missing_handler);
                }
                IAddressManagerStub addrstub = stub_factory.get_stub_identity_aware_broadcast(
                    my_dev,
                    identity_data,
                    broadcast_node_id_set,
                    identity_missing_handler);
                addr_list.add(addrstub);
            }
            QspnManagerStubBroadcastHolder ret = new QspnManagerStubBroadcastHolder(addr_list);
            return ret;
        }

        public IQspnManagerStub
                        i_qspn_get_tcp(
                            IQspnArc arc,
                            bool wait_reply=true
                        )
        {
            QspnArc _arc = (QspnArc)arc;
            IdentityArc ia = _arc.ia;
            IAddressManagerStub addrstub = stub_factory.get_stub_identity_aware_unicast_from_ia(ia, wait_reply);
            QspnManagerStubHolder ret = new QspnManagerStubHolder(addrstub);
            return ret;
        }
    }

    class MissingArcHandlerForQspn : Object, IIdentityAwareMissingArcHandler
    {
        public MissingArcHandlerForQspn(IQspnMissingArcHandler qspn_missing)
        {
            this.qspn_missing = qspn_missing;
        }
        private IQspnMissingArcHandler? qspn_missing;

        public void missing(IdentityData identity_data, IdentityArc identity_arc)
        {
            if (identity_arc.qspn_arc != null)
            {
                // identity_arc is on this network
                qspn_missing.i_qspn_missing(identity_arc.qspn_arc);
            }
        }
    }

    class ThresholdCalculator : Object, IQspnThresholdCalculator
    {
        public int i_qspn_calculate_threshold(IQspnNodePath p1, IQspnNodePath p2)
        {
            return 10000;
        }
    }

    class QspnArc : Object, IQspnArc
    {
        public QspnArc(NodeID sourceid, NodeID destid, IdentityArc ia)
        {
            this.sourceid = sourceid;
            this.destid = destid;
            this.ia = ia;
            cost_seed = PRNGen.int_range(0, 1000);
            arc = (PseudoArc)ia.arc;
        }
        public weak PseudoArc arc;
        public NodeID sourceid;
        public NodeID destid;
        public weak IdentityArc ia;
        private int cost_seed;

        public IQspnCost i_qspn_get_cost()
        {
            return new Cost(arc.cost + cost_seed);
        }

        public bool i_qspn_equals(IQspnArc other)
        {
            return other == this;
        }

        public bool i_qspn_comes_from(CallerInfo rpc_caller)
        {
            IdentityData identity_data = ia.identity_data;
            IdentityArc? caller_ia = skeleton_factory.from_caller_get_identityarc(rpc_caller, identity_data);
            if (caller_ia == null) return false;
            return caller_ia == ia;
        }
    }

    // For IQspnNaddr, IQspnMyNaddr, IQspnCost, IQspnFingerprint see Naddr, Cost, Fingerprint in serializables.vala
}

