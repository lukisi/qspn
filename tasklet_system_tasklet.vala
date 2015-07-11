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

using Tasklets;
using zcd;
using Netsukuku;
using Gee;

namespace MyTaskletSystem
{
    IZcdTasklet get_zcd()
    {
        return new MyZcdTaskletSystem.TaskletSystem();
    }

    INtkdTasklet get_ntkd()
    {
        return new MyNtkdTaskletSystem.TaskletSystem();
    }

    void init()
    {
        assert(Tasklet.init());
    }

    void kill()
    {
        assert(Tasklet.kill());
    }
}

namespace MyZcdTaskletSystem
{
    internal class TaskletSystem : Object, IZcdTasklet
    {
        private static int ind;
        private static HashMap<int,IZcdTaskletSpawnable> map;

        private void * real_func(MyHandle h)
        {
            void * ret = h.sp.func();
            map.unset(h.ind);
            return ret;
        }

        internal TaskletSystem()
        {
            ind = 0;
            map = new HashMap<int,IZcdTaskletSpawnable>();
        }

        public void schedule()
        {
            Tasklet.schedule();
        }

        public void ms_wait(int msec)
        {
            Tasklets.ms_wait(msec);
        }

        [NoReturn]
        public void exit_tasklet(void * ret)
        {
            Tasklet.exit_current_thread(ret);
            assert_not_reached();
        }

        public IZcdTaskletHandle spawn(IZcdTaskletSpawnable sp, bool joinable=false)
        {
            MyHandle h = new MyHandle();
            h.ind = ind;
            h.sp = sp;
            h.joinable = joinable;
            map[ind] = sp;
            ind++;
            h.t = Tasklet.tasklet_callback((_h) => {
                MyHandle t_h = (MyHandle)_h;
                real_func(t_h);
            }, h, null, null, null, joinable);
            return h;
        }

        public ZcdTaskletCommandResult exec_command(string cmdline) throws Error
        {
            ZcdTaskletCommandResult ret = new ZcdTaskletCommandResult();
            Tasklets.CommandResult res = Tasklet.exec_command(cmdline);
            ret.exit_status = res.exit_status;
            ret.stdout = res.cmdout;
            ret.stderr = res.cmderr;
            return ret;
        }

        public IZcdServerStreamSocket get_server_stream_socket(uint16 port, string? my_addr=null) throws Error
        {
            Tasklets.ServerStreamSocket s = new Tasklets.ServerStreamSocket(port, 5, my_addr);
            return new MyServerStreamSocket(s);
        }

        public IZcdConnectedStreamSocket get_client_stream_socket(string dest_addr, uint16 dest_port, string? my_addr=null) throws Error
        {
            Tasklets.ClientStreamSocket s = new Tasklets.ClientStreamSocket(my_addr);
            return new MyConnectedStreamSocket(s.socket_connect(dest_addr, dest_port));
        }

        public IZcdServerDatagramSocket get_server_datagram_socket(uint16 port, string dev) throws Error
        {
            Tasklets.ServerDatagramSocket s = new Tasklets.ServerDatagramSocket(port, null, dev);
            return new MyServerDatagramSocket(s);
        }

        public IZcdClientDatagramSocket get_client_datagram_socket(uint16 port, string dev) throws Error
        {
            return new MyClientDatagramSocket(new Tasklets.BroadcastClientDatagramSocket(dev, port));
        }

        public IZcdChannel get_channel()
        {
            return new MyChannel();
        }

        private class MyHandle : Object, IZcdTaskletHandle
        {
            public int ind;
            public IZcdTaskletSpawnable sp;
            public Tasklet t;
            public bool joinable;

            public bool is_running()
            {
                return map.has_key(ind);
            }

            public void kill()
            {
                t.abort();
            }

            public bool is_joinable()
            {
                return joinable;
            }

            public void * join()
            {
                if (!joinable) error("Tasklet not joinable");
                return t.join();
            }
        }

        private class MyServerStreamSocket : Object, IZcdServerStreamSocket
        {
            private Tasklets.ServerStreamSocket c;
            public MyServerStreamSocket(Tasklets.ServerStreamSocket c)
            {
                this.c = c;
            }

            public IZcdConnectedStreamSocket accept() throws Error
            {
                return new MyConnectedStreamSocket(c.accept());
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyConnectedStreamSocket : Object, IZcdConnectedStreamSocket
        {
            private Tasklets.IConnectedStreamSocket c;
            public MyConnectedStreamSocket(Tasklets.IConnectedStreamSocket c)
            {
                this.c = c;
            }

            public unowned string _peer_address_getter() {return c.peer_address;}
            public unowned string _my_address_getter() {return c.my_address;}

            public size_t recv(uint8* b, size_t maxlen) throws Error
            {
                return c.recv_new(b, maxlen);
            }

            public void send(uint8* b, size_t len) throws Error
            {
                c.send_new(b, len);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyServerDatagramSocket : Object, IZcdServerDatagramSocket
        {
            private Tasklets.ServerDatagramSocket c;
            public MyServerDatagramSocket(Tasklets.ServerDatagramSocket c)
            {
                this.c = c;
            }

            public size_t recvfrom(uint8* b, size_t maxlen, out string rmt_ip, out uint16 rmt_port) throws Error
            {
                return c.recvfrom_new(b, maxlen, out rmt_ip, out rmt_port);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyClientDatagramSocket : Object, IZcdClientDatagramSocket
        {
            private Tasklets.BroadcastClientDatagramSocket c;
            public MyClientDatagramSocket(Tasklets.BroadcastClientDatagramSocket c)
            {
                this.c = c;
            }

            public size_t sendto(uint8* b, size_t len) throws Error
            {
                return c.send_new(b, len);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyChannel : Object, IZcdChannel
        {
            private Tasklets.Channel ch;
            internal MyChannel()
            {
                ch = new Tasklets.Channel();
            }

            public void send(Value v)
            {
                ch.send(v);
            }

            public void send_async(Value v)
            {
                ch.send_async(v);
            }

            public int get_balance()
            {
                return ch.balance;
            }

            public Value recv()
            {
                return ch.recv();
            }

            public Value recv_with_timeout(int timeout_msec) throws ZcdChannelError.TIMEOUT
            {
                try {
                    return ch.recv_with_timeout(timeout_msec);
                } catch (Tasklets.ChannelError e) {
                    throw new ZcdChannelError.TIMEOUT(e.message);
                }
            }
        }
    }
}

namespace MyNtkdTaskletSystem
{
    internal class TaskletSystem : Object, INtkdTasklet
    {
        private static int ind;
        private static HashMap<int,INtkdTaskletSpawnable> map;

        private void * real_func(MyHandle h)
        {
            void * ret = h.sp.func();
            map.unset(h.ind);
            return ret;
        }

        internal TaskletSystem()
        {
            ind = 0;
            map = new HashMap<int,INtkdTaskletSpawnable>();
        }

        public void schedule()
        {
            Tasklet.schedule();
        }

        public void ms_wait(int msec)
        {
            Tasklets.ms_wait(msec);
        }

        [NoReturn]
        public void exit_tasklet(void * ret)
        {
            Tasklet.exit_current_thread(ret);
            assert_not_reached();
        }

        public INtkdTaskletHandle spawn(INtkdTaskletSpawnable sp, bool joinable=false)
        {
            MyHandle h = new MyHandle();
            h.ind = ind;
            h.sp = sp;
            h.joinable = joinable;
            map[ind] = sp;
            ind++;
            h.t = Tasklet.tasklet_callback((_h) => {
                MyHandle t_h = (MyHandle)_h;
                real_func(t_h);
            }, h, null, null, null, joinable);
            return h;
        }

        public NtkdTaskletCommandResult exec_command(string cmdline) throws Error
        {
            NtkdTaskletCommandResult ret = new NtkdTaskletCommandResult();
            Tasklets.CommandResult res = Tasklet.exec_command(cmdline);
            ret.exit_status = res.exit_status;
            ret.stdout = res.cmdout;
            ret.stderr = res.cmderr;
            return ret;
        }

        public INtkdServerStreamSocket get_server_stream_socket(uint16 port, string? my_addr=null) throws Error
        {
            Tasklets.ServerStreamSocket s = new Tasklets.ServerStreamSocket(port, 5, my_addr);
            return new MyServerStreamSocket(s);
        }

        public INtkdConnectedStreamSocket get_client_stream_socket(string dest_addr, uint16 dest_port, string? my_addr=null) throws Error
        {
            Tasklets.ClientStreamSocket s = new Tasklets.ClientStreamSocket(my_addr);
            return new MyConnectedStreamSocket(s.socket_connect(dest_addr, dest_port));
        }

        public INtkdServerDatagramSocket get_server_datagram_socket(uint16 port, string dev) throws Error
        {
            Tasklets.ServerDatagramSocket s = new Tasklets.ServerDatagramSocket(port, null, dev);
            return new MyServerDatagramSocket(s);
        }

        public INtkdClientDatagramSocket get_client_datagram_socket(uint16 port, string dev) throws Error
        {
            return new MyClientDatagramSocket(new Tasklets.BroadcastClientDatagramSocket(dev, port));
        }

        public INtkdChannel get_channel()
        {
            return new MyChannel();
        }

        private class MyHandle : Object, INtkdTaskletHandle
        {
            public int ind;
            public INtkdTaskletSpawnable sp;
            public Tasklet t;
            public bool joinable;

            public bool is_running()
            {
                return map.has_key(ind);
            }

            public void kill()
            {
                t.abort();
            }

            public bool is_joinable()
            {
                return joinable;
            }

            public void * join()
            {
                if (!joinable) error("Tasklet not joinable");
                return t.join();
            }
        }

        private class MyServerStreamSocket : Object, INtkdServerStreamSocket
        {
            private Tasklets.ServerStreamSocket c;
            public MyServerStreamSocket(Tasklets.ServerStreamSocket c)
            {
                this.c = c;
            }

            public INtkdConnectedStreamSocket accept() throws Error
            {
                return new MyConnectedStreamSocket(c.accept());
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyConnectedStreamSocket : Object, INtkdConnectedStreamSocket
        {
            private Tasklets.IConnectedStreamSocket c;
            public MyConnectedStreamSocket(Tasklets.IConnectedStreamSocket c)
            {
                this.c = c;
            }

            public unowned string _peer_address_getter() {return c.peer_address;}
            public unowned string _my_address_getter() {return c.my_address;}

            public size_t recv(uint8* b, size_t maxlen) throws Error
            {
                return c.recv_new(b, maxlen);
            }

            public void send(uint8* b, size_t len) throws Error
            {
                c.send_new(b, len);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyServerDatagramSocket : Object, INtkdServerDatagramSocket
        {
            private Tasklets.ServerDatagramSocket c;
            public MyServerDatagramSocket(Tasklets.ServerDatagramSocket c)
            {
                this.c = c;
            }

            public size_t recvfrom(uint8* b, size_t maxlen, out string rmt_ip, out uint16 rmt_port) throws Error
            {
                return c.recvfrom_new(b, maxlen, out rmt_ip, out rmt_port);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyClientDatagramSocket : Object, INtkdClientDatagramSocket
        {
            private Tasklets.BroadcastClientDatagramSocket c;
            public MyClientDatagramSocket(Tasklets.BroadcastClientDatagramSocket c)
            {
                this.c = c;
            }

            public size_t sendto(uint8* b, size_t len) throws Error
            {
                return c.send_new(b, len);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyChannel : Object, INtkdChannel
        {
            private Tasklets.Channel ch;
            internal MyChannel()
            {
                ch = new Tasklets.Channel();
            }

            public void send(Value v)
            {
                ch.send(v);
            }

            public void send_async(Value v)
            {
                ch.send_async(v);
            }

            public int get_balance()
            {
                return ch.balance;
            }

            public Value recv()
            {
                return ch.recv();
            }

            public Value recv_with_timeout(int timeout_msec) throws NtkdChannelError.TIMEOUT
            {
                try {
                    return ch.recv_with_timeout(timeout_msec);
                } catch (Tasklets.ChannelError e) {
                    throw new NtkdChannelError.TIMEOUT(e.message);
                }
            }
        }
    }
}

