package main

import (
	"context"
	"encoding/binary"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cilium/ebpf"
	"github.com/cilium/ebpf/link"
	"github.com/cilium/ebpf/ringbuf"
)

// Event-Layout muss exakt zu struct event_t in
// bpf/wg_trace_delay.bpf.c passen.
type Event struct {
	ID      uint64
	DeltaNS uint64
}

func main() {
	log.SetFlags(0)

	if os.Geteuid() != 0 {
		log.Fatal("dieses Programm muss als root ausgeführt werden (sudo)")
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	spec, err := ebpf.LoadCollectionSpec("bpf/wg_trace_delay.bpf.o")
	if err != nil {
		log.Fatalf("BPF-Objekt konnte nicht geladen werden: %v", err)
	}

	var coll struct {
		Programs struct {
			TraceWgStart *ebpf.Program `ebpf:"trace_wg_start"`
			TraceWgEnd   *ebpf.Program `ebpf:"trace_wg_end"`
		}
		Maps struct {
			Events *ebpf.Map `ebpf:"events"`
		}
	}

	if err := spec.LoadAndAssign(&coll, nil); err != nil {
		log.Fatalf("BPF-Programme und Maps konnten nicht geladen werden: %v", err)
	}
	defer coll.Programs.TraceWgStart.Close()
	defer coll.Programs.TraceWgEnd.Close()
	defer coll.Maps.Events.Close()

	// Kprobes an WireGuard-Verschlüsselungsfunktion anhängen
	startKP, err := link.Kprobe("wg_packet_encrypt_worker", coll.Programs.TraceWgStart, nil)
	if err != nil {
		log.Fatalf("Konnte Kprobe wg_packet_encrypt_worker (entry) nicht anhängen: %v", err)
	}
	defer startKP.Close()

	endKP, err := link.Kretprobe("wg_packet_encrypt_worker", coll.Programs.TraceWgEnd, nil)
	if err != nil {
		log.Fatalf("Konnte Kretprobe wg_packet_encrypt_worker (return) nicht anhängen: %v", err)
	}
	defer endKP.Close()

	rb, err := ringbuf.NewReader(coll.Maps.Events)
	if err != nil {
		log.Fatalf("Ringbuffer konnte nicht geöffnet werden: %v", err)
	}
	defer rb.Close()

	log.Println("Trace läuft. Schicke jetzt Traffic durch deinen WireGuard-Tunnel,")
	log.Println("z.B. mit: ip netns exec ns1 ping 10.10.0.2")

	for {
		select {
		case <-ctx.Done():
			log.Println("Beende Trace.")
			return
		default:
		}

		rec, err := rb.Read()
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			// Ringbuffer-Reader nutzt keine Timeouts; unerwartete Fehler hart melden.
			log.Fatalf("Fehler beim Lesen aus dem Ringbuffer: %v", err)
		}

		if len(rec.RawSample) < 8+8 {
			continue
		}

		var e Event
		e.ID = binary.LittleEndian.Uint64(rec.RawSample[0:8])
		e.DeltaNS = binary.LittleEndian.Uint64(rec.RawSample[8:16])

		lat := time.Duration(e.DeltaNS)
		fmt.Printf("wg_encrypt_worker id=%x latency=%s\n", e.ID, lat)
	}
}
