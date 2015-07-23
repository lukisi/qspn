#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>

char * macgetter_get_mac(const char *iface)
{
    struct ifreq s;
    int fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);
    char buf[20];

    strcpy(s.ifr_name, iface);
    if (0 == ioctl(fd, SIOCGIFHWADDR, &s))
    {
        char *mac = "";
        char *sep = "";
        int i;
        int p = 0;
        for (i = 0; i < 6; ++i)
        {
            int c = sprintf(buf+p, "%s%02x", sep, (unsigned char) s.ifr_addr.sa_data[i]);
            sep = ":";
            p = p + c;
        }
        return strdup(buf);
    }
    return NULL;
}

