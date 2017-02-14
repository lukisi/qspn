/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace Testbed
{
    string type_to_name(Type type)
    {
        return type.name();
    }

    Type name_to_type(string typename)
    {
        return Type.from_name(typename);
    }

    string json_string_from_object(Object obj, bool pretty=true)
    {
        Json.Node n = Json.gobject_serialize(obj);
        Json.Generator g = new Json.Generator();
        g.root = n;
        g.pretty = pretty;
        string ret = g.to_data(null);
        return ret;
    }

    Object json_object_from_string(string s, Type type)
    {
        Json.Parser p = new Json.Parser();
        try {
            assert(p.load_from_data(s));
        } catch (Error e) {print(@"$(e.message)\n");print(@"$(s)\n");error("");}
        Object ret = Json.gobject_deserialize(type, p.get_root());
        return ret;
    }

    Object dup_object(Object obj)
    {
        Type type = obj.get_type();
        string s = json_string_from_object(obj);
        return json_object_from_string(s, type);
    }

    string get_time_now(DateTime? _now=null)
    {
        DateTime now = _now == null ? new DateTime.now_local() : _now;
        int now_msec = now.get_microsecond() / 1000;
        if (now_msec < 10) return @"$(now.format("%FT%H:%M:%S")).00$(now_msec)";
        if (now_msec < 100) return @"$(now.format("%FT%H:%M:%S")).0$(now_msec)";
        return @"$(now.format("%FT%H:%M:%S")).$(now_msec)";
    }

    string naddr_repr(Naddr my_naddr)
    {
        int levels = my_naddr.i_qspn_get_levels();

        string my_naddr_str = "";
        string sep = "";
        for (int i = 0; i < levels; i++)
        {
            my_naddr_str = @"$(my_naddr.i_qspn_get_pos(i))$(sep)$(my_naddr_str)";
            sep = ":";
        }
        return my_naddr_str;
    }

    string fp_elderships_repr(Fingerprint my_fp)
    {
        string my_elderships_str = "";
        string sep = "";
        for (int i = 0; i < my_fp.elderships.size; i++)
        {
            my_elderships_str = @"$(my_fp.elderships[i])$(sep)$(my_elderships_str)";
            sep = ":";
        }
        return my_elderships_str;
    }

    string fp_elderships_seed_repr(Fingerprint my_fp)
    {
        string my_elderships_seed_str = "";
        string sep = "";
        for (int i = 0; i < my_fp.elderships_seed.size; i++)
        {
            my_elderships_seed_str = @"$(my_fp.elderships_seed[i])$(sep)$(my_elderships_seed_str)";
            sep = ":";
        }
        return my_elderships_seed_str;
    }

    void compute_topology(string topology, out ArrayList<int> _gsizes, out int levels)
    {
        _gsizes = new ArrayList<int>();
        foreach (string s_piece in topology.split("."))
        {
            int gsize = int.parse(s_piece);
            if (gsize < 2) error(@"Bad gsize $(gsize).");
            _gsizes.insert(0, gsize);
        }
        levels = _gsizes.size;
    }

    void compute_naddr(string naddr, ArrayList<int> _gsizes, out Naddr my_naddr)
    {
        ArrayList<int> _naddr = new ArrayList<int>();
        foreach (string s_piece in naddr.split(".")) _naddr.insert(0, int.parse(s_piece));
        my_naddr = new Naddr(_naddr.to_array(), _gsizes.to_array());
    }

    void compute_fp0_first_node(int64 id, int levels, out Fingerprint my_fp)
    {
        string elderships = "0";
        for (int i = 1; i < levels; i++) elderships += ".0";
        compute_fp0(id, elderships, out my_fp);
    }

    void compute_fp0(int64 id, string elderships, out Fingerprint my_fp)
    {
        ArrayList<int> _elderships = new ArrayList<int>();
        foreach (string s_piece in elderships.split(".")) _elderships.insert(0, int.parse(s_piece));
        my_fp = new Fingerprint(_elderships.to_array(), id);
    }

    const int max_paths = 5;
    const double max_common_hops_ratio = 0.6;
    const int arc_timeout = 10000;
    ITasklet tasklet;

    class IdentityData : Object
    {
        public IdentityData(int id) {
            nodeid = new NodeID(id);
        }
        public NodeID nodeid;
        public Naddr my_naddr;
        public Fingerprint my_fp;
        public QspnStubFactory stub_factory;
        public QspnManager qspn_manager;
        public int local_identity_index;
    }

    class QspnStubFactory : Object, IQspnStubFactory
    {
        public QspnStubFactory(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        private IChannel? expected_send_etp = null;
        public void expect_send_etp(int timeout_msec, out IQspnEtpMessage etp, out bool is_full, out ArrayList<NodeID> destid_set)
        {
            assert(expected_send_etp == null);
            expected_send_etp = tasklet.get_channel();
            try {
                Value v0 = expected_send_etp.recv_with_timeout(timeout_msec);
                //assert(v0 is IQspnEtpMessage);
                etp = (IQspnEtpMessage)v0;
            } catch (ChannelError.TIMEOUT e) {
                assert_not_reached();
            } catch (ChannelError e) {
                assert_not_reached();
            }
            try {
                Value v1 = expected_send_etp.recv_with_timeout(2);
                //assert(v1 is bool);
                is_full = (bool)v1;
            } catch (ChannelError.TIMEOUT e) {
                assert_not_reached();
            } catch (ChannelError e) {
                assert_not_reached();
            }
            try {
                Value v2 = expected_send_etp.recv_with_timeout(2);
                //assert(v2 is ArrayList<NodeID>);
                destid_set = (ArrayList<NodeID>)v2;
            } catch (ChannelError.TIMEOUT e) {
                assert_not_reached();
            } catch (ChannelError e) {
                assert_not_reached();
            }
            expected_send_etp = null;
        }

        private IChannel? expected_get_full_etp = null;
        public void expect_get_full_etp(int timeout_msec, out IQspnAddress requesting_address, out IChannel expected_answer, out ArrayList<NodeID> destid_set)
        {
            assert(expected_get_full_etp == null);
            expected_get_full_etp = tasklet.get_channel();
            try {
                Value v0 = expected_get_full_etp.recv_with_timeout(timeout_msec);
                //assert(v0 is IQspnAddress);
                requesting_address = (IQspnAddress)v0;
            } catch (ChannelError.TIMEOUT e) {
                assert_not_reached();
            } catch (ChannelError e) {
                assert_not_reached();
            }
            try {
                Value v1 = expected_get_full_etp.recv_with_timeout(2);
                //assert(v1 is IChannel);
                expected_answer = (IChannel)v1;
            } catch (ChannelError.TIMEOUT e) {
                assert_not_reached();
            } catch (ChannelError e) {
                assert_not_reached();
            }
            try {
                Value v2 = expected_get_full_etp.recv_with_timeout(2);
                //assert(v2 is ArrayList<NodeID>);
                destid_set = (ArrayList<NodeID>)v2;
            } catch (ChannelError.TIMEOUT e) {
                assert_not_reached();
            } catch (ChannelError e) {
                assert_not_reached();
            }
            expected_get_full_etp = null;
        }

        /* This "holder" class is needed because the QspnManagerRemote class provided by
         * the ZCD framework is owned (and tied to) by the AddressManagerXxxxRootStub.
         */
        private class QspnManagerStubHolder : Object, IQspnManagerStub
        {
            public QspnManagerStubHolder(QspnStubFactory factory, ArrayList<NodeID> destid_set, IdentityData identity_data)
            {
                this.destid_set = destid_set;
                string to_set = ""; foreach (NodeID i in destid_set) to_set += @"$(i.id) ";
                msg_hdr = @"RPC from $(factory.identity_data.nodeid.id) to {$(to_set)}";
                this.identity_data = identity_data;
                this.factory = factory;
            }
            private ArrayList<NodeID> destid_set;
            private string msg_hdr;
            private weak IdentityData identity_data;
            private QspnStubFactory factory;

            public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address)
            throws QspnNotAcceptedError, QspnBootstrapInProgressError, StubError, DeserializeError
            {
                if (factory.expected_get_full_etp != null) {
                    factory.expected_get_full_etp.send_async(requesting_address);
                    IChannel expected_answer = tasklet.get_channel();
                    factory.expected_get_full_etp.send_async(expected_answer);
                    factory.expected_get_full_etp.send_async(destid_set);
                    // handle cases of return and of exceptions
                    string ret_type = (string)expected_answer.recv();
                    if (ret_type == "OK") return (IQspnEtpMessage)expected_answer.recv();
                    else if (ret_type == "QspnBootstrapInProgressError") throw new QspnBootstrapInProgressError.GENERIC("");
                    else assert_not_reached();
                }
                string call_id = @"$(get_time_now())";
                print(@"$(call_id): Identity #$(identity_data.local_identity_index): calling RPC get_full_etp: $(msg_hdr).\n");
                print(@"   requesting_address=$(naddr_repr((Naddr)requesting_address)).\n");

                error("TODO wait for an answer from some channel.\n");
            }

            public void got_destroy()
            throws StubError, DeserializeError
            {
                print(@"$(get_time_now()): Identity #$(identity_data.local_identity_index): calling RPC got_destroy: $(msg_hdr).\n");

                error("TODO wait for an answer from some channel.\n");
            }

            public void got_prepare_destroy()
            throws StubError, DeserializeError
            {
                print(@"$(get_time_now()): Identity #$(identity_data.local_identity_index): calling RPC got_prepare_destroy: $(msg_hdr).\n");

                error("TODO wait for an answer from some channel.\n");
            }

            public void send_etp(IQspnEtpMessage etp, bool is_full)
            throws QspnNotAcceptedError, StubError, DeserializeError
            {
                if (factory.expected_send_etp != null) {
                    factory.expected_send_etp.send_async(etp);
                    factory.expected_send_etp.send_async(is_full);
                    factory.expected_send_etp.send_async(destid_set);
                    return;
                }
                string call_id = @"$(get_time_now())";
                print(@"$(call_id): Identity #$(identity_data.local_identity_index): calling RPC send_etp: $(msg_hdr).\n");
                string typename = type_to_name(etp.get_type());
                print(@"   $(typename) etp=$(json_string_from_object(etp)).\n");
                print(@"   is_full=$(is_full).\n");

                error("TODO wait for an answer from some channel.\n");
            }
        }

        /* This "void" class is needed for broadcast without arcs.
         */
        private class QspnManagerStubVoid : Object, IQspnManagerStub
        {
            public QspnManagerStubVoid(QspnStubFactory factory, IdentityData identity_data)
            {
                this.identity_data = identity_data;
                this.factory = factory;
            }
            private weak IdentityData identity_data;
            private QspnStubFactory factory;

            public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address)
            throws QspnNotAcceptedError, QspnBootstrapInProgressError, StubError, DeserializeError
            {
                assert_not_reached();
            }

            public void got_destroy()
            throws StubError, DeserializeError
            {
                print(@"$(get_time_now()): Identity #$(identity_data.local_identity_index): would call RPC got_destroy, but have no (other) arcs.\n");
            }

            public void got_prepare_destroy()
            throws StubError, DeserializeError
            {
                print(@"$(get_time_now()): Identity #$(identity_data.local_identity_index): would call RPC got_prepare_destroy, but have no (other) arcs.\n");
            }

            public void send_etp(IQspnEtpMessage etp, bool is_full)
            throws QspnNotAcceptedError, StubError, DeserializeError
            {
                if (factory.expected_send_etp != null) {
                    factory.expected_send_etp.send_async(etp);
                    factory.expected_send_etp.send_async(is_full);
                    ArrayList<NodeID> destid_set = new ArrayList<NodeID>((a, b) => a.equals(b));
                    factory.expected_send_etp.send_async(destid_set);
                    return;
                }
                print(@"$(get_time_now()): Identity #$(identity_data.local_identity_index): would call RPC send_etp, but have no (other) arcs.\n");
                string typename = type_to_name(etp.get_type());
                print(@"   $(typename) etp=$(json_string_from_object(etp)).\n");
                print(@"   is_full=$(is_full).\n");
            }
        }

        public IQspnManagerStub
        i_qspn_get_broadcast(
                             Gee.List<IQspnArc> arcs,
                             IQspnMissingArcHandler? missing_handler=null
                             )
        {
            if(arcs.is_empty) return new QspnManagerStubVoid(this, identity_data);
            ArrayList<NodeID> destid_set = new ArrayList<NodeID>((a, b) => a.equals(b));
            foreach (IQspnArc arc in arcs)
            {
                QspnArc _arc = (QspnArc)arc;
                destid_set.add(_arc.destid);
            }
            QspnManagerStubHolder ret = new QspnManagerStubHolder(this, destid_set, identity_data);
            return ret;
        }

        public IQspnManagerStub
        i_qspn_get_tcp(
                       IQspnArc arc,
                       bool wait_reply=true
                       )
        {
            QspnArc _arc = (QspnArc)arc;
            ArrayList<NodeID> destid_set = new ArrayList<NodeID>((a, b) => a.equals(b));
            destid_set.add(_arc.destid);
            QspnManagerStubHolder ret = new QspnManagerStubHolder(this, destid_set, identity_data);
            return ret;
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
        public QspnArc(NodeID sourceid, NodeID destid, Cost cost, string peer_mac)
        {
            this.sourceid = sourceid;
            this.destid = destid;
            this.cost = cost;
            this.peer_mac = peer_mac;
        }
        public NodeID sourceid;
        public NodeID destid;
        public Cost cost;
        public string peer_mac;

        public IQspnCost i_qspn_get_cost()
        {
            return cost;
        }

        public bool i_qspn_equals(IQspnArc other)
        {
            if (! (other is QspnArc)) return false;
            QspnArc _other = (QspnArc)other;
            return
                _other.sourceid.equals(sourceid) &&
                _other.destid.equals(destid);
        }

        public bool i_qspn_comes_from(CallerInfo rpc_caller)
        {
            if (rpc_caller is FakeCallerInfo)
            {
                FakeCallerInfo caller = (FakeCallerInfo)rpc_caller;
                return (this in caller.valid_set);
            }
            else if (rpc_caller is TcpclientCallerInfo)
            {
                error("not implemented yet");
            }
            else if (rpc_caller is BroadcastCallerInfo)
            {
                error("not implemented yet");
            }
            else if (rpc_caller is UnicastCallerInfo)
            {
                warning("QspnArc.i_qspn_comes_from: got a call in udp-unicast. Ignore it.");
                tasklet.exit_tasklet(null);
            }
            else
            {
                assert_not_reached();
            }
        }
    }

    class FakeCallerInfo : CallerInfo
    {
        public ArrayList<QspnArc> valid_set;
    }

    void main(string[] args)
    {
        if (args.length == 2)
        {
            if (args[1] == "01") Testbed01.testbed_01();
            else if (args[1] == "02") Testbed02.testbed_02();
            else if (args[1] == "03") Testbed03.testbed_03();
            //else if (args[1] == "04") Testbed04.testbed_04();
            else error(@"testbed: bad number $(args[1])");
            return; //OK
        }
        error("testbed: usage: testbed <number>");
    }
}