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
using Netsukuku;
using DiscoverPathsInternals;

public class FakeGenericNaddr : Object, IQspnAddress, IQspnNaddr, IQspnMyNaddr, IQspnPartialNaddr, Json.Serializable
{
    public ArrayList<int> pos {get; set;}
    public ArrayList<int> sizes {get; set;}
    public FakeGenericNaddr(int[] pos, int[] sizes)
    {
        assert(sizes.length == pos.length);
        this.pos = new ArrayList<int>();
        this.pos.add_all_array(pos);
        this.sizes = new ArrayList<int>();
        this.sizes.add_all_array(sizes);
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

    public unowned GLib.ParamSpec find_property
    (string name)
    {
        return ((ObjectClass)typeof(FakeGenericNaddr).class_ref()).find_property(name);
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

    public int i_qspn_get_level_of_gnode()
    {
        int l = 0;
        while (l < pos.size)
        {
            if (pos[l] >= 0) return l;
            l++;
        }
        return pos.size; // the whole network
    }

    public IQspnPartialNaddr i_qspn_get_address_by_coord(HCoord dest)
    {
        int[] newpos = new int[pos.size];
        for (int i = 0; i < dest.lvl; i++) newpos[i] = -1;
        for (int i = dest.lvl; i < pos.size; i++) newpos[i] = pos[i];
        newpos[dest.lvl] = dest.pos;
        return new FakeGenericNaddr(newpos, sizes.to_array());
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

    public string to_string()
    {
        int l_o_g = i_qspn_get_level_of_gnode();
        string type = "N";
        if (l_o_g > 0) type = "G";
        string sep = "";
        string positions = "";
        for (int l = l_o_g; l < i_qspn_get_levels(); l++)
        {
            int pos = i_qspn_get_pos(l);
            positions += @"$(sep)$(pos)";
            sep = ", ";
        }
        return @"$(type)[$(positions)]";
    }
}

public class FakeFingerprint : Object, IQspnFingerprint, Json.Serializable
{
    public int64 id {get; set;}
    public int level {get; set;}
    // elderships has n items, where level + n = levels of the network.
    public ArrayList<int> elderships {get; set;}
    public FakeFingerprint(int[] elderships)
    {
        this.id = Random.int_range(0, 1000000);
        this.level = 0;
        this.elderships = new ArrayList<int>();
        this.elderships.add_all_array(elderships);
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

    public unowned GLib.ParamSpec find_property
    (string name)
    {
        return ((ObjectClass)typeof(FakeFingerprint).class_ref()).find_property(name);
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
        case "elderships":
            return serialize_list_int((Gee.List<int>)@value);
        default:
            error(@"wrong param $(property_name)");
        }
    }

    private FakeFingerprint.empty() {}

    public bool i_qspn_equals(IQspnFingerprint other)
    {
        if (! (other is FakeFingerprint)) return false;
        FakeFingerprint _other = other as FakeFingerprint;
        if (_other.id != id) return false;
        return true;
    }

    public bool i_qspn_elder(IQspnFingerprint other)
    {
        assert(other is FakeFingerprint);
        FakeFingerprint _other = other as FakeFingerprint;
        if (_other.elderships[0] < elderships[0]) return false; // other is elder
        return true;
    }

    public int i_qspn_get_level()
    {
        return level;
    }

    public IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingers)
    {
        // given that:
        //  levels = level + elderships.size
        // do not construct for level = levels+1
        assert(elderships.size > 0);
        FakeFingerprint ret = new FakeFingerprint.empty();
        ret.level = level + 1;
        ret.id = id;
        ret.elderships = new ArrayList<int>();
        for (int i = 1; i < elderships.size; i++)
            ret.elderships.add(elderships[i]);
        int cur_eldership = elderships[0];
        // start comparing
        foreach (IQspnFingerprint f in fingers)
        {
            assert(f is FakeFingerprint);
            FakeFingerprint _f = f as FakeFingerprint;
            assert(_f.level == level);
            if (_f.elderships[0] < cur_eldership)
            {
                cur_eldership = _f.elderships[0];
                ret.id = _f.id;
            }
        }
        return ret;
    }
}

public class FakeCost : Object, IQspnCost
{
    public int64 usec_rtt {get; set;}

    public FakeCost(int64 usec_rtt)
    {
        this.usec_rtt = usec_rtt;
    }

    public int i_qspn_compare_to(IQspnCost other)
    {
        if (other.i_qspn_is_dead()) return -1;
        if (other.i_qspn_is_null()) return 1;
        assert(other is FakeCost);
        FakeCost o = (FakeCost)other;
        if (usec_rtt > o.usec_rtt) return 1;
        if (usec_rtt < o.usec_rtt) return -1;
        return 0;
    }

    public IQspnCost i_qspn_add_segment(IQspnCost other)
    {
        if (other.i_qspn_is_dead()) return other;
        if (other.i_qspn_is_null()) return this;
        assert(other is FakeCost);
        FakeCost o = (FakeCost)other;
        return new FakeCost(usec_rtt + o.usec_rtt);
    }

    public bool i_qspn_important_variation(IQspnCost new_cost)
    {
        if (new_cost.i_qspn_is_dead()) return true;
        if (new_cost.i_qspn_is_null()) return true;
        assert(new_cost is FakeCost);
        FakeCost o = (FakeCost)new_cost;
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

