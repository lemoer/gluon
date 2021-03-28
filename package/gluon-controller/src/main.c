#include <stdio.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <glob.h>
#include "uclient.h"
#include <uci.h>
#include <json-c/json.h>
#include <assert.h>
#include <ctype.h>

#define LIB_EXT "so"

struct recv_ctx {
	bool header_consumed;

	bool debug;
	bool nodes_found;
	struct json_tokener *tok;
	bool tok_just_reset;

	struct uci_context *uci;
	struct uci_package *uci_package;
	bool uci_changed;
	bool address_changed;
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
	if (ctx->uci_changed) {
		uci_save(ctx->uci, ctx->uci_package);
		uci_commit(ctx->uci, &ctx->uci_package, true);
	}

	uci_free_context(ctx->uci);
}

struct remote {
	const char *name;
	const char *address;
	const char *nodeid;
	struct uci_section* uci_section;
	struct recv_ctx* ctx;
};

struct remote *remote_find_by_nodeid(struct recv_ctx *ctx, const char *nodeid) {
	struct uci_element *e, *tmp;

	uci_foreach_element_safe(&ctx->uci_package->sections, tmp, e) {
		struct uci_section *s = uci_to_section(e);

		if (strcmp(s->type, "remote") != 0)
			continue;

		const char *uci_nodeid = uci_lookup_option_string(ctx->uci, s, "nodeid");
		if (!uci_nodeid || (strcmp(uci_nodeid, nodeid) != 0))
			continue;

		struct remote *r = malloc(sizeof(struct remote));
		r->uci_section = s;
		r->name = uci_lookup_option_string(ctx->uci, s, "name");
		r->address = uci_lookup_option_string(ctx->uci, s, "address");
		r->nodeid = nodeid;
		r->ctx = ctx;

		return r;
	}

	return NULL;
}

void _remote_uci_set_field(struct remote *r, const char *option, const char *value) {
	struct uci_ptr ptr = {
		.package = r->ctx->uci_package->e.name,
		.section = r->uci_section->e.name,
		.option = option,
		.value = value
	};

	uci_set(r->ctx->uci, &ptr);
	r->ctx->uci_changed = true;
}

void remote_update_address(struct remote *r, const char *new_address) {
	if (!r->address || strcmp(r->address, new_address)) {
		r->address = new_address;
		_remote_uci_set_field(r, "address", new_address);
		printf("updating address of node %s to '%s'.\n", r->nodeid, new_address);
		r->ctx->address_changed = true;
	}
}

void remote_update_name(struct remote *r, const char *new_name) {
	if (!r->name || strcmp(r->name, new_name)) {
		r->name = new_name;
		_remote_uci_set_field(r, "name", new_name);
		printf("updating name of node %s to '%s'.\n", r->nodeid, new_name);
	}
}

bool gluon_json_get_path(json_object *obj, void *dest, enum json_type T, int depth, ...) {
	va_list sp;

	va_start(sp, depth);
	json_object *el = obj;

	for(int i = 0; i < depth; i++) {
		const char *field_name = va_arg(sp, const char*);
		el = json_object_object_get(el, field_name);

		if (!el)
			return false;
	}

	if (json_object_get_type(el) != T)
		return false;

	switch (T) {
		case json_type_int:
			*((int*) dest) = json_object_get_int(el);
			break;
		case json_type_string:
			*((const char**) dest) = json_object_get_string(el);
			break;
		case json_type_array:
			*((struct json_object **) dest) = el;
			break;
		default:
			fprintf(stderr, "Error: gluon_json_get_path() NIY!\n");
			exit(1);
			assert(false); // NIY
	}

	return true;
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

	if (!isxdigit(address[3]))
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
					const char *format;
					int version;

					if (!gluon_json_get_path(jobj, &format, json_type_string, 1, "format")) {
						fprintf(stderr, "Error: format of data is unknown.\n");
						exit(1);
					}

					if (strcmp(format, "raw-nodes-jsonl") != 0) {
						fprintf(stderr, "Error: format %s is unsupported.\n", format);
						exit(1);
					}

					if (!gluon_json_get_path(jobj, &version, json_type_int, 1, "version")) {
						fprintf(stderr, "Error: unexpectedly couldn't find version information in header.\n");
						exit(1);
					}

					if (version != 1) {
						fprintf(stderr, "Error: version %d is unsupported.\n", version);
						exit(1);
					}

					ctx->header_consumed = true;
				} else {
					struct json_object *nodeinfo = json_object_object_get(jobj, "nodeinfo");
					if (!nodeinfo)
						goto skip;

					// lookup if we are interested in this node
					const char *nodeid;
					if (!gluon_json_get_path(nodeinfo, &nodeid, json_type_string, 1, "node_id"))
						goto skip;

					struct remote *remote = remote_find_by_nodeid(ctx, nodeid);
					if (!remote)
						goto skip;

					if (ctx->debug)
						printf("found node %s.\n", remote->nodeid);

					// maybe update address
					struct json_object *addresses;
					if (!gluon_json_get_path(nodeinfo, &addresses, json_type_array, 2, "network", "addresses"))
						goto skip_address_update;

					const char *new_address = NULL;
					int random_idx = rand() % json_object_array_length(addresses);
					for (int i = 0; i < json_object_array_length(addresses); i++) {
						json_object *address_j = json_object_array_get_idx(addresses, i);
						const char *address = json_object_get_string(address_j);
						if (!address)
							continue;

						if (is_ipv6_link_local(address))
							continue;

						if (remote->address && !strcmp(address, remote->address)) {
							// old address is still valid, so skip address
							// update and keep old address
							new_address = remote->address;
							break;
						}

						if (i == random_idx)
							new_address = address;
					}

					if (new_address)
						remote_update_address(remote, new_address);

					// maybe update hostname
					const char *hostname;
skip_address_update:
					if (!gluon_json_get_path(nodeinfo, &hostname, json_type_string, 1, "hostname"))
						goto skip_name_update;

					remote_update_name(remote, hostname);
				}
skip_name_update:
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
	struct recv_ctx test = {
		.debug = true
	};

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

	int err = get_url(url, &recv_cb, &test, -1);

	if (err != 0) {
		printf("error: %s\n", uclient_get_errmsg(err));
		goto out;
	}

out:
	close_uci(&test);

	if (test.address_changed) {
		printf("restarting gluon-controller service.\n");
		system("/etc/init.d/gluon-controller restart");
	}

	return 0;
}
