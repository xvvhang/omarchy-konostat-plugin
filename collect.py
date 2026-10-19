"""Read-only Linux telemetry; emit one JSON snapshot every two seconds."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time


def read(path, default=""):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return default


def number(path):
    try:
        return float(read(path))
    except ValueError:
        return None


def cpu_ticks(text):
    # guest/guest_nice are already included in user/nice.
    values = [int(v) for v in text.splitlines()[0].split()[1:9]]
    return sum(values), values[3] + values[4]


def cpu_percent(previous, current):
    if previous is None:
        return None
    total, idle = current[0] - previous[0], current[1] - previous[1]
    return round(max(0, min(100, 100 * (total - idle) / total)), 1) if total > 0 else None


def memory_info(text):
    fields = {}
    for line in text.splitlines():
        key, value = line.split(":", 1)
        fields[key] = int(value.split()[0]) * 1024
    total = fields.get("MemTotal", 0)
    available = fields.get("MemAvailable", fields.get("MemFree", 0))
    return {"total": total, "used": max(0, total - available),
            "percent": round(100 * (total - available) / total, 1) if total else None,
            "swapTotal": fields.get("SwapTotal", 0),
            "swapUsed": fields.get("SwapTotal", 0) - fields.get("SwapFree", 0)}


def sensors():
    temperatures, fans = [], []
    for hw in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        chip = read(hw / "name", hw.name)
        for kind, target, scale in [("temp", temperatures, 1000), ("fan", fans, 1)]:
            for path in sorted(hw.glob(kind + "*_input")):
                value = number(path)
                if value is None or (kind == "temp" and not -30 <= value / scale <= 150):
                    continue
                stem = path.name.removesuffix("_input")
                target.append({"name": chip + " · " + read(hw / (stem + "_label"), stem),
                               "value": round(value / scale, 1)})
    if not temperatures:
        for zone in sorted(Path("/sys/class/thermal").glob("thermal_zone*")):
            value = number(zone / "temp")
            if value is not None and -30 <= value / 1000 <= 150:
                temperatures.append({"name": read(zone / "type", zone.name), "value": value / 1000})
    return temperatures, fans


def gpu_info():
    devices = []
    for card in sorted(Path("/sys/class/drm").glob("card[0-9]*")):
        if not re.fullmatch(r"card\d+", card.name):
            continue
        dev = card / "device"
        vendor = read(dev / "vendor")
        name = {"0x8086": "Intel", "0x1002": "AMD", "0x10de": "NVIDIA"}.get(vendor, "GPU")
        busy = number(dev / "gpu_busy_percent")
        frequency = number(card / "gt_cur_freq_mhz")
        if frequency is None:
            frequency = number(dev / "gt_cur_freq_mhz")
        devices.append({"name": name + " · " + card.name, "percent": busy,
                        "frequencyMHz": frequency, "memoryUsed": number(dev / "mem_info_vram_used"),
                        "memoryTotal": number(dev / "mem_info_vram_total")})
    if shutil.which("nvidia-smi"):
        try:
            result = subprocess.run([
                "nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,fan.speed",
                "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=1.5, check=True)
            nvidia = []
            for line in result.stdout.splitlines():
                name, *raw = [part.strip() for part in line.split(",")]
                values = []
                for value in raw:
                    try:
                        values.append(float(value))
                    except ValueError:
                        values.append(None)
                if len(values) != 5:
                    continue
                busy, used, total, temp, fan = values
                nvidia.append({"name": name, "percent": busy,
                               "memoryUsed": used * 1024**2 if used is not None else None,
                               "memoryTotal": total * 1024**2 if total is not None else None,
                               "temperature": temp, "fanPercent": fan})
            if nvidia:
                devices = [d for d in devices if not d["name"].startswith("NVIDIA")] + nvidia
        except (OSError, subprocess.SubprocessError):
            pass
    return devices


def storage_info():
    result, seen = [], set()
    for line in read("/proc/self/mountinfo").splitlines():
        left, right = line.split(" - ", 1)
        fields, fs = left.split(), right.split()
        mount = re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), fields[4])
        # Only local block-backed filesystems; no network mounts or pseudo-fs.
        if not fs[1].startswith("/dev/") or mount.startswith(("/run/", "/boot", "/efi")):
            continue
        try:
            # Btrfs subvolumes have distinct st_dev values but share capacity.
            device = (fields[2], fs[1])
            if device in seen:
                continue
            usage = os.statvfs(mount)
            total, free = usage.f_blocks * usage.f_frsize, usage.f_bavail * usage.f_frsize
            used = (usage.f_blocks - usage.f_bfree) * usage.f_frsize
            if not total:
                continue
            seen.add(device)
            result.append({"mount": mount, "total": total, "used": used, "free": free,
                           "percent": round(100 * used / (used + free), 1) if used + free else 0})
        except OSError:
            continue
    return sorted(result, key=lambda row: (row["mount"] != "/", row["mount"]))


def network_counters():
    result = {}
    for interface in Path("/sys/class/net").iterdir():
        # Physical interfaces only: excludes loopback, VPN and bridge duplication.
        if not (interface / "device").exists() or read(interface / "operstate") != "up":
            continue
        rx, tx = number(interface / "statistics/rx_bytes"), number(interface / "statistics/tx_bytes")
        if rx is not None and tx is not None:
            result[interface.name] = (rx, tx)
    return result


def network_rates(previous, current, elapsed):
    rows = []
    for name, counters in current.items():
        old = previous.get(name)
        rates = [max(0, (v - p) / elapsed) for v, p in zip(counters, old)] if old and elapsed > 0 else [0, 0]
        rows.append({"name": name, "download": rates[0], "upload": rates[1]})
    return {"interfaces": rows, "download": sum(r["download"] for r in rows),
            "upload": sum(r["upload"] for r in rows)}


class Collector:
    def __init__(self):
        self.cpu = None
        self.network = {}
        self.timestamp = None
        self.storage = []
        self.storage_time = -60
        self.cpu_name = next((line.split(":", 1)[1].strip() for line in read("/proc/cpuinfo").splitlines()
                              if line.startswith("model name")), "CPU")

    def snapshot(self):
        now = time.monotonic()
        cpu = cpu_ticks(read("/proc/stat"))
        network = network_counters()
        temps, fans = sensors()
        gpus = gpu_info()
        for gpu in gpus:
            if gpu.get("temperature") is not None:
                temps.append({"name": gpu["name"], "value": gpu["temperature"]})
        if now - self.storage_time >= 30:
            self.storage = storage_info()
            self.storage_time = now
        snapshot = {"cpu": {"name": self.cpu_name, "percent": cpu_percent(self.cpu, cpu),
                             "threads": os.cpu_count(), "load": list(os.getloadavg())},
                    "memory": memory_info(read("/proc/meminfo")), "gpus": gpus,
                    "storage": self.storage, "network": network_rates(self.network, network, now - self.timestamp if self.timestamp else 0),
                    "temperatures": temps, "fans": fans, "updatedAt": time.time()}
        self.cpu, self.network, self.timestamp = cpu, network, now
        return snapshot


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    collector = Collector()
    while True:
        start = time.monotonic()
        try:
            print(json.dumps(collector.snapshot(), ensure_ascii=False, allow_nan=False), flush=True)
        except BrokenPipeError:
            return
        if args.once:
            return
        time.sleep(max(0.1, 2 - (time.monotonic() - start)))


if __name__ == "__main__":
    main()
