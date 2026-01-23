#!/usr/bin/env python3
import os
import re
import sys
import time
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt

os.environ["QT_API"] = "PySide6"

from PySide6.QtWidgets import QMainWindow, QApplication

from matplotlib.backends.backend_qtagg import FigureCanvas


LATENCY_PATTERN = re.compile(r"([-+]?\d*\.?\d+)\s*(us|µs|ms)\b", re.IGNORECASE)


def _read_latencies_us(path: Path) -> list[float]:
    """Liest alle Latenzen aus einer Logdatei und gibt sie in µs zurück."""

    if not path.is_file():
        return []

    values: list[float] = []

    with path.open() as f:
        for line in f:
            m = LATENCY_PATTERN.search(line)
            if not m:
                continue

            val = float(m.group(1))
            unit = m.group(2).lower()

            if unit in ("us", "µs"):
                val_us = val
            elif unit == "ms":
                val_us = val * 1000.0
            else:
                continue

            values.append(val_us)

    return values


def main() -> None:
    # Standard: lese aus wg_trace_delay_c.log und ping.log im aktuellen Verzeichnis
    if len(sys.argv) >= 3:
        wg_path = Path(sys.argv[1])
        ping_path = Path(sys.argv[2])
    else:
        wg_path = Path("wg_trace_delay_c.log")
        ping_path = Path("ping.log")

    print(f"Verwende WG-Log: {wg_path}")
    print(f"Verwende ping-Log: {ping_path}")

    matplotlib.use("QtAgg", force=True)

    plt.ion()

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))

    try:
        while True:
            wg_values = _read_latencies_us(wg_path)
            ping_values = _read_latencies_us(ping_path)

            ax1.clear()
            ax2.clear()

            len_wg = len(wg_values)
            len_ping = len(ping_values)

            # Zeitreihe mit Alignment auf den aktuellen Zeitpunkt
            # Ein Schritt im globalen Index entspricht 50 µs
            dt_s = 50e-3
            current_index: int | None = None

            if len_wg and len_ping:
                current_index = max(len_wg, len_ping) - 1

                start_wg = current_index - len_wg + 1
                start_ping = current_index - len_ping + 1

                idx_wg = list(range(start_wg, current_index + 1))
                idx_ping = list(range(start_ping, current_index + 1))

                x_wg = [i * dt_s for i in idx_wg]
                x_ping = [i * dt_s for i in idx_ping]

                ax1.plot(x_wg, [v / 1000.0 for v in wg_values], marker=".", linestyle="-", linewidth=0.7, label="wg_trace_delay_c")
                ax1.plot(x_ping, [v / 1000.0 for v in ping_values], marker=".", linestyle="-", linewidth=0.7, label="ping")
            elif len_wg:
                current_index = len_wg - 1
                idx_wg = list(range(len_wg))
                x_wg = [i * dt_s for i in idx_wg]
                ax1.plot(x_wg, [v / 1000.0 for v in wg_values], marker=".", linestyle="-", linewidth=0.7, label="wg_trace_delay_c")
            elif len_ping:
                current_index = len_ping - 1
                idx_ping = list(range(len_ping))
                x_ping = [i * dt_s for i in idx_ping]
                ax1.plot(x_ping, [v / 1000.0 for v in ping_values], marker=".", linestyle="-", linewidth=0.7, label="ping")

            ax1.set_title("Latenz über der Zeit")
            ax1.set_xlabel("Zeit [s] (relativ)")
            ax1.set_ylabel("Latenz [ms]")
            ax1.grid(True, alpha=0.3)
            ax1.legend(loc="upper right")

            # Nur ein Fenster der letzten 30 Sekunden anzeigen
            if current_index is not None:
                window_seconds = 30.0
                current_time = current_index * dt_s
                left = max(0.0, current_time - window_seconds)
                right = current_time
                ax1.set_xlim(left, right)

            # Histogramm (in ms)
            if wg_values:
                ax2.hist([v / 1000.0 for v in wg_values], bins=80, edgecolor="black", alpha=0.5, label="wg_trace_delay_c")
            if ping_values:
                ax2.hist([v / 1000.0 for v in ping_values], bins=80, edgecolor="black", alpha=0.5, label="ping")

            ax2.set_title("Histogramm der Latenzen")
            ax2.set_xlabel("Latenz [ms]")
            ax2.set_ylabel("Anzahl")
            ax2.grid(True, alpha=0.3)
            ax2.legend(loc="upper right")

            plt.tight_layout()
            plt.pause(0.05)

    except KeyboardInterrupt:
        pass
    finally:
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()
