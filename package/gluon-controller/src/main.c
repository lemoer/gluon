#include <stdio.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <glob.h>
#include "uclient.h"

#define LIB_EXT "so"

struct recv_ctx {
	int fd;
};

struct ustream_ssl_ctx *ssl_ctx;
const struct ustream_ssl_ops *ssl_ops;

static void recv_cb(struct uclient *cl) {
	struct recv_ctx *ctx = uclient_get_custom(cl);
	char buf[1024];
	int len;

	while (true) {
		printf(".");
		fflush(stdout);
		len = uclient_read_account(cl, buf, sizeof(buf));
		if (len <= 0)
			return;

		printf(
			"\rDownloading image: % 5zi / %zi KiB",
			uclient_data(cl)->downloaded / 1024,
			uclient_data(cl)->length / 1024
		);
		fflush(stdout);

		if (write(ctx->fd, buf, len) < len) {
			fputs("autoupdater: error: downloading firmware image failed: ", stderr);
			perror(NULL);
			return;
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

	const char *url = "https://hannover.freifunk.net/api/nodes.json";

	uloop_init();
	init_ustream_ssl();

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
