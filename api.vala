/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

namespace Netsukuku.Qspn
{
    public interface IQspnNaddr : Object, IQspnAddress
    {
        public abstract int i_qspn_get_levels();
        public abstract int i_qspn_get_gsize(int level);
        public abstract int i_qspn_get_pos(int level);
    }

    public interface IQspnMyNaddr : Object, IQspnNaddr
    {
        public abstract HCoord i_qspn_get_coord_by_address(IQspnNaddr dest);
    }

    public interface IQspnFingerprint : Object
    {
        public abstract bool i_qspn_equals(IQspnFingerprint other);
        public abstract int i_qspn_get_level();
        public abstract IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingerprints, bool is_null_eldership=false);
        public abstract bool i_qspn_elder_seed(IQspnFingerprint other);
    }

    public interface IQspnCost : Object
    {
        public abstract int i_qspn_compare_to(IQspnCost other);
        public abstract IQspnCost i_qspn_add_segment(IQspnCost other);
        public abstract bool i_qspn_important_variation(IQspnCost new_cost);
        public abstract bool i_qspn_is_dead();
        public abstract bool i_qspn_is_null();
    }

    // Cost: Zero.
    internal class NullCost : Object, IQspnCost
    {
        public int i_qspn_compare_to(IQspnCost other)
        {
            if (other is NullCost) return 0;
            return -1;
        }

        public IQspnCost i_qspn_add_segment(IQspnCost other)
        {
            return other;
        }

        public bool i_qspn_important_variation(IQspnCost new_cost)
        {
            if (new_cost is NullCost) return false;
            return true;
        }

        public bool i_qspn_is_null()
        {
            return true;
        }

        public bool i_qspn_is_dead()
        {
            return false;
        }
    }

    // Cost: Infinity.
    internal class DeadCost : Object, IQspnCost
    {
        public int i_qspn_compare_to(IQspnCost other)
        {
            if (other is DeadCost) return 0;
            return 1;
        }

        public IQspnCost i_qspn_add_segment(IQspnCost other)
        {
            return this;
        }

        public bool i_qspn_important_variation(IQspnCost new_cost)
        {
            if (new_cost is DeadCost) return false;
            return true;
        }

        public bool i_qspn_is_null()
        {
            return false;
        }

        public bool i_qspn_is_dead()
        {
            return true;
        }
    }

    public interface IQspnArc : Object
    {
        public abstract IQspnCost i_qspn_get_cost();
        public abstract bool i_qspn_equals(IQspnArc other);
        public abstract bool i_qspn_comes_from(CallerInfo rpc_caller);
    }

    public interface IQspnHop : Object
    {
        public abstract int i_qspn_get_arc_id();
        public abstract HCoord i_qspn_get_hcoord();
    }

    public interface IQspnNodePath : Object
    {
        public abstract IQspnArc i_qspn_get_arc();
        public abstract Gee.List<IQspnHop> i_qspn_get_hops();
        public abstract IQspnCost i_qspn_get_cost();
        public abstract int i_qspn_get_nodes_inside();
        public abstract bool equals(IQspnNodePath other);
    }

    public interface IQspnThresholdCalculator : Object
    {
        public abstract int i_qspn_calculate_threshold(IQspnNodePath p1, IQspnNodePath p2);
    }

    public interface IQspnMissingArcHandler : Object
    {
        public abstract void i_qspn_missing(IQspnArc arc);
    }

    public interface IQspnStubFactory : Object
    {
        public abstract IQspnManagerStub
                        i_qspn_get_broadcast(
                            Gee.List<IQspnArc> arcs,
                            IQspnMissingArcHandler? missing_handler=null
                        );
        public abstract IQspnManagerStub
                        i_qspn_get_tcp(
                            IQspnArc arc,
                            bool wait_reply=true
                        );
    }

    public delegate IQspnNaddr ChangeNaddrDelegate(IQspnNaddr old);
    public delegate IQspnFingerprint ChangeFingerprintDelegate(IQspnFingerprint old);
}
