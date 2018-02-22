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
using TaskletSystem;

namespace Netsukuku.Qspn
{
    public interface IRandomNumberGenerator : Object
    {
        // Generate a random integer from begin (included) to end (excluded)
        public abstract int32 int_range(int32 begin, int32 end);
    }

    internal class PRNGen : Object
    {
        /*
        This internal static method is called from IdentityManager.init_rngen which is
        public, so the program can call it.

        The program can call this function with an implementation of IRandomNumberGenerator.

        Otherwise, the program can call the function with a *null* rngen, and a *null* seed.
        In this case the library will use g_random_int_range of glib.

        Otherwise, the program can call the function with a *null* rngen, and a seed.
        In this case the library will generate a GRand with g_rand_new_with_seed of glib.
        Then it will use g_rand_int_range of glib.

        If the program does not call the function at all, then the first call (from the
        code of the library) to the PRNGen (static) methods will initialize by calling
        first the function with *null* and *null*.
        */
        public static void init_rngen(IRandomNumberGenerator? rngen=null, uint32? seed=null)
        {
            if (rngen != null) _rng = rngen;
            else if (seed == null) _rng = new DefaultRandomNumberGenerator();
            else _rng = new DefaultRandomNumberGenerator.with_seed(seed);
        }

        private static IRandomNumberGenerator? _rng = null;

        public static int32 int_range(int32 begin, int32 end)
        {
            if (_rng == null) init_rngen();
            assert(_rng != null);
            return _rng.int_range(begin, end);
        }
    }

    internal class DefaultRandomNumberGenerator : Object, IRandomNumberGenerator
    {
        private Rand? _rand;
        public DefaultRandomNumberGenerator()
        {
            _rand = null;
        }
        public DefaultRandomNumberGenerator.with_seed(uint32 seed)
        {
            _rand = new Rand.with_seed(seed);
        }

        public int32 int_range(int32 begin, int32 end)
        {
            if (_rand == null) return Random.int_range(begin, end);
            else return _rand.int_range(begin, end);
        }
    }
}
