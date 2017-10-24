/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

namespace Testbed
{
    public class Naddr : Object, IQspnAddress, IQspnNaddr, IQspnMyNaddr, Json.Serializable
    {
        public ArrayList<int> pos {get; set;}
        public ArrayList<int> sizes {get; set;}
        public Naddr(int[] pos, int[] sizes)
        {
            assert(sizes.length == pos.length);
            this.pos = new ArrayList<int>();
            this.pos.add_all_array(pos);
            this.sizes = new ArrayList<int>();
            this.sizes.add_all_array(sizes);
        }

        public int get_real_up_to()
        {
            int levels = sizes.size;
            int real_up_to = -1;
            while (real_up_to < levels-1)
            {
                if (pos[real_up_to+1] >= sizes[real_up_to+1]) break;
                real_up_to++;
            }
            return real_up_to;
        }

        public int get_virtual_up_to()
        {
            int levels = sizes.size;
            int virtual_up_to = levels-1;
            while (virtual_up_to >= 0)
            {
                if (pos[virtual_up_to] >= sizes[virtual_up_to]) break;
                virtual_up_to--;
            }
            return virtual_up_to;
        }

        public bool is_real_from_to(int from, int to)
        {
            for (int i = from; i <= to; i++)
                if (pos[i] >= sizes[i]) return false;
            return true;
        }

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "pos":
            case "sizes":
                try {
                    ArrayList<int> ret = new ArrayList<int>();
                    ret.add_all(deserialize_list_int(property_node));
                    @value = ret;
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec? find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "pos":
            case "sizes":
                return serialize_list_int((Gee.List<int>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }

        public int i_qspn_get_levels()
        {
            return sizes.size;
        }

        public int i_qspn_get_gsize(int level)
        {
            return sizes[level];
        }

        public int i_qspn_get_pos(int level)
        {
            return pos[level];
        }

        public HCoord i_qspn_get_coord_by_address(IQspnNaddr dest)
        {
            int l = pos.size-1;
            while (l >= 0)
            {
                if (pos[l] != dest.i_qspn_get_pos(l)) return new HCoord(l, dest.i_qspn_get_pos(l));
                l--;
            }
            // same naddr: error
            return new HCoord(-1, -1);
        }

        public bool equals(Naddr o)
        {
            if (pos.size != o.pos.size) return false;
            for (int i = 0; i < pos.size; i++)
            {
                if (pos[i] != o.pos[i]) return false;
                if (sizes[i] != o.sizes[i]) return false;
            }
            return true;
        }
    }

    public class Fingerprint : Object, IQspnFingerprint, Json.Serializable
    {
        public int64 id {get; set;}
        public int level {get; set;}
        // elderships has n items, where level + n = levels of the network.
        public ArrayList<int> elderships {get; set;}
        public ArrayList<int> elderships_seed {get; set;}
        public Fingerprint(int[] elderships, int64 id=-1)
        {
            if (id == -1)
            {
                this.id = Random.int_range(0, 1000000);
                this.id *= 1000000;
                this.id = Random.int_range(0, 1000000);
            }
            else
                this.id = id;
            level = 0;
            this.elderships = new ArrayList<int>();
            this.elderships.add_all_array(elderships);
            elderships_seed = new ArrayList<int>();
        }

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "id":
                try {
                    @value = deserialize_int64(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "level":
                try {
                    @value = deserialize_int(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "elderships_seed":
            case "elderships-seed":
            case "elderships":
                try {
                    ArrayList<int> ret = new ArrayList<int>();
                    ret.add_all(deserialize_list_int(property_node));
                    @value = ret;
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec? find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "id":
                return serialize_int64((int64)@value);
            case "level":
                return serialize_int((int)@value);
            case "elderships_seed":
            case "elderships-seed":
            case "elderships":
                return serialize_list_int((Gee.List<int>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }

        private Fingerprint.empty() {}

        public bool i_qspn_equals(IQspnFingerprint other)
        {
            assert(other is Fingerprint);
            Fingerprint _other = (Fingerprint)other;

            /* The level of the destination must be the same (and also the pos)
             */
            assert(_other.level == level);

            if (_other.id != id) return false;
            return true;
        }

        private bool elder(IQspnFingerprint other)
        {
            /* The class uses this method to compare fingerprints referred to
             * two distinct destination in the same upper g-node.
             */

            assert(other is Fingerprint);
            Fingerprint _other = (Fingerprint)other;

            /* The level of the destination must be the same (but not the pos)
             */
            assert(_other.level == level);

            /* The correct behaviour assures that distinct g-nodes in the same upper
             * g-node will never get the same eldership at lower level. We should (somehow) assure that a
             * fingerprint maliciously crafted will be spotted and dropped.
             */
            assert(_other.elderships[0] != elderships[0]);

            if (_other.elderships[0] < elderships[0]) return false; // other is elder
            return true;
        }

        public bool i_qspn_elder_seed(IQspnFingerprint other)
        {
            /* The program should use this method to compare fingerprints referred to
             * one destination. And after that i_qspn_equals reveals that they are not
             * equal. And only for levels greater than 0.
             */

            assert(other is Fingerprint);
            Fingerprint _other = other as Fingerprint;

            /* The level of the destination must be the same (and also the pos)
             */
            assert(_other.level == level);
            assert(level > 0);

            /* The compare must be made when we know that the id is not the same
             */
            assert(_other.id != id);

            /* The correct behaviour assures that different id in the same g-node will
             * never get the same elderships_seed. We should (somehow) assure that a
             * fingerprint maliciously crafted will be spotted and dropped.
             */
            assert(_other.elderships_seed.size == elderships_seed.size);
            for (int i = 0; i < elderships_seed.size; i++)
            {
                if (_other.elderships_seed[i] < elderships_seed[i]) return false; // other is elder
                if (_other.elderships_seed[i] > elderships_seed[i]) return true; // this is elder
            }
            assert_not_reached();
        }

        public int i_qspn_get_level()
        {
            return level;
        }

        public IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingerprints)
        {
            // given that:
            //  levels = level + elderships.size
            // do not construct for level = levels+1
            assert(elderships.size > 0);
            Fingerprint ret = new Fingerprint.empty();
            ret.level = level + 1;
            ret.elderships = new ArrayList<int>();
            for (int i = 1; i < elderships.size; i++)
                ret.elderships.add(elderships[i]);
            // start comparing
            Fingerprint eldest_f = this;
            foreach (IQspnFingerprint f in fingerprints)
            {
                assert(f is Fingerprint);
                Fingerprint _f = (Fingerprint)f;
                if (_f.elder(eldest_f)) eldest_f = _f;
            }
            ret.elderships_seed = new ArrayList<int>();
            ret.elderships_seed.add(eldest_f.elderships[0]);
            ret.elderships_seed.add_all(eldest_f.elderships_seed);
            ret.id = eldest_f.id;
            return ret;
        }
    }

    public class Cost : Object, IQspnCost
    {
        public int64 usec_rtt {get; set;}

        public Cost(int64 usec_rtt)
        {
            this.usec_rtt = usec_rtt;
        }

        public int i_qspn_compare_to(IQspnCost other)
        {
            if (other.i_qspn_is_dead()) return -1;
            if (other.i_qspn_is_null()) return 1;
            assert(other is Cost);
            Cost o = (Cost)other;
            if (usec_rtt > o.usec_rtt) return 1;
            if (usec_rtt < o.usec_rtt) return -1;
            return 0;
        }

        public IQspnCost i_qspn_add_segment(IQspnCost other)
        {
            if (other.i_qspn_is_dead()) return other;
            if (other.i_qspn_is_null()) return this;
            assert(other is Cost);
            Cost o = (Cost)other;
            return new Cost(usec_rtt + o.usec_rtt);
        }

        public bool i_qspn_important_variation(IQspnCost new_cost)
        {
            if (new_cost.i_qspn_is_dead()) return true;
            if (new_cost.i_qspn_is_null()) return true;
            assert(new_cost is Cost);
            Cost o = (Cost)new_cost;
            int64 upper_threshold = (int64)(o.usec_rtt * 0.3);
            if (o.usec_rtt > usec_rtt + upper_threshold) return true;
            int64 lower_threshold = (int64)(usec_rtt * 0.3);
            if (o.usec_rtt < usec_rtt - lower_threshold) return true;
            return false;
        }

        public virtual bool i_qspn_is_dead()
        {
            return false;
        }

        public virtual bool i_qspn_is_null()
        {
            return false;
        }
    }
}

