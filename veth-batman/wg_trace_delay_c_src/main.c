// Userspace-Programm, das bpf/wg_trace_delay.bpf.o lädt,
// kprobes auf die im BPF-Programm definierten Hooks anhängt und
// Events aus dem Ringbuffer "events" ausgibt.

#define _GNU_SOURCE
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <limits.h>
#include <libgen.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>

static volatile sig_atomic_t exiting = 0;

static void handle_sigint(int sig)
{
    (void)sig;
    exiting = 1;
}

struct event_t {
    uint64_t id;
    uint64_t delta_ns;
};

static int handle_event(void *ctx, void *data, size_t data_sz)
{
    (void)ctx;

    if (data_sz < sizeof(struct event_t)) {
        fprintf(stderr, "event size too small: %zu\n", data_sz);
        return 0;
    }

    const struct event_t *e = data;
    double us = e->delta_ns / 1000.0;
    double ms = e->delta_ns / 1e6;

    printf("wg_encrypt_worker id=0x%llx latency=%llu ns (%.3f us, %.6f ms)\n",
           (unsigned long long)e->id,
           (unsigned long long)e->delta_ns,
           us, ms);
    fflush(stdout);

    return 0;
}

int main(int argc, char **argv)
{
    char obj_path_buf[PATH_MAX];
    const char *obj_path = NULL;
    struct bpf_object *obj = NULL;
    struct bpf_program *prog_start = NULL;
    struct bpf_program *prog_end = NULL;
    struct bpf_link *link_start = NULL;
    struct bpf_link *link_end = NULL;
    struct bpf_map *events_map = NULL;
    struct ring_buffer *rb = NULL;
    int err = 0;

    if (geteuid() != 0) {
        fprintf(stderr, "wg_trace_delay_c muss als root ausgeführt werden (sudo ./wg_trace_delay_c).\n");
        return 1;
    }

    /* Standardpfad: BPF-Objekt relativ zum Verzeichnis des Binaries
     * erwarten (../bpf/wg_trace_delay.bpf.o, wenn Binary im Projekt-
     * Wurzelverzeichnis liegt). Fällt zurück auf Pfad relativ zum
     * aktuellen Arbeitsverzeichnis, falls /proc/self/exe nicht
     * verfügbar ist.
     */
    do {
        char exe_path[PATH_MAX];
        ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
        if (len < 0) {
            /* Fallback: wie bisher relativ zum CWD. */
            obj_path = "bpf/wg_trace_delay.bpf.o";
            break;
        }
        exe_path[len] = '\0';

        char *dir = dirname(exe_path);
        if (!dir) {
            obj_path = "bpf/wg_trace_delay.bpf.o";
            break;
        }

        if (snprintf(obj_path_buf, sizeof(obj_path_buf), "%s/%s", dir, "bpf/wg_trace_delay.bpf.o") >= (int)sizeof(obj_path_buf)) {
            obj_path = "bpf/wg_trace_delay.bpf.o";
            break;
        }

        obj_path = obj_path_buf;
    } while (0);

    if (argc > 1)
        obj_path = argv[1];

    signal(SIGINT, handle_sigint);
    signal(SIGTERM, handle_sigint);

    obj = bpf_object__open_file(obj_path, NULL);
    if (!obj) {
        fprintf(stderr, "bpf_object__open_file(%s) failed: %s\n",
                obj_path, strerror(errno));
        return 1;
    }

    err = bpf_object__load(obj);
    if (err) {
        fprintf(stderr, "bpf_object__load failed: %d\n", err);
        goto cleanup;
    }

    prog_start = bpf_object__find_program_by_name(obj, "trace_wg_start");
    prog_end   = bpf_object__find_program_by_name(obj, "trace_wg_end");
    if (!prog_start || !prog_end) {
        fprintf(stderr, "could not find programs trace_wg_start/trace_wg_end\n");
        err = 1;
        goto cleanup;
    }

    link_start = bpf_program__attach(prog_start);
    if (!link_start) {
        err = -errno;
        fprintf(stderr, "bpf_program__attach(trace_wg_start) failed: %s\n",
                strerror(errno));
        goto cleanup;
    }

    link_end = bpf_program__attach(prog_end);
    if (!link_end) {
        err = -errno;
        fprintf(stderr, "bpf_program__attach(trace_wg_end) failed: %s\n",
                strerror(errno));
        goto cleanup;
    }

    events_map = bpf_object__find_map_by_name(obj, "events");
    if (!events_map) {
        fprintf(stderr, "could not find map 'events'\n");
        err = 1;
        goto cleanup;
    }

    int events_fd = bpf_map__fd(events_map);
    if (events_fd < 0) {
        fprintf(stderr, "bpf_map__fd(events) failed\n");
        err = 1;
        goto cleanup;
    }

    rb = ring_buffer__new(events_fd, handle_event, NULL, NULL);
    if (!rb) {
        fprintf(stderr, "ring_buffer__new failed\n");
        err = 1;
        goto cleanup;
    }

    printf("wg_trace_delay_c attached, press Ctrl-C to stop...\n");

    while (!exiting) {
        err = ring_buffer__poll(rb, 100 /* ms */);
        if (err == -EINTR) {
            break;
        } else if (err < 0) {
            fprintf(stderr, "ring_buffer__poll failed: %d\n", err);
            break;
        }
    }

    err = 0;

cleanup:
    ring_buffer__free(rb);
    if (link_start)
        bpf_link__destroy(link_start);
    if (link_end)
        bpf_link__destroy(link_end);
    if (obj)
        bpf_object__close(obj);

    return err ? 1 : 0;
}
