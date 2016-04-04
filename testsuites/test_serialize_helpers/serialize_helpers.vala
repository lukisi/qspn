/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2015-2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

using Netsukuku;
using Gee;

namespace TestSerializeInternals
{
    internal errordomain HelperDeserializeError {
        GENERIC
    }

    internal Object? deserialize_object(Type expected_type, bool nullable, Json.Node property_node)
    throws HelperDeserializeError
    {
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
        {
            if (!nullable)
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            return null;
        }
        if (!r.is_object())
            throw new HelperDeserializeError.GENERIC("element must be an object");
        string typename;
        if (!r.read_member("typename"))
            throw new HelperDeserializeError.GENERIC("element must have typename");
        if (!r.is_value())
            throw new HelperDeserializeError.GENERIC("typename must be a string");
        if (r.get_value().get_value_type() != typeof(string))
            throw new HelperDeserializeError.GENERIC("typename must be a string");
        typename = r.get_string_value();
        r.end_member();
        Type type = Type.from_name(typename);
        if (type == 0)
            throw new HelperDeserializeError.GENERIC(@"typename '$(typename)' unknown class");
        if (!type.is_a(expected_type))
            throw new HelperDeserializeError.GENERIC(@"typename '$(typename)' is not a '$(expected_type.name())'");
        if (!r.read_member("value"))
            throw new HelperDeserializeError.GENERIC("element must have value");
        r.end_member();
        unowned Json.Node p_value = property_node.get_object().get_member("value");
        Json.Node cp_value = p_value.copy();
        return Json.gobject_deserialize(type, cp_value);
    }

    internal Json.Node serialize_object(Object obj)
    {
        Json.Builder b = new Json.Builder();
        b.begin_object();
        b.set_member_name("typename");
        b.add_string_value(obj.get_type().name());
        b.set_member_name("value");
        b.add_value(Json.gobject_serialize(obj));
        b.end_object();
        return b.get_root();
    }

    internal class ListDeserializer<T> : Object
    {
        internal Gee.List<T> deserialize_list_object(Json.Node property_node)
        throws HelperDeserializeError
        {
            ArrayList<T> ret = new ArrayList<T>();
            Json.Reader r = new Json.Reader(property_node.copy());
            if (r.get_null_value())
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            if (!r.is_array())
                throw new HelperDeserializeError.GENERIC("element must be an array");
            int l = r.count_elements();
            for (uint j = 0; j < l; j++)
            {
                unowned Json.Node p_value = property_node.get_array().get_element(j);
                Json.Node cp_value = p_value.copy();
                ret.add(deserialize_object(typeof(T), false, cp_value));
            }
            return ret;
        }
    }

    internal Json.Node serialize_list_object(Gee.List<Object> lst)
    {
        Json.Builder b = new Json.Builder();
        b.begin_array();
        foreach (Object obj in lst)
        {
            b.add_value(serialize_object(obj));
        }
        b.end_array();
        return b.get_root();
    }

    internal int deserialize_int(Json.Node property_node)
    throws HelperDeserializeError
    {
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
            throw new HelperDeserializeError.GENERIC("element is not nullable");
        if (!r.is_value())
            throw new HelperDeserializeError.GENERIC("element must be a int");
        if (r.get_value().get_value_type() != typeof(int64))
            throw new HelperDeserializeError.GENERIC("element must be a int");
        int64 val = r.get_int_value();
        if (val > int.MAX || val < int.MIN)
            throw new HelperDeserializeError.GENERIC("element overflows size of int");
        return (int)val;
    }

    internal Json.Node serialize_int(int i)
    {
        Json.Node ret = new Json.Node(Json.NodeType.VALUE);
        ret.set_int(i);
        return ret;
    }

    internal IQspnNaddr deserialize_i_qspn_naddr(Json.Node property_node)
    throws HelperDeserializeError
    {
        return (IQspnNaddr)deserialize_object(typeof(IQspnNaddr), false, property_node);
    }

    internal Json.Node serialize_i_qspn_naddr(IQspnNaddr n)
    {
        return serialize_object(n);
    }

    internal IQspnCost deserialize_i_qspn_cost(Json.Node property_node)
    throws HelperDeserializeError
    {
        return (IQspnCost)deserialize_object(typeof(IQspnCost), false, property_node);
    }

    internal Json.Node serialize_i_qspn_cost(IQspnCost n)
    {
        return serialize_object(n);
    }

    internal IQspnFingerprint deserialize_i_qspn_fingerprint(Json.Node property_node)
    throws HelperDeserializeError
    {
        return (IQspnFingerprint)deserialize_object(typeof(IQspnFingerprint), false, property_node);
    }

    internal Json.Node serialize_i_qspn_fingerprint(IQspnFingerprint n)
    {
        return serialize_object(n);
    }

    internal EtpPath deserialize_etp_path(Json.Node property_node)
    throws HelperDeserializeError
    {
        return (EtpPath)deserialize_object(typeof(EtpPath), false, property_node);
    }

    internal Json.Node serialize_etp_path(EtpPath n)
    {
        return serialize_object(n);
    }

    internal Gee.List<IQspnFingerprint> deserialize_list_i_qspn_fingerprint(Json.Node property_node)
    throws HelperDeserializeError
    {
        ListDeserializer<IQspnFingerprint> c = new ListDeserializer<IQspnFingerprint>();
        return c.deserialize_list_object(property_node);
    }

    internal Json.Node serialize_list_i_qspn_fingerprint(Gee.List<IQspnFingerprint> lst)
    {
        return serialize_list_object(lst);
    }

    internal Gee.List<HCoord> deserialize_list_hcoord(Json.Node property_node)
    throws HelperDeserializeError
    {
        ListDeserializer<HCoord> c = new ListDeserializer<HCoord>();
        var first_ret = c.deserialize_list_object(property_node);
        // N.B. list of HCoord must be searchable for the qspn module to work.
        var ret = new ArrayList<HCoord>((a, b) => a.equals(b));
        ret.add_all(first_ret);
        return ret;
    }

    internal Json.Node serialize_list_hcoord(Gee.List<HCoord> lst)
    {
        return serialize_list_object(lst);
    }

    internal Gee.List<EtpPath> deserialize_list_etp_path(Json.Node property_node)
    throws HelperDeserializeError
    {
        ListDeserializer<EtpPath> c = new ListDeserializer<EtpPath>();
        return c.deserialize_list_object(property_node);
    }

    internal Json.Node serialize_list_etp_path(Gee.List<EtpPath> lst)
    {
        return serialize_list_object(lst);
    }

    internal Gee.List<int> deserialize_list_int(Json.Node property_node)
    throws HelperDeserializeError
    {
        ArrayList<int> ret = new ArrayList<int>();
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
            throw new HelperDeserializeError.GENERIC("element is not nullable");
        if (!r.is_array())
            throw new HelperDeserializeError.GENERIC("element must be an array");
        int l = r.count_elements();
        for (int j = 0; j < l; j++)
        {
            r.read_element(j);
            if (r.get_null_value())
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            if (!r.is_value())
                throw new HelperDeserializeError.GENERIC("element must be a int");
            if (r.get_value().get_value_type() != typeof(int64))
                throw new HelperDeserializeError.GENERIC("element must be a int");
            int64 val = r.get_int_value();
            if (val > int.MAX || val < int.MIN)
                throw new HelperDeserializeError.GENERIC("element overflows size of int");
            ret.add((int)val);
            r.end_element();
        }
        return ret;
    }

    internal Json.Node serialize_list_int(Gee.List<int> lst)
    {
        Json.Builder b = new Json.Builder();
        b.begin_array();
        foreach (int i in lst)
        {
            b.add_int_value(i);
        }
        b.end_array();
        return b.get_root();
    }

    internal Gee.List<bool> deserialize_list_bool(Json.Node property_node)
    throws HelperDeserializeError
    {
        ArrayList<bool> ret = new ArrayList<bool>();
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
            throw new HelperDeserializeError.GENERIC("element is not nullable");
        if (!r.is_array())
            throw new HelperDeserializeError.GENERIC("element must be an array");
        int l = r.count_elements();
        for (int j = 0; j < l; j++)
        {
            r.read_element(j);
            if (r.get_null_value())
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            if (!r.is_value())
                throw new HelperDeserializeError.GENERIC("element must be a bool");
            if (r.get_value().get_value_type() != typeof(bool))
                throw new HelperDeserializeError.GENERIC("element must be a bool");
            ret.add(r.get_boolean_value());
            r.end_element();
        }
        return ret;
    }

    internal Json.Node serialize_list_bool(Gee.List<bool> lst)
    {
        Json.Builder b = new Json.Builder();
        b.begin_array();
        foreach (bool i in lst)
        {
            b.add_boolean_value(i);
        }
        b.end_array();
        return b.get_root();
    }
}
