using Netsukuku;
using Netsukuku.ModRpc;
using Gee;

namespace Netsukuku
{
    public interface IQspnNaddr : Object
    {
    }
    public class MyNaddr : Object, IQspnNaddr
    {
        public int g1 {get; set;}
        public int g0 {get; set;}
    }

    public interface IQspnCost : Object
    {
    }
    public class MyCost : Object, IQspnCost
    {
        public int c {get; set;}
    }

    public interface IQspnFingerprint : Object
    {
    }
    public class MyFingerprint : Object, IQspnFingerprint
    {
        public int f {get; set;}
    }

    public class HCoord : Object
    {
        public int lvl {get; set;}
        public int pos {get; set;}
    }

    public class EtpPath : Object
    {
    }

    namespace ModRpc
    {
    }
}

void main() {
    try {
        bool first = true;
        while(first) // while(true)   - to check memory growth
        {
            var addr0 = new MyNaddr();
            addr0.g0 = 12;
            addr0.g1 = 23;
            Json.Node x = serialize_i_qspn_naddr(addr0);
            if (first) print("serialized.\n");
            IQspnNaddr addr1 = deserialize_i_qspn_naddr(x);
            if (first) print("deserialized.\n");
            assert(addr1 is MyNaddr);
            MyNaddr _addr1 = (MyNaddr)addr1;
            if (first) print(@"($(_addr1.g0).$(_addr1.g1))\n");
            Json.Node x2 = serialize_i_qspn_naddr(addr0);
            if (first) print("serialized.\n");
            IQspnNaddr addr2 = deserialize_i_qspn_naddr(x2);
            if (first) print("deserialized.\n");
            assert(addr2 is MyNaddr);
            MyNaddr _addr2 = (MyNaddr)addr1;
            if (first) print(@"($(_addr2.g0).$(_addr2.g1))\n");
            IQspnNaddr addr3 = deserialize_i_qspn_naddr(x2);
            if (first) print("deserialized again.\n");
            assert(addr3 is MyNaddr);
            MyNaddr _addr3 = (MyNaddr)addr1;
            if (first) print(@"($(_addr3.g0).$(_addr3.g1))\n");
            Thread.usleep(20000);
            first = false;
        }
        var cost = new MyCost();
        cost.c = 123;
        var fp = new MyFingerprint();
        fp.f = 876;
        Json.Node c0 = serialize_i_qspn_cost(cost);
        Json.Node f0 = serialize_i_qspn_fingerprint(fp);
        IQspnCost cc = deserialize_i_qspn_cost(c0);
        IQspnFingerprint ff = deserialize_i_qspn_fingerprint(f0);
        print(@"$((cc as MyCost).c), $((ff as MyFingerprint).f)\n");

        first = true;
        while(first) // while(true)   - to check memory growth
        {
            var lst = new ArrayList<IQspnFingerprint>();
            MyFingerprint lst_el_0 = new MyFingerprint();
            lst_el_0.f = 123;
            lst.add(lst_el_0);
            MyFingerprint lst_el_1 = new MyFingerprint();
            lst_el_1.f = 124;
            lst.add(lst_el_1);
            MyFingerprint lst_el_2 = new MyFingerprint();
            lst_el_2.f = 125;
            lst.add(lst_el_2);
            Json.Node lf = serialize_list_i_qspn_fingerprint(lst);
            if (first) print("lst serialized.\n");
            var lst2 = deserialize_list_i_qspn_fingerprint(lf);
            if (first) print("lst deserialized.\n");
            foreach (IQspnFingerprint el in lst2)
            {
                if (first) print(@"$((el as MyFingerprint).f)\n");
            }
            Thread.usleep(20000);
            first = false;
        }

        // int
        int i = 0;
        Json.Node n_i = serialize_int(i);
        int i2 = deserialize_int(n_i);
        assert(i == i2);

        // list hcoord
        Gee.List<HCoord> lh = new ArrayList<HCoord>();
        HCoord el1 = new HCoord(); el1.lvl = 12; el1.pos = 23; lh.add(el1);
        HCoord el2 = new HCoord(); el2.lvl = 1; el2.pos = 2; lh.add(el2);
        Json.Node n_lh = serialize_list_hcoord(lh);
        Gee.List<HCoord> lh2 = deserialize_list_hcoord(n_lh);
        assert(lh.size == lh2.size);
        for (int j = 0; j < lh.size; j++) assert(lh[j].pos == lh2[j].pos);

        // list etppath
        Gee.List<EtpPath> le = new ArrayList<EtpPath>();
        EtpPath el3 = new EtpPath(); le.add(el3);
        EtpPath el4 = new EtpPath(); le.add(el4);
        Json.Node n_le = serialize_list_etp_path(le);
        Gee.List<EtpPath> le2 = deserialize_list_etp_path(n_le);
        assert(le.size == le2.size);

        // list int
        Gee.List<int> li = new ArrayList<int>.wrap({1,2,3});
        Json.Node n_li = serialize_list_int(li);
        Gee.List<int> li2 = deserialize_list_int(n_li);
        assert(li.size == li2.size);
        for (int j = 0; j < li.size; j++) assert(li[j] == li2[j]);

        // list bool
        Gee.List<bool> lb = new ArrayList<bool>.wrap({true,false,false});
        Json.Node n_lb = serialize_list_bool(lb);
        Gee.List<bool> lb2 = deserialize_list_bool(n_lb);
        assert(lb.size == lb2.size);
        for (int j = 0; j < lb.size; j++) assert(lb[j] == lb2[j]);

    } catch (HelperDeserializeError e) {assert_not_reached();}
}

