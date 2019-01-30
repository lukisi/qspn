using Gee;
using Netsukuku;
using Netsukuku.Qspn;
using TaskletSystem;

namespace SystemPeer
{
    void do_check_four_nodes_pid1()
    {
        // there should be 3 "Qspn:0:Signal:destination_added:"
        int count = 0;
        foreach (string s_event in tester_events)
            if ("Qspn:0:Signal:destination_added:" in s_event) count++;
        assert(count == 3);
        // there should be 3 "Qspn:0:Signal:path_added:eth0_"
        // and 3 "Qspn:0:Signal:path_added:eth1_"
        count = 0;
        foreach (string s_event in tester_events)
            if ("Qspn:0:Signal:path_added:eth0_" in s_event) count++;
        assert(count == 3);
        count = 0;
        foreach (string s_event in tester_events)
            if ("Qspn:0:Signal:path_added:eth1_" in s_event) count++;
        assert(count == 3);
    }

    void do_check_four_nodes_pid4()
    {
        // Since this is the last node to die, then there should be several events
        //  of type "Qspn:1:Signal:changed_nodes_inside(2):" and the last one of them
        //  should have ":0+1". (0 known dests, 1 nodes_inside)
        // "Qspn:1:Signal:changed_nodes_inside(2):Main:0+1"
        int count = 0;
        string last = "";
        foreach (string s_event in tester_events)
            if ("Qspn:1:Signal:changed_nodes_inside(2):" in s_event)
            {
                count++;
                last = s_event;
            }
        assert(count > 1);
        assert(":0+1" in last);
    }
}