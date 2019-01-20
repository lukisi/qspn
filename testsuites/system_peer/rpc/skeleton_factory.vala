using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    class SkeletonFactory : Object
    {
        public SkeletonFactory()
        {
            dlg = new ServerDelegate(this);
        }

        private ServerDelegate dlg;
        HashMap<string,IListenerHandle> handles_by_listen_pathname;

        public void start_stream_system_listen(string listen_pathname)
        {
            IErrorHandler stream_system_err = new ServerErrorHandler(@"for stream_system_listen $(listen_pathname)");
            if (handles_by_listen_pathname == null) handles_by_listen_pathname = new HashMap<string,IListenerHandle>();
            handles_by_listen_pathname[listen_pathname] = stream_system_listen(dlg, stream_system_err, listen_pathname);
        }
        public void stop_stream_system_listen(string listen_pathname)
        {
            assert(handles_by_listen_pathname != null);
            assert(handles_by_listen_pathname.has_key(listen_pathname));
            IListenerHandle lh = handles_by_listen_pathname[listen_pathname];
            lh.kill();
            handles_by_listen_pathname.unset(listen_pathname);
        }

        public void start_datagram_system_listen(string listen_pathname, string send_pathname, ISrcNic src_nic)
        {
            string s_src_nic = "";
            if (src_nic is NeighbourSrcNic) s_src_nic = @"((NeighbourSrcNic)src_nic).mac";
            IErrorHandler datagram_system_err = new ServerErrorHandler(@"for datagram_system_listen $(listen_pathname) $(send_pathname) $(s_src_nic)");
            if (handles_by_listen_pathname == null) handles_by_listen_pathname = new HashMap<string,IListenerHandle>();
            handles_by_listen_pathname[listen_pathname] = datagram_system_listen(dlg, datagram_system_err, listen_pathname, send_pathname, src_nic);
        }
        public void stop_datagram_system_listen(string listen_pathname)
        {
            assert(handles_by_listen_pathname != null);
            assert(handles_by_listen_pathname.has_key(listen_pathname));
            IListenerHandle lh = handles_by_listen_pathname[listen_pathname];
            lh.kill();
            handles_by_listen_pathname.unset(listen_pathname);
        }

        [NoReturn]
        private void abort_tasklet(string msg_warning)
        {
            warning(msg_warning);
            tasklet.exit_tasklet();
        }

        private IAddressManagerSkeleton? get_dispatcher(StreamCallerInfo caller_info)
        {
            // in this test we have only IdentityAwareSourceID and IdentityAwareUnicastID
            if (! (caller_info.source_id is IdentityAwareSourceID)) abort_tasklet(@"Bad caller_info.source_id");
            IdentityAwareSourceID _source_id = (IdentityAwareSourceID)caller_info.source_id;
            NodeID source_nodeid = _source_id.id;
            if (! (caller_info.unicast_id is IdentityAwareUnicastID)) abort_tasklet(@"Bad caller_info.unicast_id");
            IdentityAwareUnicastID _unicast_id = (IdentityAwareUnicastID)caller_info.unicast_id;
            NodeID unicast_nodeid = _unicast_id.id;
            if (! (caller_info.src_nic is NeighbourSrcNic)) abort_tasklet(@"Bad caller_info.src_nic");
            string peer_mac = ((NeighbourSrcNic)caller_info.src_nic).mac;
            return get_identity_skeleton(source_nodeid, unicast_nodeid, peer_mac);
        }

        private Gee.List<IAddressManagerSkeleton> get_dispatcher_set(DatagramCallerInfo caller_info)
        {
            // in this test we have only IdentityAwareSourceID and IdentityAwareBroadcastID
            if (! (caller_info.source_id is IdentityAwareSourceID)) abort_tasklet(@"Bad caller_info.source_id");
            IdentityAwareSourceID _source_id = (IdentityAwareSourceID)caller_info.source_id;
            NodeID source_nodeid = _source_id.id;
            if (! (caller_info.broadcast_id is IdentityAwareBroadcastID)) abort_tasklet(@"Bad caller_info.broadcast_id");
            IdentityAwareBroadcastID _broadcast_set = (IdentityAwareBroadcastID)caller_info.broadcast_id;
            Gee.List<NodeID> broadcast_set = _broadcast_set.id_set;
            if (! (caller_info.src_nic is NeighbourSrcNic)) abort_tasklet(@"Bad caller_info.src_nic");
            string peer_mac = ((NeighbourSrcNic)caller_info.src_nic).mac;
            if (! (caller_info.listener is DatagramSystemListener)) abort_tasklet(@"Bad caller_info.listener");
            string caller_listen_pathname = ((DatagramSystemListener)caller_info.listener).listen_pathname;
            string my_dev = null;
            foreach (string dev in pseudonic_map.keys)
            {
                if (pseudonic_map[dev].listen_pathname == caller_listen_pathname)
                {
                    my_dev = dev;
                    break;
                }
            }
            if (my_dev == null) abort_tasklet(@"Bad caller_info.listener.listen_pathname=$(caller_listen_pathname)");
            return get_identity_skeleton_set(source_nodeid, broadcast_set, peer_mac, my_dev);
        }

        private IAddressManagerSkeleton?
        get_identity_skeleton(
            NodeID source_nodeid,
            NodeID unicast_nodeid,
            string peer_mac)
        {
            IdentityData local_identity_data = find_local_identity(unicast_nodeid);
            if (local_identity_data == null) return null;

            foreach (IdentityArc ia in local_identity_data.identity_arcs)
            {
                if (ia.arc.peer_mac == peer_mac)
                {
                    if (ia.peer_nodeid.equals(source_nodeid))
                    {
                        return new IdentitySkeleton(local_identity_data);
                    }
                }
            }

            return null;
        }

        private Gee.List<IAddressManagerSkeleton>
        get_identity_skeleton_set(
            NodeID source_nodeid,
            Gee.List<NodeID> broadcast_set,
            string peer_mac,
            string my_dev)
        {
            ArrayList<IAddressManagerSkeleton> ret = new ArrayList<IAddressManagerSkeleton>();
            foreach (IdentityData local_identity_data in local_identities.values)
            {
                NodeID local_nodeid = local_identity_data.nodeid;
                if (local_nodeid in broadcast_set)
                {
                    foreach (IdentityArc ia in local_identity_data.identity_arcs)
                    {
                        if (ia.arc.peer_mac == peer_mac
                            && ia.arc.my_nic.dev == my_dev)
                        {
                            if (ia.peer_nodeid.equals(source_nodeid))
                            {
                                ret.add(new IdentitySkeleton(local_identity_data));
                            }
                        }
                    }
                }
            }
            return ret;
        }

        // from_caller_get_nodearc not in this test

        /* Get IdentityArc where a received message has transited. For identity-aware requests.
         */
        public IdentityArc?
        from_caller_get_identityarc(CallerInfo rpc_caller, IdentityData identity_data)
        {
            if (rpc_caller is StreamCallerInfo)
            {
                StreamCallerInfo caller_info = (StreamCallerInfo)rpc_caller;

                // in this test we have only IdentityAwareSourceID and IdentityAwareUnicastID
                if (! (caller_info.source_id is IdentityAwareSourceID)) abort_tasklet(@"Bad caller_info.source_id");
                IdentityAwareSourceID _source_id = (IdentityAwareSourceID)caller_info.source_id;
                NodeID source_nodeid = _source_id.id;
                if (! (caller_info.src_nic is NeighbourSrcNic)) abort_tasklet(@"Bad caller_info.src_nic");
                string peer_mac = ((NeighbourSrcNic)caller_info.src_nic).mac;

                foreach (IdentityArc ia in identity_data.identity_arcs)
                {
                    if (ia.arc.peer_mac == peer_mac)
                    {
                        if (ia.peer_nodeid.equals(source_nodeid))
                        {
                            return ia;
                        }
                    }
                }

                return null;
            }
            else if (rpc_caller is DatagramCallerInfo)
            {
                DatagramCallerInfo caller_info = (DatagramCallerInfo)rpc_caller;

                // in this test we have only IdentityAwareSourceID and IdentityAwareBroadcastID
                if (! (caller_info.source_id is IdentityAwareSourceID)) abort_tasklet(@"Bad caller_info.source_id");
                IdentityAwareSourceID _source_id = (IdentityAwareSourceID)caller_info.source_id;
                NodeID source_nodeid = _source_id.id;
                if (! (caller_info.src_nic is NeighbourSrcNic)) abort_tasklet(@"Bad caller_info.src_nic");
                string peer_mac = ((NeighbourSrcNic)caller_info.src_nic).mac;
                if (! (caller_info.listener is DatagramSystemListener)) abort_tasklet(@"Bad caller_info.listener");
                string caller_listen_pathname = ((DatagramSystemListener)caller_info.listener).listen_pathname;
                string my_dev = null;
                foreach (string dev in pseudonic_map.keys)
                {
                    if (pseudonic_map[dev].listen_pathname == caller_listen_pathname)
                    {
                        my_dev = dev;
                        break;
                    }
                }
                if (my_dev == null) abort_tasklet(@"Bad caller_info.listener.listen_pathname=$(caller_listen_pathname)");

                foreach (IdentityArc ia in identity_data.identity_arcs)
                {
                    if (ia.arc.peer_mac == peer_mac
                        && ia.arc.my_nic.dev == my_dev)
                    {
                        if (ia.peer_nodeid.equals(source_nodeid))
                        {
                            return ia;
                        }
                    }
                }

                return null;
            }
            else
            {
                error(@"Unexpected class $(rpc_caller.get_type().name())");
            }
        }

        private class ServerErrorHandler : Object, IErrorHandler
        {
            private string name;
            public ServerErrorHandler(string name)
            {
                this.name = name;
            }

            public void error_handler(Error e)
            {
                error(@"ServerErrorHandler '$(name)': $(e.message)");
            }
        }

        private class ServerDelegate : Object, IDelegate
        {
            public ServerDelegate(SkeletonFactory skeleton_factory)
            {
                this.skeleton_factory = skeleton_factory;
            }
            private SkeletonFactory skeleton_factory;

            public Gee.List<IAddressManagerSkeleton> get_addr_set(CallerInfo caller_info)
            {
                if (caller_info is StreamCallerInfo)
                {
                    StreamCallerInfo c = (StreamCallerInfo)caller_info;
                    var ret = new ArrayList<IAddressManagerSkeleton>();
                    IAddressManagerSkeleton? d = skeleton_factory.get_dispatcher(c);
                    if (d != null) ret.add(d);
                    return ret;
                }
                else if (caller_info is DatagramCallerInfo)
                {
                    DatagramCallerInfo c = (DatagramCallerInfo)caller_info;
                    return skeleton_factory.get_dispatcher_set(c);
                }
                else
                {
                    error(@"Unexpected class $(caller_info.get_type().name())");
                }
            }
        }

        /* A skeleton for the identity remotable methods
         */
        class IdentitySkeleton : Object, IAddressManagerSkeleton
        {
            public IdentitySkeleton(IdentityData identity_data)
            {
                this.identity_data = identity_data;
            }

            private weak IdentityData identity_data;

            public unowned INeighborhoodManagerSkeleton
            neighborhood_manager_getter()
            {
                warning("IdentitySkeleton.neighborhood_manager_getter: not for identity");
                tasklet.exit_tasklet(null);
            }

            protected unowned IIdentityManagerSkeleton
            identity_manager_getter()
            {
                warning("IdentitySkeleton.identity_manager_getter: not for identity");
                tasklet.exit_tasklet(null);
            }

            public unowned IQspnManagerSkeleton
            qspn_manager_getter()
            {
                // member qspn_mgr of identity_data is QspnManager, which is a IQspnManagerSkeleton
                if (identity_data.qspn_mgr == null)
                {
                    print(@"IdentitySkeleton.qspn_manager_getter: id $(identity_data.nodeid.id) has qspn_mgr NULL. Might be too early, wait a bit.\n");
                    bool once_more = true; int wait_next = 5;
                    while (once_more)
                    {
                        once_more = false;
                        if (identity_data.qspn_mgr == null)
                        {
                            //  let's wait a bit and try again a few times.
                            if (wait_next < 3000) {
                                wait_next = wait_next * 10; tasklet.ms_wait(wait_next); once_more = true;
                            }
                        }
                        else
                        {
                            print(@"IdentitySkeleton.qspn_manager_getter: id $(identity_data.nodeid.id) now has qspn_mgr valid.\n");
                        }
                    }
                }
                if (identity_data.qspn_mgr == null)
                {
                    print(@"IdentitySkeleton.qspn_manager_getter: id $(identity_data.nodeid.id) has qspn_mgr NULL yet. Might be too late, abort responding.\n");
                    tasklet.exit_tasklet(null);
                }
                return identity_data.qspn_mgr;
            }

            public unowned IPeersManagerSkeleton
            peers_manager_getter()
            {
                error("not in this test");
            }

            public unowned ICoordinatorManagerSkeleton
            coordinator_manager_getter()
            {
                error("not in this test");
            }

            public unowned IHookingManagerSkeleton
            hooking_manager_getter()
            {
                error("not in this test");
            }

            /* TODO in ntkdrpc
            public unowned IAndnaManagerSkeleton
            andna_manager_getter()
            {
                error("not in this test");
            }
            */
        }
    }
}