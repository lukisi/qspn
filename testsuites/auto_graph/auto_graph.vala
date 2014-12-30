using Tasklets;
using Gee;
using zcd;
using Netsukuku;
using Test;

namespace Netsukuku
{
    public void    log_debug(string msg)   {print(msg+"\n");}
    public void    log_trace(string msg)   {print(msg+"\n");}
    public void  log_verbose(string msg)   {print(msg+"\n");}
    public void     log_info(string msg)   {print(msg+"\n");}
    public void   log_notice(string msg)   {print(msg+"\n");}
    public void     log_warn(string msg)   {print(msg+"\n");}
    public void    log_error(string msg)   {print(msg+"\n");}
    public void log_critical(string msg)   {print(msg+"\n");}
}

class Test.Address : Object
{
    public ArrayList<int> pos;
    public Address(Gee.List<int> pos)
    {
        this.pos = new ArrayList<int>();
        this.pos.add_all(pos);
    }
    public Address get_common_gnode(Address other)
    {
        ArrayList<int> p = new ArrayList<int>();
        int my_l = pos.size - 1;
        int other_l = other.pos.size - 1;
        while (true)
        {
            if (my_l < 0) break;
            if (other_l < 0) break;
            if (pos[my_l] != other.pos[other_l]) break;
            p.insert(0, pos[my_l]);
            my_l--;
            other_l--;
        }
        return new Address(p);
    }
    public string to_string()
    {
        string sep = "";
        string positions = "";
        for (int l = pos.size-1; l >= 0; l--)
        {
            positions += @"$(sep)$(pos[l])";
            sep = ".";
        }
        return @"$(positions)";
    }
}

class Test.Edge : Object
{
    public Test.Node src;
    public Test.Node dst;
}

class Test.Arc : Object
{
    public Node node;
    public int cost;
}

class Test.Node : Object
{
    public Address addr;
    public ArrayList<Arc> arcs;
    public int id;
}

class Test.GNode : Object
{
    public int pos;
    public HashMap<int, GNode> busy;
}

class GraphBuilder : Object
{
    public GraphBuilder(int[] gsizes, int max_arcs, int num_nodes)
    {
        this.gsizes = gsizes;
        this.max_arcs = max_arcs;
        this.num_nodes = num_nodes;
        levels = gsizes.length;
        edges = new ArrayList<Edge>();
        nodes = new ArrayList<Test.Node>();
        busy = new HashMap<int, GNode>();
    }
    public int[] gsizes;
    public int max_arcs;
    public int num_nodes;
    public int levels;
    public ArrayList<Edge> edges;
    public ArrayList<Test.Node> nodes;
    public HashMap<int, GNode> busy;
    public void add_node()
    {
        if (nodes.size == 0) {first_node(); return;}
        ArrayList<Test.Node> arcs_n = new ArrayList<Test.Node>();
        int k = 1;
        if (nodes.size < Math.sqrt(num_nodes) * 1.5)
        {
            arcs_n.add(nodes[nodes.size-1]);
        }
        else
        {
            k = Random.int_range(1, 4); // 1..3
            Test.Node v;
            while (true)
            {
                int rnd = Random.int_range(0, nodes.size);
                v = nodes[rnd];
                if (v.arcs.size < max_arcs) break;
            }
            Gee.List<Test.Node> n_v = neighborhood(v, k);
            arcs_n.add(v);
            for (int i = 0; i < k; i++)
            {
                Test.Node v2 = n_v[Random.int_range(0, n_v.size)];
                if (! (v2 in arcs_n) && v2.arcs.size < max_arcs)
                    arcs_n.add(v2);
            }
        }
        Address ref_addr = arcs_n[0].addr;
        Address addr = random_addr();
        while (true)
        {
            Address common = addr.get_common_gnode(ref_addr);
            int levels_common = common.pos.size;
            if (levels_common < levels)
            {
                HashMap<int, GNode> iteration_busy = busy;
                int iteration_lev = 0;
                while (iteration_lev < levels_common)
                {
                    iteration_busy = iteration_busy[common.pos[levels_common-iteration_lev-1]].busy;
                    iteration_lev++;
                }
                if (! (iteration_busy.has_key(addr.pos[levels-iteration_lev-1])))
                {
                    while (iteration_lev < levels)
                    {
                        int pos = addr.pos[levels-iteration_lev-1];
                        GNode new_gnode = new GNode();
                        new_gnode.pos = pos;
                        new_gnode.busy = new HashMap<int, GNode>();
                        iteration_busy[pos] = new_gnode;
                        iteration_busy = new_gnode.busy;
                        iteration_lev++;
                    }
                    break;
                }
            }
            addr = random_addr();
        }
        Test.Node n = new Test.Node();
        n.addr = addr;
        n.arcs = new ArrayList<Arc>();
        n.id = nodes.size + 1;
        foreach (Test.Node q in arcs_n)
        {
            Arc n_to_q = new Arc();
            n_to_q.node = q;
            n_to_q.cost = k*500 + Random.int_range(0, 1000);
            n.arcs.add(n_to_q);
            Arc q_to_n = new Arc();
            q_to_n.node = n;
            q_to_n.cost = k*500 + Random.int_range(0, 1000);
            q.arcs.add(q_to_n);
            Edge nq = new Edge();
            nq.src = n;
            nq.dst = q;
            edges.add(nq);
        }
        nodes.add(n);
    }
    void first_node()
    {
        Test.Node n = new Test.Node();
        n.addr = random_addr();
        n.arcs = new ArrayList<Arc>();
        n.id = nodes.size + 1;
        HashMap<int, GNode> iteration_busy = busy;
        int iteration_lev = 0;
        while (iteration_lev < levels)
        {
            int pos = n.addr.pos[levels-iteration_lev-1];
            GNode new_gnode = new GNode();
            new_gnode.pos = pos;
            new_gnode.busy = new HashMap<int, GNode>();
            iteration_busy[pos] = new_gnode;
            iteration_busy = new_gnode.busy;
            iteration_lev++;
        }
        nodes.add(n);
    }
    Address random_addr()
    {
        ArrayList<int> p = new ArrayList<int>();
        for (int i = 0; i < levels; i++) p.add(Random.int_range(0, gsizes[i]));
        return new Address(p);
    }
    Gee.List<Test.Node> neighborhood(Test.Node v, int k)
    {
        ArrayList<Test.Node> i = new ArrayList<Test.Node>();
        i.add(v);
        return neighborhood_recurse(i, k);
    }
    Gee.List<Test.Node> neighborhood_recurse(Gee.List<Test.Node> v_set, int k)
    {
        if (k == 0) return v_set;
        ArrayList<Test.Node> ret = new ArrayList<Test.Node>();
        ret.add_all(v_set);
        foreach (Test.Node v in v_set)
        {
            foreach (Arc a in v.arcs)
            {
                Test.Node v1 = a.node;
                foreach (Test.Node v2 in neighborhood(v1, k-1))
                {
                    if (! (v2 in ret)) ret.add(v2);
                }
            }
        }
        return ret;
    }
}

void print_graph(GraphBuilder b)
{
    print("GRAPH starts =====\n");
    foreach (Test.Node n in b.nodes)
    {
        print(@"Node $(n.addr)\n");
        if (! n.arcs.is_empty)
        {
            print(" connected to:\n");
            foreach (Arc a in n.arcs)
            {
                print(@"  * $(a.node.addr) (cost = $(a.cost))\n");
            }
        }
    }
    print("GRAPH ends =====\n");
    print("graph [\n");
    foreach (Test.Node n in b.nodes)
    {
        print("  node [\n");
        print(@"    id $(n.id)\n");
        print(@"    label \"$(n.addr)\"\n");
        print("  ]\n");
    }
    foreach (Edge e in b.edges)
    {
        print("  edge [\n");
        print(@"    source $(e.src.id)\n");
        print(@"    target $(e.dst.id)\n");
        print("  ]\n");
    }
    print("]\n");
}

int num_nodes;
int max_arcs;
[CCode (array_length = false, array_null_terminated = true)]
string[] topology;

int main(string[] args)
{
    num_nodes = 50; // default
    max_arcs = 6; // default
    int[] net_topology = {};
    OptionContext oc = new OptionContext();
    OptionEntry[] entries = new OptionEntry[4];
    int index = 0;
    entries[index++] = {"gsize", 's', 0, OptionArg.STRING_ARRAY, ref topology, "Size of gnodes", null};
    entries[index++] = {"maxarcs", 'm', 0, OptionArg.INT, ref max_arcs, "Max number of arcs per node", null};
    entries[index++] = {"nodes", 0, 0, OptionArg.INT, ref num_nodes, "Number of nodes", null};
    entries[index++] = { null };
    oc.add_main_entries(entries, null);
    try {
        oc.parse(ref args);
    }
    catch (OptionError e) {
        print(@"Error parsing options: $(e.message)\n");
        return 1;
    }

    foreach (string str_size in topology) net_topology += int.parse(str_size);
    if (net_topology.length == 0) net_topology = {16, 8, 8, 8}; // default
    GraphBuilder b = new GraphBuilder(net_topology, max_arcs, num_nodes);
    for (int i = 0; i < num_nodes; i++) b.add_node();
    print_graph(b);
    return 0;
}
