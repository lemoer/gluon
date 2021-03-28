#include <stdio.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <glob.h>
#include "uclient.h"
#include <uci.h>
#include <json-c/json.h>
#include <ctype.h>

#define LIB_EXT "so"

struct recv_ctx {
	int fd;
	bool header_consumed;

	bool nodes_found;
	struct json_tokener *tok;
	bool tok_just_reset;

	struct uci_context *uci;
	struct uci_package *uci_package;
};

struct ustream_ssl_ctx *ssl_ctx;
const struct ustream_ssl_ops *ssl_ops;

void load_uci(struct recv_ctx *ctx) {

	ctx->uci = uci_alloc_context();

	if (!ctx->uci) {
		fprintf(stderr, "Error: Could not allocate uci context!\n");
		exit(1);
	}
	ctx->uci->flags &= ~UCI_FLAG_STRICT;

	if (uci_load(ctx->uci, "gluon-controller", &ctx->uci_package)) {
		fprintf(stderr, "Error: Could not load uci package gluon-controller\n");
		exit(1);
	}
}

void close_uci(struct recv_ctx *ctx) {
	uci_free_context(ctx->uci);
}

struct uci_section *find_remote_section_by_nodeid(struct recv_ctx *ctx, const char *nodeid) {
	struct uci_element *e, *tmp;

	uci_foreach_element_safe(&ctx->uci_package->sections, tmp, e) {
		struct uci_section *s = uci_to_section(e);

		if (strcmp(s->type, "remote") != 0)
			continue;

		const char *uci_nodeid = uci_lookup_option_string(ctx->uci, s, "nodeid");
		if (!uci_nodeid || (strcmp(uci_nodeid, nodeid) != 0))
			continue;

		return s;
	}

	return NULL;
}

bool is_ipv6_link_local(const char *address) {
	if (strlen(address) < 3)
		return false;

	if (!index(address, ':'))
		return false;

	if (address[0] != 'f' || address[1] != 'e')
		return false;

	const char *nibble_3 = "89ab";
	if (!index(nibble_3, address[2]))
		return false;

	if (!isxdigit(address[4]))
		return false;

	return true;
}

static void recv_cb(struct uclient *cl) {
	struct recv_ctx *ctx = uclient_get_custom(cl);
	char buf[1024];
	int len;

	while (true) {
		len = uclient_read_account(cl, buf, sizeof(buf));
		if (len <= 0) {
			return;
		}

		int parsed_length = 0;
		const char *begin = buf;

		while (parsed_length < len) {
			begin += parsed_length;
			len -= parsed_length;
			parsed_length = 0;

			if (ctx->tok_just_reset) {
				ctx->tok_just_reset = false;

				if (*begin == '\n') {
					parsed_length = 1;
					continue;
				}
			}

			enum json_tokener_error jerr;
			json_object * jobj = json_tokener_parse_ex(ctx->tok, begin, len);
			jerr = json_tokener_get_error(ctx->tok);

			if (jerr != json_tokener_continue) {
				parsed_length = ctx->tok->char_offset;

				if (jerr != json_tokener_success) {
					printf("error :(\n");
					printf("%c%c%c%c%c%c%c%c%c\n", *(begin + parsed_length-8), *(begin + parsed_length-7), *(begin + parsed_length-6), *(begin + parsed_length-5), *(begin + parsed_length-4), *(begin + parsed_length-3), *(begin + parsed_length-2), *(begin + parsed_length-1), *(begin + parsed_length));
					printf("%d %d\n", len, parsed_length);
					exit(1);
				}

				if (!ctx->header_consumed) {
					struct json_object *format = json_object_object_get(jobj, "format");
					if (!format) {
						fprintf(stderr, "Error: format is wrong\n");
						exit(1);
					}

					if (json_object_get_type(format) != json_type_string) {
						fprintf(stderr, "Error: format is wrong\n");
						exit(1);
					}

					if (strcmp(json_object_get_string(format), "raw-nodes-jsonl") != 0) {
						fprintf(stderr, "Error: format %s is unsupported.\n", json_object_get_string(format));
						exit(1);
					}

					struct json_object *version = json_object_object_get(jobj, "version");

					if (!version) {
						fprintf(stderr, "Error: format is wrong\n");
						exit(1);
					}

					if (json_object_get_type(version) != json_type_int) {
						fprintf(stderr, "Error: format is wrong\n");
						exit(1);
					}

					if (json_object_get_int(version) != 1) {
						fprintf(stderr, "Error: version %d is unsupported.\n", json_object_get_int(version));
						exit(1);
					}

					fprintf(stderr, "%d\n", json_object_get_int(version));

					ctx->header_consumed = true;
				} else {

					// lookup if we are interested in this node

					struct json_object *nodeinfo = json_object_object_get(jobj, "nodeinfo");
					if (!nodeinfo)
						goto skip;

					struct json_object *nodeid_j = json_object_object_get(nodeinfo, "node_id");
					if (!nodeid_j)
						goto skip;

					const char *nodeid = json_object_get_string(nodeid_j);

					struct uci_section *section = find_remote_section_by_nodeid(ctx, nodeid);
					if (!section)
						goto skip;

					bool changed = false;

					// maybe update address

					const char *uci_address = uci_lookup_option_string(ctx->uci, section, "address");

					struct json_object *network = json_object_object_get(nodeinfo, "network");
					if (!network)
						goto skip_address_update;

					struct json_object *addresses = json_object_object_get(network, "addresses");
					if (!addresses || json_object_get_type(addresses) != json_type_array)
						goto skip_address_update;

					const char *new_address = NULL;
					bool update_address = true;
					int random_idx = rand() % json_object_array_length(addresses);
					for (int i = 0; i < json_object_array_length(addresses); i++) {
						json_object *address_j = json_object_array_get_idx(addresses, i);
						const char *address = json_object_get_string(address_j);
						if (!address)
							continue;

						if (is_ipv6_link_local(address))
							continue;

						if (uci_address && !strcmp(address, uci_address)) {
							// old address is still valid, so skip address
							// update and keep old address
							update_address = false;
							break;
						}

						if (i == random_idx)
							new_address = address;
					}

					if (update_address && new_address) {
						printf("%s\n", new_address);
						struct uci_ptr ptr = {
							.package = ctx->uci_package->e.name,
							.section = section->e.name,
							.option = "address",
							.value = new_address
						};

						uci_set(ctx->uci, &ptr);
						uci_save(ctx->uci, ctx->uci_package);
						uci_commit(ctx->uci, &ctx->uci_package, true);
						printf("%s\n", "update");
					}

skip_address_update:
					printf("%s\n", nodeid);

				}
skip:
				json_object_put(jobj);

				ctx->tok_just_reset = true;
				json_tokener_reset(ctx->tok);
				continue;

			} else {
				// the whole buffer was consumed by json_tokener_parse_ex(), so
				// we are done as of now.
				break;
			}
		}

	}
}

static void init_ustream_ssl(void)
{
	void *dlh;

	dlh = dlopen("libustream-ssl." LIB_EXT, RTLD_LAZY | RTLD_LOCAL);
	if (!dlh)
		return;

	ssl_ops = dlsym(dlh, "ustream_ssl_ops");
	if (!ssl_ops)
		return;

	ssl_ctx = ssl_ops->context_new(false);
}

static void init_ca_cert(void)
{
	glob_t gl;
	unsigned int i;

	glob("/etc/ssl/certs/*.crt", 0, NULL, &gl);
	for (i = 0; i < gl.gl_pathc; i++)
		ssl_ops->context_add_ca_crt_file(ssl_ctx, gl.gl_pathv[i]);
	globfree(&gl);
}


int main(int argc, char const *argv[]) {
	/* code */
	struct recv_ctx test = {};

	const char *url = "https://harvester.ffh.zone/raw.jsonl";

	// init stuff
	srand(time(NULL));
	uloop_init();
	init_ustream_ssl();
	load_uci(&test);

	test.tok = json_tokener_new();

	if (!ssl_ctx && !strncmp(url, "https", 5)) {
		fprintf(stderr,
			"%s: SSL support not available, please install one of the "
			"libustream-.*[ssl|tls] packages as well as the ca-bundle and "
			"ca-certificates packages.\n",
			argv[0]);

		return 1;
	}

	if (ssl_ctx)
		init_ca_cert();

	test.fd = open("/tmp/nodes.json", O_WRONLY | O_CREAT);

	printf("open\n");

	int err = get_url(url, &recv_cb, &test, -1);

	if (err != 0) {
		printf("error: %s\n", uclient_get_errmsg(err));
		goto out;
	}

	printf("after get_url()\n");

out:
	close_uci(&test);
	close(test.fd);

	printf("hey\n");
	return 0;
}
