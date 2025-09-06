#!/usr/bin/env python3
import argparse
import os
import shlex
import subprocess
import sys
from datetime import datetime


BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LOG_DIR = os.path.join(BASE_DIR, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)


def ts():
    return datetime.now().strftime('%Y%m%d-%H%M%S')


def run(cmd, sudo=False, timeout=120, env=None):
    if isinstance(cmd, str):
        cmd_list = shlex.split(cmd)
    else:
        cmd_list = cmd
    if sudo and os.geteuid() != 0:
        cmd_list = ['sudo', '-n'] + cmd_list
    try:
        return subprocess.run(
            cmd_list,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            env=env or os.environ,
            text=True,
            check=False,
        ).stdout
    except subprocess.CalledProcessError as e:
        return e.stdout or str(e)
    except subprocess.TimeoutExpired:
        return f"Command timed out: {' '.join(cmd_list)}"
    except Exception as e:
        return f"Error running {' '.join(cmd_list)}: {e}"


def write_section(f, title, content):
    f.write(f"## {title}\n")
    f.write(content.rstrip() + "\n\n---\n\n")


def collect_diagnostics(outfile):
    with open(outfile, 'w') as f:
        f.write("macOS Python IT Toolkit Diagnostics\n")
        f.write(f"Timestamp: {datetime.now().isoformat()}\n")
        f.write("Tool version: 0.1.0\n\n")

    append = lambda title, cmd, sudo=False: write_section(
        open(outfile, 'a'), title, run(cmd, sudo=sudo)
    )

    # Health Summary (quick signals)
    write_section(open(outfile, 'a'), "Health Summary", build_health_summary())

    append("OS Version", ["sw_vers"]) 
    append("Kernel", ["uname", "-a"]) 
    append("Uptime", ["uptime"]) 
    append("Hardware", ["system_profiler", "SPHardwareDataType"]) 
    append("Root Disk Usage", ["df", "-H", "/"]) 
    append("Spotlight Indexing", ["mdutil", "-s", "/"]) 
    append("Network Interfaces", ["ifconfig", "-a"]) 
    append("DNS Summary", 'sh -c \'scutil --dns | sed -n "1,160p"\'') 
    append("Default Route", ["route", "-n", "get", "default"]) 
    append(
        "Wi-Fi (if present)",
        "sh -c 'networksetup -listallhardwareports; echo; networksetup -getinfo Wi-Fi || true'",
    )
    append("Recent Reboots", "last reboot | head -n 10")
    # Login items (can be blocked by permissions; ignore errors)
    append(
        "Login Items",
        [
            "osascript",
            "-e",
            'tell application "System Events" to get the name of every login item',
        ],
    )


# ---------------- Functions needed for reporting -----------------

def _disk_used_percent():
    out = run(["df", "-k", "/"]) or ""
    lines = [l for l in out.splitlines() if l.strip()]
    if len(lines) < 2:
        return None
    # header: Filesystem 1024-blocks Used Available Capacity iused ifree %iused Mounted on
    parts = lines[1].split()
    if len(parts) < 6:
        return None
    # try to find a column like '85%'
    for p in parts:
        if p.endswith('%') and p[:-1].isdigit():
            try:
                return int(p[:-1])
            except ValueError:
                pass
    return None


def _iface_ip(iface):
    if not iface:
        return None
    out = run(["ipconfig", "getifaddr", iface]) or ""
    o = out.strip()
    return o if o and "does not have an IPv4 address" not in o else None


def _dns_nameserver_count():
    out = run(["sh", "-c", "scutil --dns | grep -E 'nameserver\\\\[[0-9]+\\\\]' | wc -l"]) or ""
    try:
        return int(out.strip())
    except Exception:
        return None


def build_health_summary():
    lines = []

    # Disk usage
    used_pct = _disk_used_percent()
    if used_pct is None:
        lines.append("Disk: Unknown usage (df parse failed)")
    else:
        state = "OK" if used_pct < 85 else ("WARN" if used_pct < 95 else "CRIT")
        lines.append(f"Disk: {used_pct}% used (/)	[{state}]")

    # Network default route + IP
    iface = primary_interface()
    ip = _iface_ip(iface) if iface else None
    if not iface:
        lines.append("Network: No default route	[WARN]")
    else:
        if ip:
            lines.append(f"Network: {iface} has IP {ip}	[OK]")
        else:
            lines.append(f"Network: {iface} has no IP	[WARN]")

    # DNS resolvers
    dns_count = _dns_nameserver_count()
    if dns_count is None:
        lines.append("DNS: Unknown (scutil parse failed)")
    else:
        state = "OK" if dns_count >= 1 else "WARN"
        lines.append(f"DNS: {dns_count} resolver(s)	[{state}]")

    # Spotlight indexing
    sp = run(["mdutil", "-s", "/"]) or ""
    if "Indexing enabled" in sp:
        lines.append("Spotlight: Indexing enabled	[OK]")
    elif "Indexing disabled" in sp:
        lines.append("Spotlight: Indexing disabled	[INFO]")
    else:
        lines.append("Spotlight: Unknown status	[INFO]")

    # Time sync (best-effort)
    tsync = run(["systemsetup", "-getusingnetworktime"]) or ""
    if "On" in tsync:
        lines.append("Time Sync: On	[OK]")
    elif "Off" in tsync:
        lines.append("Time Sync: Off	[INFO]")
    else:
        lines.append("Time Sync: Unknown	[INFO]")

    return "\n".join(lines)


def collect_sections():
    sections = []
    header = (
        "macOS Python IT Toolkit Diagnostics\n"
        f"Timestamp: {datetime.now().isoformat()}\n"
        "Tool version: 0.1.0\n"
    )
    sections.append(("Header", header))
    sections.append(("Health Summary", build_health_summary()))
    sections.append(("OS Version", run(["sw_vers"]) or ""))
    sections.append(("Kernel", run(["uname", "-a"]) or ""))
    sections.append(("Uptime", run(["uptime"]) or ""))
    sections.append(("Hardware", run(["system_profiler", "SPHardwareDataType"]) or ""))
    sections.append(("Root Disk Usage", run(["df", "-H", "/"]) or ""))
    sections.append(("Spotlight Indexing", run(["mdutil", "-s", "/"]) or ""))
    sections.append(("Network Interfaces", run(["ifconfig", "-a"]) or ""))
    sections.append(("DNS Summary", run('sh -c \'scutil --dns | sed -n "1,160p"\'') or ""))
    sections.append(("Default Route", run(["route", "-n", "get", "default"]) or ""))
    sections.append(("Wi-Fi (if present)", run("sh -c 'networksetup -listallhardwareports; echo; networksetup -getinfo Wi-Fi || true'") or ""))
    sections.append(("Recent Reboots", run("last reboot | head -n 10") or ""))
    sections.append(("Login Items", run(["osascript", "-e", 'tell application "System Events" to get the name of every login item']) or ""))
    return sections


def write_text_report(outfile, sections):
    with open(outfile, 'w') as f:
        header_title, header_content = sections[0]
        f.write(header_content + "\n")
        for title, content in sections[1:]:
            write_section(f, title, content or "")


def write_html_report(html_path, sections):
    import html
    css = """
    body{font-family:-apple-system,system-ui,BlinkMacSystemFont,Segoe UI,Roboto,Arial,sans-serif;margin:20px;color:#111}
    h1{font-size:20px;margin:0 0 8px}
    .meta{color:#555;margin-bottom:16px}
    .card{border:1px solid #e5e7eb;border-radius:8px;margin-bottom:16px;overflow:hidden}
    .card h2{background:#f9fafb;margin:0;padding:10px 12px;font-size:16px;border-bottom:1px solid #eee}
    .card pre{margin:0;padding:12px;overflow:auto;background:#fff}
    .hs li{margin:4px 0}
    .badge{display:inline-block;font-size:11px;border-radius:10px;padding:2px 8px;margin-left:6px}
    .ok{background:#e6f7ef;color:#046c4e;border:1px solid #a7e7c8}
    .warn{background:#fff7e6;color:#8a5200;border:1px solid #ffd48a}
    .crit{background:#ffebeb;color:#a40000;border:1px solid #ffb3b3}
    .info{background:#eef2ff;color:#3730a3;border:1px solid #c7d2fe}
    """

    _, header_content = sections[0]
    lines = header_content.splitlines()
    title = "macOS Python IT Toolkit"
    meta = html.escape(" | ".join(lines[1:3])) if len(lines) >= 3 else ""

    hs_title, hs_content = sections[1]
    items = []
    for line in (hs_content or "").splitlines():
        cls = 'info'
        if '[CRIT]' in line:
            cls = 'crit'
        elif '[WARN]' in line:
            cls = 'warn'
        elif '[OK]' in line:
            cls = 'ok'
        display = html.escape(line.split('[')[0].strip())
        tag = line[line.rfind('['):].strip('[]') if '[' in line else 'INFO'
        items.append(f"<li>{display} <span class='badge {cls}'>{html.escape(tag)}</span></li>")

    cards = []
    for title2, content in sections[2:]:
        cards.append(f"<div class='card'><h2>{html.escape(title2)}</h2><pre>{html.escape(content or '')}</pre></div>")

    html_doc = f"""
    <!doctype html>
    <html><head><meta charset='utf-8'><title>{html.escape(title)}</title>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <style>{css}</style></head>
    <body>
      <h1>{html.escape(title)}</h1>
      <div class='meta'>{meta}</div>
      <div class='card'>
        <h2>Health Summary</h2>
        <ul class='hs'>
          {''.join(items)}
        </ul>
      </div>
      {''.join(cards)}
    </body></html>
    """
    with open(html_path, 'w') as f:
        f.write(html_doc)


# --- Helpers for fixes ---
def primary_interface():
    out = run(["route", "-n", "get", "default"]) or ""
    for line in out.splitlines():
        if line.strip().startswith("interface:"):
            return line.split(":", 1)[1].strip()
    return ""


def service_for_interface(iface):
    out = run(["networksetup", "-listallhardwareports"]) or ""
    port, dev = None, None
    for line in out.splitlines():
        if line.startswith("Hardware Port:"):
            port = line.split(":", 1)[1].strip()
        elif line.startswith("Device:"):
            dev = line.split(":", 1)[1].strip()
            if dev == iface:
                return port
    return ""


def act_flush_dns():
    print("[action] Flush DNS cache")
    run(["dscacheutil", "-flushcache"], sudo=True)
    run(["killall", "-HUP", "mDNSResponder"], sudo=True)


def act_restart_mdns():
    print("[action] Restart mDNSResponder")
    run(["launchctl", "kickstart", "-k", "system/com.apple.mDNSResponder"], sudo=True)


def act_renew_dhcp():
    iface = primary_interface()
    svc = service_for_interface(iface) if iface else ""
    if not svc:
        print("[warn] Could not determine active network service; skipping DHCP renew")
        return
    print(f"[action] Renew DHCP for service {svc} (iface {iface})")
    run(["networksetup", "-setdhcp", svc])


def act_bounce_iface():
    iface = primary_interface()
    if not iface:
        print("[warn] No primary interface detected; skipping interface bounce")
        return
    print(f"[action] Bounce interface {iface} (down/up)")
    run(["ifconfig", iface, "down"], sudo=True)
    run(["sleep", "2"])  # via shell; harmless if sleep not found
    run(["ifconfig", iface, "up"], sudo=True)


def act_rebuild_spotlight():
    print("[action] Rebuild Spotlight index for /")
    run(["mdutil", "-E", "/"], sudo=True)
    run(["mdutil", "-i", "on", "/"], sudo=True)


def act_ls_rebuild():
    print("[action] Rebuild Launch Services database")
    lsreg = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    run([lsreg, "-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]) 


def act_verify_disk():
    print("[action] Verify system volume")
    run(["diskutil", "verifyVolume", "/"])  # read-only check


SAFE_ACTIONS = {
    "1": ("Flush DNS cache", act_flush_dns),
    "2": ("Restart mDNSResponder", act_restart_mdns),
    "3": ("Renew DHCP on active service", act_renew_dhcp),
    "4": ("Bounce active network interface", act_bounce_iface),
    "5": ("Rebuild Spotlight index", act_rebuild_spotlight),
    "6": ("Rebuild Launch Services DB", act_ls_rebuild),
    "7": ("Verify system volume", act_verify_disk),
}


def menu_apply_actions(log_path):
    print("Safe Remediation Actions (enter numbers separated by commas):")
    for k in sorted(SAFE_ACTIONS.keys(), key=int):
        print(f"  {k}) {SAFE_ACTIONS[k][0]}")
    print("  0) Cancel")
    choice = input("Select actions (e.g., 1,3,5) > ").strip()
    if not choice or choice == "0":
        print("Cancelled.")
        return
    actions = [c.strip() for c in choice.split(',') if c.strip()]
    with open(log_path, 'a') as log:
        log.write(f"# Actions at {datetime.now().isoformat()}\n")
        for a in actions:
            if a in SAFE_ACTIONS:
                name, func = SAFE_ACTIONS[a]
                print(f"[apply] {name}")
                log.write(f"- {name}\n")
                func()
            else:
                print(f"[warn] Unknown selection: {a}")


def cmd_audit(args):
    timestamp = ts()
    diag = os.path.join(LOG_DIR, f"py-diagnostics-{timestamp}.txt")
    html_out = os.path.join(LOG_DIR, f"py-diagnostics-{timestamp}.html")
    sections = collect_sections()
    write_text_report(diag, sections)
    print(f"Diagnostics saved → {diag}")
    if getattr(args, 'html', False):
        write_html_report(html_out, sections)
        print(f"HTML report → {html_out}")
        if args.open:
            run(["open", html_out])
    elif args.open:
        run(["open", diag])


def cmd_fix(args):
    actions_log = os.path.join(LOG_DIR, f"py-actions-{ts()}.log")
    if args.auto:
        print("AUTO: Applying 1,2,3 (DNS flush, restart mDNS, renew DHCP)")
        for key in ["1", "2", "3"]:
            SAFE_ACTIONS[key][1]()
        print(f"Actions complete. Log hint → {actions_log}")
        return
    menu_apply_actions(actions_log)
    print(f"Actions log → {actions_log}")


def build_parser():
    p = argparse.ArgumentParser(description="macOS Python IT Toolkit")
    sub = p.add_subparsers(dest='command')

    pa = sub.add_parser('audit', help='Collect diagnostics and write to logs')
    pa.add_argument('--open', action='store_true', help='Open the diagnostics report')
    pa.add_argument('--html', action='store_true', help='Also write an HTML report')
    pa.set_defaults(func=cmd_audit)

    pf = sub.add_parser('fix', help='Apply safe remediations (interactive by default)')
    pf.add_argument('--auto', action='store_true', help='Run a minimal safe set: 1,2,3')
    pf.set_defaults(func=cmd_fix)

    return p


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    if not getattr(args, 'func', None):
        parser.print_help()
        return 2
    try:
        return args.func(args) or 0
    except KeyboardInterrupt:
        print("Interrupted")
        return 130


if __name__ == '__main__':
    sys.exit(main())


