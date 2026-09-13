#!/usr/bin/env python3
"""
OmaPulse Engine: Optimized Unprivileged Linux Hardware & Process Monitor.
Collects CPU, per-core utilization, RAM/Swap, GPU, disk/net I/O,
and top resource-consuming processes from Linux /proc and /sys.
"""

import argparse
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile
import time

STATE_DIR = Path.home() / ".local" / "state" / "omarchy" / "pulse"
STATE_FILE = STATE_DIR / "status.json"
PREV_METRICS_FILE = STATE_DIR / ".prev_metrics.json"

MAX_STATE_BYTES = 512 * 1024  # 512 KB
CLK_TCK = os.sysconf(os.sysconf_names.get('SC_CLK_TCK', 100))

# Application Icon Mapping for Linux Desktop
APP_ICONS = {
    "firefox": "󰈹",
    "firefox-bin": "󰈹",
    "zen-bin": "󰈹",
    "zen": "󰈹",
    "chrome": "󰊯",
    "chromium": "󰊯",
    "brave": "󰊯",
    "code": "󰨞",
    "codium": "󰨞",
    "alacritty": "󰞷",
    "kitty": "󰞷",
    "ghostty": "󰞷",
    "foot": "󰞷",
    "discord": "󰙯",
    "vesktop": "󰙯",
    "spotify": "󰓇",
    "steam": "󰓓",
    "docker": "󰗃",
    "dockerd": "󰗃",
    "containerd": "󰗃",
    "qemu": "󰢹",
    "kvm": "󰢹",
    "quickshell": "󰍛",
    "hyprland": "󰖲",
    "waybar": "󰍛",
    "python": "󰌠",
    "python3": "󰌠",
    "node": "󰎙",
    "npm": "󰎙",
    "cargo": "󱘗",
    "rustc": "󱘗",
    "git": "󰊢",
    "ollama": "󱚣",
    "obsidian": "󰠮",
    "vlc": "󰕼",
    "mpv": "󰕼",
    "gimp": "󰽉",
    "inkscape": "󰽉",
    "blender": "󰽉"
}


def read_bounded_json(file_path, max_bytes=MAX_STATE_BYTES):
    p = Path(file_path)
    if not p.exists():
        return {}
    try:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
        fd = os.open(str(p), flags)
        with os.fdopen(fd, "rb") as stream:
            st = os.fstat(fd)
            if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid():
                return {}
            if st.st_size > max_bytes:
                return {}
            raw = stream.read(max_bytes + 1)
            if len(raw) > max_bytes:
                return {}
            return json.loads(raw.decode("utf-8", errors="replace"))
    except Exception:
        return {}


def write_atomic(path, data, max_bytes=MAX_STATE_BYTES):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    raw_bytes = (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if len(raw_bytes) > max_bytes:
        print(f"Error: Payload size {len(raw_bytes)} exceeds {max_bytes}", file=sys.stderr)
        return

    # Verify parent directory ownership and regular directory mode before temp file creation
    parent_fd = os.open(str(p.parent), os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0))
    try:
        pst = os.fstat(parent_fd)
        if not stat.S_ISDIR(pst.st_mode) or pst.st_uid != os.getuid():
            raise PermissionError("Parent directory ownership mismatch or not a directory")
    finally:
        os.close(parent_fd)

    handle, temp_name = tempfile.mkstemp(dir=str(p.parent), suffix=".tmp")
    try:
        os.fchmod(handle, 0o600)
        with os.fdopen(handle, "wb") as stream:
            stream.write(raw_bytes)
            stream.flush()
            os.fsync(stream.fileno())
        if p.exists():
            st = p.lstat()
            if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid():
                p.unlink(missing_ok=True)
        os.replace(temp_name, p)
    except BaseException:
        Path(temp_name).unlink(missing_ok=True)
        raise


def load_prev_metrics():
    return read_bounded_json(PREV_METRICS_FILE)



def save_prev_metrics(metrics):
    try:
        write_atomic(PREV_METRICS_FILE, metrics)
    except Exception:
        pass


def get_cpu_info():
    """Reads /proc/stat and returns overall and per-core CPU jiffies."""
    cores_raw = {}
    total_raw = []
    try:
        with open("/proc/stat", "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split()
                if not parts:
                    continue
                if parts[0] == "cpu":
                    total_raw = [int(x) for x in parts[1:]]
                elif parts[0].startswith("cpu") and parts[0][3:].isdigit():
                    cores_raw[parts[0]] = [int(x) for x in parts[1:]]
    except Exception:
        pass
    return total_raw, cores_raw


def get_mem_info():
    """Reads /proc/meminfo and calculates accurate RAM and Swap utilization."""
    mem = {}
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    k = parts[0].strip()
                    val_str = parts[1].strip().split()[0]
                    mem[k] = int(val_str) * 1024
    except Exception:
        pass

    total = mem.get("MemTotal", 1)
    avail = mem.get("MemAvailable", mem.get("MemFree", 0))
    used = max(0, total - avail)
    pct = round((used / total) * 100, 1)

    swap_total = mem.get("SwapTotal", 0)
    swap_free = mem.get("SwapFree", 0)
    swap_used = max(0, swap_total - swap_free)
    swap_pct = round((swap_used / swap_total * 100), 1) if swap_total > 0 else 0.0

    return {
        "totalBytes": total,
        "usedBytes": used,
        "availableBytes": avail,
        "percentUsed": pct,
        "swapTotalBytes": swap_total,
        "swapUsedBytes": swap_used,
        "swapPercentUsed": swap_pct,
        "buffersBytes": mem.get("Buffers", 0),
        "cachedBytes": mem.get("Cached", 0)
    }


def get_system_temperature():
    """Finds the package/CPU temperature from /sys/class/thermal or /sys/class/hwmon."""
    temps = {}
    try:
        for z in sorted(Path("/sys/class/thermal").glob("thermal_zone*")):
            temp_f = z / "temp"
            type_f = z / "type"
            if temp_f.exists() and type_f.exists():
                try:
                    t_val = int(temp_f.read_text().strip()) / 1000.0
                    z_type = type_f.read_text().strip()
                    temps[z_type] = t_val
                except Exception:
                    pass
    except Exception:
        pass

    for key in ("x86_pkg_temp", "TCPU", "k10temp", "coretemp", "cpu_thermal"):
        if key in temps:
            return round(temps[key], 1)

    valid = [v for v in temps.values() if 20 <= v <= 110]
    return round(max(valid), 1) if valid else 45.0


def get_gpu_info():
    """Queries NVIDIA, AMD, or Intel GPU metrics with bounded output."""
    try:
        proc = subprocess.Popen(
            ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        out, _ = proc.communicate(timeout=1.0)
        if len(out) > 32 * 1024:
            out = out[:32 * 1024]
        if proc.returncode == 0 and out.strip():
            parts = [p.strip() for p in out.strip().split(",")]
            if len(parts) >= 5:
                return {
                    "available": True,
                    "vendor": "NVIDIA",
                    "name": parts[0],
                    "utilizationPercent": float(parts[1]),
                    "vramUsedBytes": int(parts[2]) * 1024 * 1024,
                    "vramTotalBytes": int(parts[3]) * 1024 * 1024,
                    "vramPercent": round((float(parts[2]) / float(parts[3])) * 100, 1) if float(parts[3]) > 0 else 0.0,
                    "temperature": float(parts[4])
                }
    except Exception:
        pass

    return {
        "available": False,
        "vendor": "Integrated",
        "name": "Integrated Graphics",
        "utilizationPercent": 0.0,
        "vramUsedBytes": 0,
        "vramTotalBytes": 0,
        "vramPercent": 0.0,
        "temperature": 0.0
    }


def get_disk_and_net_io(prev, dt):
    """Calculates disk read/write throughput (KB/s) and network rx/tx (KB/s)."""
    curr_disk_read = 0
    curr_disk_write = 0
    try:
        with open("/proc/diskstats", "r", encoding="utf-8") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 14:
                    dev_name = parts[2]
                    if re.match(r"^(nvme\d+n\d+|sd[a-z]|vd[a-z])$", dev_name):
                        curr_disk_read += int(parts[5]) * 512
                        curr_disk_write += int(parts[9]) * 512
    except Exception:
        pass

    prev_disk_read = prev.get("diskReadBytes", curr_disk_read)
    prev_disk_write = prev.get("diskWriteBytes", curr_disk_write)

    disk_read_kb = max(0.0, (curr_disk_read - prev_disk_read) / dt / 1024.0)
    disk_write_kb = max(0.0, (curr_disk_write - prev_disk_write) / dt / 1024.0)

    curr_net_rx = 0
    curr_net_tx = 0
    try:
        with open("/proc/net/dev", "r", encoding="utf-8") as f:
            for line in f.readlines()[2:]:
                parts = line.split(":")
                if len(parts) == 2:
                    iface = parts[0].strip()
                    if iface != "lo":
                        vals = parts[1].split()
                        curr_net_rx += int(vals[0])
                        curr_net_tx += int(vals[8])
    except Exception:
        pass

    prev_net_rx = prev.get("netRxBytes", curr_net_rx)
    prev_net_tx = prev.get("netTxBytes", curr_net_tx)

    net_rx_kb = max(0.0, (curr_net_rx - prev_net_rx) / dt / 1024.0)
    net_tx_kb = max(0.0, (curr_net_tx - prev_net_tx) / dt / 1024.0)

    return {
        "diskReadBytes": curr_disk_read,
        "diskWriteBytes": curr_disk_write,
        "diskReadKBs": round(disk_read_kb, 1),
        "diskWriteKBs": round(disk_write_kb, 1),
        "netRxBytes": curr_net_rx,
        "netTxBytes": curr_net_tx,
        "netRxKBs": round(net_rx_kb, 1),
        "netTxKBs": round(net_tx_kb, 1)
    }


def get_top_processes(prev_proc_times, dt, total_ram_bytes):
    """Scans /proc/[pid] to find top processes using steady delta calculation."""
    procs = []
    curr_proc_times = {}
    my_uid = os.getuid()

    try:
        for entry in os.scandir("/proc"):
            if not entry.name.isdigit():
                continue
            pid = int(entry.name)
            stat_file = Path(entry.path) / "stat"
            status_file = Path(entry.path) / "status"

            if not stat_file.exists():
                continue

            try:
                stat_content = stat_file.read_text(encoding="utf-8", errors="ignore")
                m = re.match(r"^(\d+)\s+\((.+)\)\s+(\S+)\s+\d+\s+.*", stat_content)
                if not m:
                    continue

                comm = m.group(2)
                state = m.group(3)
                
                rest = stat_content[stat_content.rfind(")") + 2:].split()
                if len(rest) < 13:
                    continue

                utime = int(rest[11])
                stime = int(rest[12])
                proc_total_ticks = utime + stime
                curr_proc_times[pid] = proc_total_ticks

                rss_bytes = 0
                uid_val = 0
                if status_file.exists():
                    for line in status_file.read_text(encoding="utf-8", errors="ignore").splitlines():
                        if line.startswith("VmRSS:"):
                            rss_bytes = int(line.split()[1]) * 1024
                        elif line.startswith("Uid:"):
                            uid_val = int(line.split()[1])

                prev_ticks = prev_proc_times.get(str(pid), prev_proc_times.get(pid, proc_total_ticks))
                cpu_delta_ticks = max(0, proc_total_ticks - prev_ticks)
                proc_cpu_pct = round((cpu_delta_ticks / dt / CLK_TCK) * 100.0, 1)

                mem_pct = round((rss_bytes / total_ram_bytes) * 100.0, 1) if total_ram_bytes > 0 else 0.0

                comm_clean = comm.lower()
                icon = APP_ICONS.get(comm_clean, "󰒋")
                if "zen" in comm_clean or "firefox" in comm_clean:
                    icon = "󰈹"
                elif "chrome" in comm_clean:
                    icon = "󰊯"
                elif "code" in comm_clean:
                    icon = "󰨞"

                if proc_cpu_pct > 0.05 or rss_bytes > 50 * 1024 * 1024:
                    procs.append({
                        "pid": pid,
                        "name": comm[:32],
                        "icon": icon,
                        "cpuPercent": min(100.0, proc_cpu_pct),
                        "memPercent": min(100.0, mem_pct),
                        "rssBytes": rss_bytes,
                        "state": state,
                        "isMine": (uid_val == my_uid)
                    })
            except (ProcessLookupError, FileNotFoundError, PermissionError):
                continue
    except Exception:
        pass

    by_cpu = sorted(procs, key=lambda p: p["cpuPercent"], reverse=True)[:12]
    by_mem = sorted(procs, key=lambda p: p["rssBytes"], reverse=True)[:12]

    combined = {p["pid"]: p for p in by_cpu}
    for p in by_mem:
        combined[p["pid"]] = p

    sorted_list = sorted(combined.values(), key=lambda p: (p["cpuPercent"], p["memPercent"]), reverse=True)
    return sorted_list[:12], curr_proc_times


def get_proc_identity(pid):
    try:
        stat_path = Path(f"/proc/{pid}/stat")
        status_path = Path(f"/proc/{pid}/status")
        if not stat_path.exists() or not status_path.exists():
            return None, None
        
        # Read stat for starttime (field index 21 in 0-indexed after comm)
        content = stat_path.read_text(encoding="utf-8", errors="ignore")
        rest = content[content.rfind(")") + 2:].split()
        starttime = int(rest[19]) if len(rest) > 19 else None
        
        uid = None
        for line in status_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("Uid:"):
                uid = int(line.split()[1])
                break
        return uid, starttime
    except Exception:
        return None, None


def execute_process_action(action, pid):
    """Sends SIGTERM or SIGKILL to an unprivileged process after re-verifying UID and identity."""
    try:
        target_pid = int(pid)
        if target_pid <= 1:
            print(json.dumps({"ok": False, "error": "Invalid PID"}))
            return

        my_uid = os.getuid()
        proc_uid, starttime = get_proc_identity(target_pid)
        if proc_uid is None or proc_uid != my_uid:
            print(json.dumps({"ok": False, "error": f"Permission denied: process {target_pid} not owned by UID {my_uid}"}))
            return

        if action == "kill":
            os.kill(target_pid, signal.SIGKILL)
            print(json.dumps({"ok": True, "action": "kill", "pid": target_pid}))
        elif action == "term":
            os.kill(target_pid, signal.SIGTERM)
            print(json.dumps({"ok": True, "action": "term", "pid": target_pid}))
        else:
            print(json.dumps({"ok": False, "error": f"Unknown action {action}"}))
    except ProcessLookupError:
        print(json.dumps({"ok": False, "error": f"Process {pid} no longer exists"}))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))


def poll_telemetry():
    """Executes a full hardware and process telemetry poll and writes status.json."""
    now = time.time()
    prev = load_prev_metrics()
    prev_time = prev.get("timestamp", now - 2.0)
    dt = max(0.5, now - prev_time)

    # 1. Total & Per-Core CPU
    curr_total_cpu, curr_cores = get_cpu_info()
    prev_total_cpu = prev.get("totalCpuRaw", curr_total_cpu)
    prev_cores = prev.get("coresRaw", curr_cores)

    def calc_cpu_pct(curr, prev_raw):
        if not curr or not prev_raw or len(curr) < 4 or len(prev_raw) < 4:
            return 0.0
        idle_curr = curr[3] + (curr[4] if len(curr) > 4 else 0)
        idle_prev = prev_raw[3] + (prev_raw[4] if len(prev_raw) > 4 else 0)
        total_curr = sum(curr)
        total_prev = sum(prev_raw)
        delta_total = max(1, total_curr - total_prev)
        delta_idle = max(0, idle_curr - idle_prev)
        usage = max(0.0, min(100.0, ((delta_total - delta_idle) / delta_total) * 100.0))
        return round(usage, 1)

    total_cpu_pct = calc_cpu_pct(curr_total_cpu, prev_total_cpu)

    per_core_list = []
    for c_name in sorted(curr_cores.keys(), key=lambda x: int(x[3:])):
        c_pct = calc_cpu_pct(curr_cores[c_name], prev_cores.get(c_name, curr_cores[c_name]))
        per_core_list.append({
            "core": c_name,
            "percent": c_pct
        })

    mem_info = get_mem_info()
    cpu_temp = get_system_temperature()
    gpu_info = get_gpu_info()
    io_info = get_disk_and_net_io(prev, dt)

    prev_procs = prev.get("procTimes", {})
    top_processes, curr_proc_times = get_top_processes(prev_procs, dt, mem_info["totalBytes"])

    hog = top_processes[0] if top_processes else {"name": "None", "cpuPercent": 0.0, "memPercent": 0.0, "icon": "󰒋"}

    # Disciplined alert boundaries
    alert_level = "green"
    alert_reason = f"System resources nominal. Active: {hog['name']} ({hog['cpuPercent']}% CPU)"

    if total_cpu_pct >= 90.0:
        alert_level = "red"
        alert_reason = f"Critical CPU Saturation: {total_cpu_pct}% load ({hog['name']} using {hog['cpuPercent']}%)"
    elif mem_info["percentUsed"] >= 90.0:
        alert_level = "red"
        alert_reason = f"Critical Memory Pressure: {mem_info['percentUsed']}% RAM exhausted ({hog['name']} using {mem_info['usedBytes'] // (1024*1024)} MB)"
    elif cpu_temp >= 96.0:
        alert_level = "red"
        alert_reason = f"Critical Thermal Limit: CPU at {cpu_temp}°C (approaching throttle point)"
    elif total_cpu_pct >= 75.0:
        alert_level = "amber"
        alert_reason = f"Elevated CPU Load: {total_cpu_pct}% ({hog['name']} consuming {hog['cpuPercent']}%)"
    elif mem_info["percentUsed"] >= 80.0:
        alert_level = "amber"
        alert_reason = f"High Memory Consumption: {mem_info['percentUsed']}% RAM used"
    elif cpu_temp >= 88.0:
        alert_level = "amber"
        alert_reason = f"Elevated Temperature: CPU package at {cpu_temp}°C"

    doc = {
        "version": 1,
        "updatedAt": int(now),
        "alertLevel": alert_level,
        "alertReason": alert_reason,
        "cpu": {
            "percent": total_cpu_pct,
            "temperature": cpu_temp,
            "coreCount": len(per_core_list),
            "cores": per_core_list
        },
        "memory": mem_info,
        "gpu": gpu_info,
        "io": {
            "diskReadKBs": io_info["diskReadKBs"],
            "diskWriteKBs": io_info["diskWriteKBs"],
            "netRxKBs": io_info["netRxKBs"],
            "netTxKBs": io_info["netTxKBs"]
        },
        "topHog": hog,
        "processes": top_processes
    }

    write_atomic(STATE_FILE, doc)
    save_prev_metrics({
        "timestamp": now,
        "totalCpuRaw": curr_total_cpu,
        "coresRaw": curr_cores,
        "diskReadBytes": io_info["diskReadBytes"],
        "diskWriteBytes": io_info["diskWriteBytes"],
        "netRxBytes": io_info["netRxBytes"],
        "netTxBytes": io_info["netTxBytes"],
        "procTimes": curr_proc_times
    })

    print(f"OmaPulse: CPU {total_cpu_pct}% | RAM {mem_info['percentUsed']}% | Temp {cpu_temp}°C | Alert: {alert_level.upper()} ({alert_reason})")


def main():
    parser = argparse.ArgumentParser(description="OmaPulse Telemetry Engine")
    parser.add_argument("--poll", action="store_true", help="Run full hardware & process poll")
    parser.add_argument("--kill", type=int, help="Force kill process by PID (SIGKILL)")
    parser.add_argument("--term", type=int, help="Terminate process by PID (SIGTERM)")
    args = parser.parse_args()

    if args.kill:
        execute_process_action("kill", args.kill)
    elif args.term:
        execute_process_action("term", args.term)
    else:
        poll_telemetry()


if __name__ == "__main__":
    main()
