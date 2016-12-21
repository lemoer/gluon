#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <json-c/json.h>
#include <net/if.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "batadv-netlink.h"

#define STR(x) #x
#define XSTR(x) STR(x)

struct neigh_netlink_opts {
  struct json_object *obj;
  struct batadv_nlquery_opts query_opts;
};

static const enum batadv_nl_attrs parse_orig_list_mandatory[] = {
  BATADV_ATTR_ORIG_ADDRESS,
  BATADV_ATTR_NEIGH_ADDRESS,
  BATADV_ATTR_TQ,
  BATADV_ATTR_HARD_IFINDEX,
  BATADV_ATTR_LAST_SEEN_MSECS,
};

static int parse_orig_list_netlink_cb(struct nl_msg *msg, void *arg)
{
  struct nlattr *attrs[BATADV_ATTR_MAX+1];
  struct nlmsghdr *nlh = nlmsg_hdr(msg);
  struct batadv_nlquery_opts *query_opts = arg;
  struct genlmsghdr *ghdr;
  uint8_t *orig;
  uint8_t *dest;
  uint8_t tq;
  uint32_t hardif;
  uint32_t lastseen;
  char ifname_buf[IF_NAMESIZE], *ifname;
  struct neigh_netlink_opts *opts;
  char mac1[18];

  opts = container_of(query_opts, struct neigh_netlink_opts, query_opts);

  if (!genlmsg_valid_hdr(nlh, 0))
    return NL_OK;

  ghdr = nlmsg_data(nlh);

  if (ghdr->cmd != BATADV_CMD_GET_ORIGINATORS)
    return NL_OK;

  if (nla_parse(attrs, BATADV_ATTR_MAX, genlmsg_attrdata(ghdr, 0),
        genlmsg_len(ghdr), batadv_netlink_policy))
    return NL_OK;

  if (batadv_nl_missing_attrs(attrs, parse_orig_list_mandatory,
              ARRAY_SIZE(parse_orig_list_mandatory)))
    return NL_OK;

  if (!attrs[BATADV_ATTR_FLAG_BEST])
    return NL_OK;

  orig = nla_data(attrs[BATADV_ATTR_ORIG_ADDRESS]);
  dest = nla_data(attrs[BATADV_ATTR_NEIGH_ADDRESS]);
  tq = nla_get_u8(attrs[BATADV_ATTR_TQ]);
  hardif = nla_get_u32(attrs[BATADV_ATTR_HARD_IFINDEX]);
  lastseen = nla_get_u32(attrs[BATADV_ATTR_LAST_SEEN_MSECS]);

  if (memcmp(orig, dest, 6) != 0)
    return NL_OK;

  ifname = if_indextoname(hardif, ifname_buf);
  if (!ifname)
    return NL_OK;

  sprintf(mac1, "%02x:%02x:%02x:%02x:%02x:%02x",
          orig[0], orig[1], orig[2], orig[3], orig[4], orig[5]);

  struct json_object *neigh = json_object_new_object();
  if (!neigh)
    return NL_OK;

  json_object_object_add(neigh, "protocol", json_object_new_string("batman"));
  json_object_object_add(neigh, "tq", json_object_new_int(tq));
  json_object_object_add(neigh, "lastseen", json_object_new_double(lastseen / 1000.));
  json_object_object_add(neigh, "ifname", json_object_new_string(ifname));

  json_object_object_add(opts->obj, mac1, neigh);

  return NL_OK;
}

/**
 * ll_to_mac - convert a ipv6 link local address to mac address
 * @dest: buffer to store the resulting mac as string (18 bytes including the terminating \0)
 * @linklocal_ip6: \0 terminated string of the ipv6 address
 *
 * Return: true on success
 */
bool ll_to_mac(char *dest, const char* linklocal_ip6) {
  struct in6_addr ll_addr;
  unsigned char mac[6];

  // parse the ip6
  if (!inet_pton(AF_INET6, linklocal_ip6, &ll_addr))
    return false;

  mac[0] = ll_addr.s6_addr[ 8] ^ (1 << 1);
  mac[1] = ll_addr.s6_addr[ 9];
  mac[2] = ll_addr.s6_addr[10];
  mac[3] = ll_addr.s6_addr[13];
  mac[4] = ll_addr.s6_addr[14];
  mac[5] = ll_addr.s6_addr[15];

  snprintf(dest, 18, "%02x:%02x:%02x:%02x:%02x:%02x",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return true;
}

/**
 * sock_read_line - read until a newline without a fixed buffer length (using realloc)
 * @sock_fd: socket filedescriptor
 * @buffer: pointer to the address of the allocated buffer (on first call
            this should point to a pointer with the value NULL)
 * @line_len: length of the already processed line including the terminating \0,
 *            at the beginning of the buffer.
 * @collected_chars: number of characters already collected for the next line
 *
 * Return: This function returns true, if we were able to read something.
 */
bool sock_read_line(int sock_fd, char **buffer, size_t *line_len, size_t *collected_chars) {
  // we want to receive up to 1024 bytes on the socket
  const size_t chunksize = 1024;

  // move the already collected characters of the next line
  // to the beginning of the buffer, if it's necessary
  if (*line_len) {
    char *next_line = *buffer + *line_len;
    memmove(*buffer, next_line, *collected_chars);
  }

  // search for a newline in *buffer if *buffer != NULL
  if (*buffer) {
    char *stringp = *buffer;
    strsep(&stringp, "\n");

    if (stringp) {
      // we reached a newline
      *line_len = strlen(*buffer) + 1;
      *collected_chars -= *line_len;
      return true;
    }
  }

  // reallocate buffer
  size_t new_buffer_size = (*collected_chars) + chunksize + 1;
  *buffer = realloc(*buffer, new_buffer_size);

  if (!*buffer) {
    fprintf(stderr, "Cannot allocate buffer\n");
    exit(1);
  }

  int len = read(sock_fd, *buffer + *collected_chars, chunksize);

  if (!len)
    return false;

  if (len < 0) {
    perror("read");
    exit(1);
  }

  *collected_chars += len;
  (*buffer)[new_buffer_size - 1] = '\0';

  *line_len = 0;
  return sock_read_line(sock_fd, buffer, line_len, collected_chars);
}

void add_neighbours_babel(struct json_object *obj) {
    // init babel socket
    int babel_fd = socket(AF_INET6, SOCK_STREAM, 0);

    if (babel_fd < 0)
      return;

    struct sockaddr_in6 babel_addr = {
      .sin6_family = AF_INET6,
      .sin6_port = htons(33123)
    };

    if (inet_pton(AF_INET6, "::1", &babel_addr.sin6_addr) != 1) {
      fprintf(stderr, "Can't read parse hostname ::1.\n");
      exit(1);
    }

    if (connect(babel_fd, (struct sockaddr *) &babel_addr, sizeof(babel_addr)) != 0)
      return;

    // send the dump command and shutdown write operations on the socket, so babeld
    // will close the socket after writing the response to the socket
    write(babel_fd, "dump\n", 5);
    shutdown(babel_fd, SHUT_WR);

    size_t collected_chars = 0;
    size_t line_len = 0;
    char *buffer = NULL;

    while (sock_read_line(babel_fd, &buffer, &line_len, &collected_chars)) {
      char node_id[13];
      char linklocal_ip6[25];
      char mac[18];
      char ifname[IF_NAMESIZE+1];
      unsigned short reach;
      unsigned short rxcost;
      unsigned short txcost;
      unsigned short cost;

      int count = sscanf(
        buffer,
        "add neighbour %12s address %24s if %" XSTR(IF_NAMESIZE) "s "
        "reach %hx rxcost %hu txcost %hu cost %hu ",
        node_id, linklocal_ip6, ifname,
        &reach, &rxcost, &txcost, &cost
      );

      if (count != 7)
        continue;

      // convert the link local address to mac
      if (!ll_to_mac(mac, linklocal_ip6))
        continue;

      struct json_object *neigh = json_object_new_object();

      json_object_object_add(neigh, "protocol", json_object_new_string("babel"));
      // TODO: add an identifier for the used cost algorithm
      json_object_object_add(neigh, "rxcost", json_object_new_int(rxcost));
      json_object_object_add(neigh, "txcost", json_object_new_int(txcost));
      json_object_object_add(neigh, "cost", json_object_new_int(cost));
      json_object_object_add(neigh, "reachability", json_object_new_double(reach));
      json_object_object_add(neigh, "ifname", json_object_new_string(ifname));

      json_object_object_add(obj, mac, neigh);
    }

    free(buffer);
    close(babel_fd);
}

void add_neighbours_batman(struct json_object *obj) {
  struct neigh_netlink_opts opts = {
    .query_opts = {
      .err = 0,
    },
    .obj = obj,
  };

  batadv_nl_query_common("bat0", BATADV_CMD_GET_ORIGINATORS,
                         parse_orig_list_netlink_cb, NLM_F_DUMP,
                         &opts.query_opts);
}

int main(void) {
  struct json_object *neighbours;

  printf("Content-type: text/event-stream\n\n");
  fflush(stdout);

  while (1) {
    neighbours = json_object_new_object();
    if (!neighbours)
      continue;

    add_neighbours_batman(neighbours);
    add_neighbours_babel(neighbours);

    printf("data: %s\n\n", json_object_to_json_string_ext(neighbours, JSON_C_TO_STRING_PLAIN));
    fflush(stdout);
    json_object_put(neighbours);

    sleep(10);
  }

  return 0;
}
