// eBPF-Programm, das die Dauer vom Aufruf von
// wg_packet_send_staged_packets() bis zum tatsächlichen Absenden des
// verschlüsselten UDP-Pakets über wg_socket_send_skb_to_peer() misst.
//
// Damit bekommst du nahezu die Gesamtdauer der Verarbeitung eines
// ausgehenden IP-Pakets durch WireGuard ab dem Zeitpunkt, an dem für
// einen Peer tatsächlich Daten verschickt werden sollen, inklusive
// Queueing, Verschlüsselung in wg_packet_encrypt_worker und finalem
// Socket-Send.

#include <linux/bpf.h>
#include <linux/types.h>
#include <bpf/bpf_endian.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

char LICENSE[] SEC("license") = "GPL";

struct event_t {
    __u64 id;        // Identifier (hier: Pointer auf struct wg_peer)
    __u64 delta_ns;  // Laufzeit in Nanosekunden
};

// Map: Paket-ID -> Start-Timestamp
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 16384);
    __type(key, __u64);
    __type(value, __u64);
} start_ts SEC(".maps");

// Ringbuffer für Events
// Auf Embedded-Systemen ist 16 MiB (1<<24) oft zu groß und
// führt zu ENOMEM. 1<<20 entspricht 1 MiB Puffer.
struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 1 << 20);
} events SEC(".maps");

// Globales Rate-Limit: maximal ein Event alle 50 ms
#define EMIT_INTERVAL_NS 50000000ULL

// Map mit einem Element zur Speicherung des letzten Emit-Timestamps
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, __u64);
} last_emit_ts SEC(".maps");

static __always_inline int should_emit(void)
{
    __u32 idx = 0;
    __u64 now = bpf_ktime_get_ns();
    __u64 *last = bpf_map_lookup_elem(&last_emit_ts, &idx);

    if (!last)
        return 0;

    if (*last == 0) {
        *last = now;
        return 1;
    }

    if (now - *last < EMIT_INTERVAL_NS)
        return 0;

    *last = now;
    return 1;
}

// Start: Eintritt in wg_packet_send_staged_packets(struct wg_peer *peer)
//
// Wir verwenden als Key den Pointer auf den Peer. Auf Systemen wie
// OpenWrt ist wg_xmit in der Regel ein static-Symbol und damit nicht
// kprobebar (kein Eintrag in kallsyms), wg_packet_send_staged_packets
// hingegen ist global und zuverlässig verfügbar.
SEC("kprobe/wg_prev_queue_enqueue")
int trace_wg_start(struct pt_regs *ctx)
{
    void *skb = (void *)PT_REGS_PARM2(ctx);
    __u64 raw = (__u64) skb;
    __u64 key = raw >> 32;
    __u64 ts = bpf_ktime_get_ns();

    if (!skb)
        return 0;

    bpf_map_update_elem(&start_ts, &key, &ts, BPF_ANY);

    /* Debug-Mock: wir kennen struct wg_peer auf diesem Kernel nicht
     * (kein BTF-Eintrag), daher verwenden wir hier einfach den
     * Peer-Pointer selbst als id und eine feste Latenz. So kannst du
     * sehen, dass wg_packet_send_staged_packets() getriggert wird,
     * ohne von echten WireGuard-Headern abhängig zu sein.
     */
    // struct event_t *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    // if (!e)
    //     return 0;

    // e->id = key;
    // e->delta_ns = 1337;

    // bpf_ringbuf_submit(e, 0);
    // return 0;
}

// Ende: Eintritt in wg_socket_send_skb_to_peer(struct wg_peer *peer,
//                                              struct sk_buff *skb,
//                                              u8 ds)
// Zu diesem Zeitpunkt ist das Paket verschlüsselt und wird als
// WireGuard-UDP-Paket über den Socket verschickt.
SEC("kprobe/wg_socket_send_skb_to_peer")
int trace_wg_end(struct pt_regs *ctx)
{
    /* Debug-Version: wir ignorieren die eigentliche Zeitmessung und
     * geben einfach den skb-Pointer als id und eine konstante
     * delta_ns=1337 aus, um sicherzustellen, dass der Hook
     * funktioniert und wir das richtige skb sehen.
     */
    void *skb = (void *)PT_REGS_PARM2(ctx);
    __u64 raw = (__u64) skb;
    __u64 key = raw >> 32;


    // struct event_t *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    // if (!e)
    //     return 0;

    // e->id = key;
    // e->delta_ns = 0;

    // bpf_ringbuf_submit(e, 0);

    // lookup
    __u64 *start_ts_ptr = bpf_map_lookup_elem(&start_ts, &key);
    if (!start_ts_ptr)
        return 0;

    __u64 delta_ns = bpf_ktime_get_ns() - *start_ts_ptr;
    bpf_map_delete_elem(&start_ts, &key);

    if (!should_emit())
        return 0;

    struct event_t *e2 = bpf_ringbuf_reserve(&events, sizeof(*e2), 0);
    if (!e2)
        return 0;

    e2->id = (__u64)skb;
    e2->delta_ns = delta_ns;

    bpf_ringbuf_submit(e2, 0);

    return 0;
}
