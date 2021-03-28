#include <stdio.h>
#include <sys/stat.h>
#include <uci.h>
#include <json-c/json.h>
#include <assert.h>
#include <ctype.h>
#include "util.h"
#include "uclient.h"

struct recv_ctx {
	bool debug;

	// json stream parsing
	bool header_consumed;
	struct json_tokener *tok;
	bool tok_just_reset;

	// uci stuff
	struct uci_context *uci;
	struct uci_package *uci_package;
	bool uci_changed;
	bool address_changed;
};

struct node {
	const char *name;
	const char *address;
	const char *nodeid;
	struct uci_section* uci_section;
	struct recv_ctx* ctx;
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

struct node *node_find_by_nodeid(struct recv_ctx *ctx, const char *nodeid) {
	struct uci_element *e, *tmp;

	uci_foreach_element_safe(&ctx->uci_package->sections, tmp, e) {
		struct uci_section *s = uci_to_section(e);

		if (strcmp(s->type, "remote") != 0)
			continue;

		const char *uci_nodeid = uci_lookup_option_string(ctx->uci, s, "nodeid");
		if (!uci_nodeid || (strcmp(uci_nodeid, nodeid) != 0))
			continue;

		struct node *r = malloc(sizeof(struct node));
		r->uci_section = s;
		r->name = uci_lookup_option_string(ctx->uci, s, "name");
		r->address = uci_lookup_option_string(ctx->uci, s, "address");
		r->nodeid = nodeid;
		r->ctx = ctx;

		return r;
	}

	return NULL;
}

void _node_uci_set_field(struct node *r, const char *option, const char *value) {
	struct uci_ptr ptr = {
		.package = r->ctx->uci_package->e.name,
		.section = r->uci_section->e.name,
		.option = option,
		.value = value
	};

	uci_set(r->ctx->uci, &ptr);
	r->ctx->uci_changed = true;
}

void node_update_address(struct node *r, const char *new_address) {
	if (!r->address || strcmp(r->address, new_address)) {
		r->address = new_address;
		_node_uci_set_field(r, "address", new_address);
		printf("updating address of node %s to '%s'.\n", r->nodeid, new_address);
		r->ctx->address_changed = true;
	}
}

void node_update_name(struct node *r, const char *new_name) {
	if (!r->name || strcmp(r->name, new_name)) {
		r->name = new_name;
		_node_uci_set_field(r, "name", new_name);
		printf("updating name of node %s to '%s'.\n", r->nodeid, new_name);
	}
}

void node_update_from_nodeinfo(struct node *r, json_object *nodeinfo) {
	// maybe update address
	struct json_object *addresses;
	if (!gluon_json_get_path(nodeinfo, &addresses, json_type_array, 2, "network", "addresses"))
		goto update_node_name;

	// only change the address, if the json says that the node
	// does not have the old address anymore.
	if (r->address && gluon_json_string_array_contains(addresses, r->address))
		goto update_node_name;

	while (json_object_array_length(addresses) > 0) {
		int random_idx = rand() % json_object_array_length(addresses);
		json_object *address_j = json_object_array_get_idx(addresses, random_idx);
		const char *address = json_object_get_string(address_j);

		if (address && !is_ipv6_link_local(address)) {
			node_update_address(r, address);
			break;
		}

		json_object_array_del_idx(addresses, random_idx, 1);
	}

	// maybe update name
	const char *hostname;

update_node_name:
	if (gluon_json_get_path(nodeinfo, &hostname, json_type_string, 1, "hostname"))
		node_update_name(r, hostname);
}

void consume_line_json(struct recv_ctx *ctx, struct json_object *line) {
	if (!ctx->header_consumed) {
		const char *format;
		int version;

		if (!gluon_json_get_path(line, &format, json_type_string, 1, "format")) {
			fprintf(stderr, "Error: format of data is unknown.\n");
			exit(1);
		}

		if (strcmp(format, "raw-nodes-jsonl") != 0) {
			fprintf(stderr, "Error: format %s is unsupported.\n", format);
			exit(1);
		}

		if (!gluon_json_get_path(line, &version, json_type_int, 1, "version")) {
			fprintf(stderr, "Error: unexpectedly couldn't find version information in header.\n");
			exit(1);
		}

		if (version != 1) {
			fprintf(stderr, "Error: version %d is unsupported.\n", version);
			exit(1);
		}

		ctx->header_consumed = true;
	} else {
		struct json_object *nodeinfo = json_object_object_get(line, "nodeinfo");
		if (!nodeinfo)
			return;

		// lookup if we are interested in this node
		const char *nodeid;
		if (!gluon_json_get_path(nodeinfo, &nodeid, json_type_string, 1, "node_id"))
			return;

		// check if we are interested in this node
		struct node *node = node_find_by_nodeid(ctx, nodeid);
		if (!node)
			return;

		if (ctx->debug)
			printf("found node %s.\n", node->nodeid);

		node_update_from_nodeinfo(node, nodeinfo);
	}
}

void consume_chunk(struct recv_ctx *ctx, const char *pos, int len) {
	int parsed_length = 0;

	while (parsed_length < len) {
		pos += parsed_length;
		len -= parsed_length;
		parsed_length = 0;

		if (ctx->tok_just_reset) {
			ctx->tok_just_reset = false;

			if (*pos == '\n') {
				parsed_length = 1;
				continue;
			}
		}

		enum json_tokener_error jerr;
		json_object * jobj = json_tokener_parse_ex(ctx->tok, pos, len);
		jerr = json_tokener_get_error(ctx->tok);

		if (jerr == json_tokener_continue) {
			// the whole buffer was consumed by json_tokener_parse_ex(), so
			// we are done as of now.
			break;
		}

		parsed_length = ctx->tok->char_offset;

		if (jerr != json_tokener_success) {
			fprintf(stderr, "Invalid format detected.\n");
			exit(1);
		}

		consume_line_json(ctx, jobj);

		json_object_put(jobj);

		ctx->tok_just_reset = true;
		json_tokener_reset(ctx->tok);
	}
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

		consume_chunk(ctx, buf, len);
	}
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
	load_uci(&test);
	init_get_url();

	test.tok = json_tokener_new();

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
