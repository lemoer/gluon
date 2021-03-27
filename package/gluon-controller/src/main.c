#include <stdio.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "uclient.h"

struct recv_ctx {
	int fd;
};

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

int main(int argc, char const *argv[]) {
	/* code */
	struct recv_ctx test = {};

	uloop_init();

	test.fd = open("/tmp/nodes.json", O_WRONLY | O_CREAT);

	printf("open\n");

	int err = get_url("https://hannover.freifunk.net/api/nodes.json", &recv_cb, &test, -1);

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
