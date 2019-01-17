using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    class QspnManagerStubHolder : Object, IQspnManagerStub
    {
        public QspnManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address)
        throws QspnNotAcceptedError, QspnBootstrapInProgressError, StubError, DeserializeError
        {
            return addr.qspn_manager.get_full_etp(requesting_address);
        }

        public void got_destroy()
        throws StubError, DeserializeError
        {
            addr.qspn_manager.got_destroy();
        }

        public void got_prepare_destroy()
        throws StubError, DeserializeError
        {
            addr.qspn_manager.got_prepare_destroy();
        }

        public void send_etp(IQspnEtpMessage etp, bool is_full)
        throws QspnNotAcceptedError, StubError, DeserializeError
        {
            addr.qspn_manager.send_etp(etp, is_full);
        }
    }

    class QspnManagerStubBroadcastHolder : Object, IQspnManagerStub
    {
        public QspnManagerStubBroadcastHolder(Gee.List<IAddressManagerStub> addr_list)
        {
            this.addr_list = addr_list;
        }
        private Gee.List<IAddressManagerStub> addr_list;

        public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address)
        throws QspnNotAcceptedError, QspnBootstrapInProgressError, StubError, DeserializeError
        {
            assert_not_reached();
        }

        public void got_destroy()
        throws StubError, DeserializeError
        {
            foreach (var addr in addr_list)
            addr.qspn_manager.got_destroy();
        }

        public void got_prepare_destroy()
        throws StubError, DeserializeError
        {
            foreach (var addr in addr_list)
            addr.qspn_manager.got_prepare_destroy();
        }

        public void send_etp(IQspnEtpMessage etp, bool is_full)
        throws QspnNotAcceptedError, StubError, DeserializeError
        {
            foreach (var addr in addr_list)
            addr.qspn_manager.send_etp(etp, is_full);
        }
    }

    class QspnManagerStubVoid : Object, IQspnManagerStub
    {
        public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address)
        throws QspnNotAcceptedError, QspnBootstrapInProgressError, StubError, DeserializeError
        {
            assert_not_reached();
        }

        public void got_destroy()
        throws StubError, DeserializeError
        {
        }

        public void got_prepare_destroy()
        throws StubError, DeserializeError
        {
        }

        public void send_etp(IQspnEtpMessage etp, bool is_full)
        throws QspnNotAcceptedError, StubError, DeserializeError
        {
        }
    }
}