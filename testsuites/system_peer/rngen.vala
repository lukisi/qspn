namespace SystemPeer
{
    public interface IRandomNumberGenerator : Object
    {
        // Generate a random integer from begin (included) to end (excluded)
        public abstract int32 int_range(int32 begin, int32 end);
    }

    public class PRNGen : Object
    {
        /*
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

    public class DefaultRandomNumberGenerator : Object, IRandomNumberGenerator
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
