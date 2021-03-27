#include <stdio.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <glob.h>
#include "uclient.h"
#include <json-c/json.h>

#define LIB_EXT "so"

struct recv_ctx {
	int fd;
	bool header_consumed;

	bool nodes_found;
	struct json_tokener *tok;
	bool tok_just_reset;
};

struct ustream_ssl_ctx *ssl_ctx;
const struct ustream_ssl_ops *ssl_ops;

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

				}

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

	uloop_init();
	init_ustream_ssl();

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
	close(test.fd);

	printf("hey\n");
	return 0;
}
