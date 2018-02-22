using Gee;

namespace Netsukuku.Qspn
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
        public bool equals(HCoord o)
        {
            return o.lvl == lvl && o.pos == pos;
        }
        public int lvl {get; set;}
        public int pos {get; set;}
    }

    public interface IQspnEtpMessage : Object
    {
    }

    string json_string_object(Object obj)
    {
        Json.Node n = Json.gobject_serialize(obj);
        Json.Generator g = new Json.Generator();
        g.root = n;
        g.pretty = true;
        string ret = g.to_data(null);
        return ret;
    }

    void print_object(Object obj)
    {
        print(@"$(obj.get_type().name())\n");
        string t = json_string_object(obj);
        print(@"$(t)\n");
    }

    class QspnTester : Object
    {
        public void set_up ()
        {
        }

        public void tear_down ()
        {
        }

        public void test_etp()
        {
            EtpMessage m0;
            {
                Json.Node node;
                {
                    EtpMessage m = new EtpMessage();
                    // TODO node = Json.gobject_serialize(m);
                }
                // TODO m0 = (EtpMessage)Json.gobject_deserialize(typeof(EtpMessage), node);
            }
            // TODO assert(m0.reserve_request_id == 1234);
        }

        public static int main(string[] args)
        {
            GLib.Test.init(ref args);
            GLib.Test.add_func ("/Serializables/EtpMessage", () => {
                var x = new QspnTester();
                x.set_up();
                x.test_etp();
                x.tear_down();
            });
            GLib.Test.run();
            return 0;
        }
    }
}
