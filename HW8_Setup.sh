#!/bin/bash
# =====================================================================
# BIT 2554 -- Homework Assignment 8 setup script
# Networking Concepts
#
# Scenario: Blue Ridge Dental Group (BRD). The clinic's IT contractor left a
# small practice network on your VM. Everything below lives INSIDE your VM --
# no packet from this lab ever leaves the machine, so ping, traceroute, and
# nmap against these addresses are safe and allowed.
#
#   Your VM ── brd-lan0 (10.77.14.25/24) ──── brd-gw router (10.77.14.1)
#                                                  │  (10.88.5.1)
#                                                  └── brd-records server (10.88.5.20)
#                                                        open TCP: 21, 22, 443, 5432
#   Your VM ── brd-bkup0 (10.99.2.25/24) ──X  brd-offsite (10.99.2.1)
#              far end of this virtual cable is DOWN -> "Link detected: no"
#
#   Routes added on your VM:
#     10.88.5.0/24  via 10.77.14.1 dev brd-lan0
#     10.120.0.0/20 via 10.99.2.1  dev brd-bkup0   (branch offices, via the dead link)
#
#   Services on your VM (run by systemd, restart automatically, survive a reboot):
#     brd-portal   TCP 0.0.0.0:8443       listens on every IPv4 address
#     brd-db       TCP 10.77.14.25:3306   listens on the lab address only
#     brd-backup   TCP 127.0.0.1:2222     listens on loopback only
#     brd-syslog   UDP 0.0.0.0:514        privileged port (needs root)
#     brd-sync     ESTABLISHED 10.77.14.25:51515 -> 10.88.5.20:443 (fixed client port)
#
# The router and records server are Linux network namespaces (brd-rtr, brd-srv);
# the far end of the backup link sits in namespace brd-off and is left down.
# /etc/hosts gets three names: brd-gw, brd-records, brd-offsite.
#
# CLEANUP: the script also installs /usr/local/bin/hw8-cleanup. The LAST section
# of the homework has students run "sudo hw8-cleanup" once they are completely
# done; it removes everything this script added (the command deletes itself).
# The Exercise 11-10 setup script also checks for leftovers and removes them.
#
# Uses sudo. Idempotent: re-running tears everything down and rebuilds it.
# Every value below is FIXED. Changing any of them changes the answer key --
# re-verify the key after any edit.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ───────────────────
LAN_IF="brd-lan0";   LAN_IP="10.77.14.25";  LAN_MAC="02:b2:d0:4d:0e:19"; LAN_MTU=1450
GW_IP="10.77.14.1"
SRV_NET="10.88.5.0/24"; RTR_SRV_IP="10.88.5.1"; SRV_IP="10.88.5.20"
BK_IF="brd-bkup0";   BK_IP="10.99.2.25";    BK_MAC="02:b2:d0:4d:63:02"
OFF_IP="10.99.2.1"
BRANCH_NET="10.120.0.0/20"
PORTAL_PORT=8443; DB_PORT=3306; BACKUP_PORT=2222; SYSLOG_PORT=514
SYNC_PORT=51515;  SYNC_PEER_PORT=443
RECORDS_PORTS="21 22 443 5432"
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/HW8"
LIB="/usr/local/lib/bit2554-hw8"
LABCMD="/usr/local/sbin/hw8-lab"
CLEANCMD="/usr/local/bin/hw8-cleanup"
UNITDIR="/etc/systemd/system"
NMCONF="/etc/NetworkManager/conf.d/bit2554-hw8.conf"
SERVICES="brd-portal brd-db brd-backup brd-syslog brd-records brd-sync"

if [ -d /run/systemd/system ]; then USE_SYSTEMD=1; else USE_SYSTEMD=0; fi

echo "Setting up Homework 8 (this uses sudo -- enter your password if asked)..."
sudo -v

# ---------------------------------------------------------------------
# 1. Tear down anything left from a previous run
# ---------------------------------------------------------------------
if [ "$USE_SYSTEMD" -eq 1 ]; then
  for s in $SERVICES; do sudo systemctl disable --now "hw8-$s.service" >/dev/null 2>&1 || true; done
  sudo systemctl disable --now hw8-lab.service >/dev/null 2>&1 || true
fi
for s in $SERVICES; do sudo pkill -x "$s" >/dev/null 2>&1 || true; done
[ -x "$LABCMD" ] && sudo "$LABCMD" down >/dev/null 2>&1 || true
sudo rm -rf "$LIB"
sudo rm -f "$LABCMD" "$UNITDIR"/hw8-*.service "$CLEANCMD"
sudo sed -i '/# BIT2554-HW8 BEGIN/,/# BIT2554-HW8 END/d' /etc/hosts
rm -rf "$BASE"

# ---------------------------------------------------------------------
# 2. Keep NetworkManager's hands off the lab interfaces (if it is installed)
# ---------------------------------------------------------------------
if [ -d /etc/NetworkManager/conf.d ]; then
  printf '[keyfile]\nunmanaged-devices=interface-name:brd-*\n' | sudo tee "$NMCONF" >/dev/null
  sudo nmcli general reload >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------
# 3. Lab network builder: /usr/local/sbin/hw8-lab up|down
# ---------------------------------------------------------------------
sudo tee "$LABCMD" >/dev/null <<EOF
#!/bin/bash
# BIT 2554 HW8 -- builds (up) or removes (down) the Blue Ridge Dental practice network.
LAN_IF=$LAN_IF; LAN_IP=$LAN_IP; LAN_MAC=$LAN_MAC; LAN_MTU=$LAN_MTU; GW_IP=$GW_IP
SRV_NET=$SRV_NET; RTR_SRV_IP=$RTR_SRV_IP; SRV_IP=$SRV_IP
BK_IF=$BK_IF; BK_IP=$BK_IP; BK_MAC=$BK_MAC; OFF_IP=$OFF_IP; BRANCH_NET=$BRANCH_NET
EOF
sudo tee -a "$LABCMD" >/dev/null <<'EOF'
down() {
  ip link del "$LAN_IF" 2>/dev/null || true
  ip link del "$BK_IF"  2>/dev/null || true
  for ns in brd-rtr brd-srv brd-off; do ip netns del "$ns" 2>/dev/null || true; done
  return 0
}
up() {
  set -e
  down
  modprobe veth 2>/dev/null || true
  ip netns add brd-rtr; ip netns add brd-srv; ip netns add brd-off
  for ns in brd-rtr brd-srv brd-off; do ip -n "$ns" link set lo up; done

  # Clinic LAN link: your VM <-> router
  ip link add "$LAN_IF" type veth peer name rtr-lan netns brd-rtr
  ip link set "$LAN_IF" address "$LAN_MAC" mtu "$LAN_MTU"
  sysctl -qw "net.ipv6.conf.$LAN_IF.disable_ipv6=1" 2>/dev/null || true
  ip addr add "$LAN_IP/24" brd + dev "$LAN_IF"
  ip link set "$LAN_IF" up
  ip -n brd-rtr link set rtr-lan mtu "$LAN_MTU"
  ip -n brd-rtr addr add "$GW_IP/24" dev rtr-lan
  ip -n brd-rtr link set rtr-lan up

  # Router <-> records server
  ip -n brd-rtr link add rtr-srv type veth peer name srv0 netns brd-srv
  ip -n brd-rtr addr add "$RTR_SRV_IP/24" dev rtr-srv
  ip -n brd-rtr link set rtr-srv up
  ip -n brd-srv addr add "$SRV_IP/24" dev srv0
  ip -n brd-srv link set srv0 up
  ip -n brd-srv route add default via "$RTR_SRV_IP"
  ip netns exec brd-rtr sysctl -qw net.ipv4.ip_forward=1 net.ipv4.icmp_ratelimit=0
  ip netns exec brd-srv sysctl -qw net.ipv4.icmp_ratelimit=0

  # Backup link to the off-site office: the far end is left DOWN (no carrier)
  ip link add "$BK_IF" type veth peer name off-wan netns brd-off
  ip link set "$BK_IF" address "$BK_MAC"
  sysctl -qw "net.ipv6.conf.$BK_IF.disable_ipv6=1" 2>/dev/null || true
  ip addr add "$BK_IP/24" brd + dev "$BK_IF"
  ip link set "$BK_IF" up
  ip -n brd-off addr add "$OFF_IP/24" dev off-wan

  # Static routes on your VM
  ip route add "$SRV_NET" via "$GW_IP" dev "$LAN_IF"
  ip route add "$BRANCH_NET" via "$OFF_IP" dev "$BK_IF"
}
case "$1" in
  up)   up ;;
  down) down ;;
  *)    echo "Usage: hw8-lab up|down"; exit 2 ;;
esac
EOF
sudo chmod 755 "$LABCMD"

# ---------------------------------------------------------------------
# 4. Clinic programs. One Python file, installed under six names; the name it
#    is started as decides what it does (and is the name ss -p reports).
# ---------------------------------------------------------------------
sudo mkdir -p "$LIB"
sudo tee "$LIB/brd-portal" >/dev/null <<EOF
#!/usr/bin/python3
# BIT 2554 HW8 -- Blue Ridge Dental lab service (behavior depends on program name)
ROLES = {
    "brd-portal":  [("tcp", "0.0.0.0", $PORTAL_PORT)],
    "brd-db":      [("tcp", "$LAN_IP", $DB_PORT)],
    "brd-backup":  [("tcp", "127.0.0.1", $BACKUP_PORT)],
    "brd-syslog":  [("udp", "0.0.0.0", $SYSLOG_PORT)],
    "brd-records": [("tcp", "0.0.0.0", p) for p in ($(echo $RECORDS_PORTS | tr ' ' ','))],
}
SYNC = ("$LAN_IP", $SYNC_PORT, "$SRV_IP", $SYNC_PEER_PORT)
EOF
sudo tee -a "$LIB/brd-portal" >/dev/null <<'EOF'
import os, socket, sys, threading, time

def hold(conn):
    try:
        while conn.recv(1024):
            pass
    except OSError:
        pass
    finally:
        conn.close()

def tcp_server(addr, port):
    while True:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind((addr, port))
            s.listen(16)
            break
        except OSError:
            time.sleep(2)
    while True:
        conn, _ = s.accept()
        threading.Thread(target=hold, args=(conn,), daemon=True).start()

def udp_server(addr, port):
    while True:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.bind((addr, port))
            break
        except OSError:
            time.sleep(2)
    while True:
        s.recvfrom(2048)

def sync_client():
    laddr, lport, raddr, rport = SYNC
    while True:
        try:
            c = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            c.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            c.bind((laddr, lport))
            c.connect((raddr, rport))
            while c.recv(1024):
                pass
        except OSError:
            pass
        try:
            c.close()
        except Exception:
            pass
        time.sleep(2)

name = os.path.basename(sys.argv[0])
if name == "brd-sync":
    sync_client()
for proto, addr, port in ROLES[name]:
    fn = tcp_server if proto == "tcp" else udp_server
    threading.Thread(target=fn, args=(addr, port), daemon=True).start()
while True:
    time.sleep(3600)
EOF
for s in $SERVICES; do
  [ "$s" = brd-portal ] || sudo cp "$LIB/brd-portal" "$LIB/$s"
done
sudo chmod 755 "$LIB"/*

# ---------------------------------------------------------------------
# 5. Host names for the lab devices
# ---------------------------------------------------------------------
sudo tee -a /etc/hosts >/dev/null <<EOF
# BIT2554-HW8 BEGIN (Blue Ridge Dental practice network -- removed when setup re-runs)
$GW_IP	brd-gw
$SRV_IP	brd-records
$OFF_IP	brd-offsite
# BIT2554-HW8 END
EOF

# ---------------------------------------------------------------------
# 5b. Cleanup command: sudo hw8-cleanup (last step of the homework)
# ---------------------------------------------------------------------
sudo tee "$CLEANCMD" >/dev/null <<'CLEANUP_EOF'
#!/bin/bash
# BIT 2554 HW8 -- removes the Blue Ridge Dental practice network from this VM.
# Only run this when you are completely done with Homework 8.
# Safe to run more than once. Leaves ~/BIT2554/HW8 (your files) alone.
if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi

SERVICES="brd-portal brd-db brd-backup brd-syslog brd-records brd-sync"
echo "Removing the HW8 practice network..."

# 1. Stop and disable the clinic services and the lab network service
if [ -d /run/systemd/system ]; then
  for s in $SERVICES; do systemctl disable --now "hw8-$s.service" >/dev/null 2>&1; done
  systemctl disable --now hw8-lab.service >/dev/null 2>&1
fi
for s in $SERVICES; do pkill -x "$s" >/dev/null 2>&1; done

# 2. Remove the interfaces and namespaces (their routes go with them)
ip link del brd-lan0  >/dev/null 2>&1
ip link del brd-bkup0 >/dev/null 2>&1
for ns in brd-rtr brd-srv brd-off; do ip netns del "$ns" >/dev/null 2>&1; done

# 3. Remove the installed files and the /etc/hosts names
rm -f /etc/systemd/system/hw8-*.service
[ -d /run/systemd/system ] && systemctl daemon-reload >/dev/null 2>&1
rm -rf /usr/local/lib/bit2554-hw8 /usr/local/sbin/hw8-lab
if [ -f /etc/NetworkManager/conf.d/bit2554-hw8.conf ]; then
  rm -f /etc/NetworkManager/conf.d/bit2554-hw8.conf
  nmcli general reload >/dev/null 2>&1
fi
sed -i '/# BIT2554-HW8 BEGIN/,/# BIT2554-HW8 END/d' /etc/hosts

# 4. Check that nothing is left
sleep 1
left=""
for i in brd-lan0 brd-bkup0; do ip link show "$i" >/dev/null 2>&1 && left="$left $i"; done
for ns in brd-rtr brd-srv brd-off; do ip netns list 2>/dev/null | grep -qw "$ns" && left="$left netns:$ns"; done
for s in $SERVICES; do pgrep -x "$s" >/dev/null 2>&1 && left="$left $s"; done
grep -q 'BIT2554-HW8' /etc/hosts && left="$left /etc/hosts"

if [ -n "$left" ]; then
  echo "⚠ CLEANUP INCOMPLETE -- still found:$left"
  echo "  Run sudo hw8-cleanup again. If this message repeats, contact your instructor."
  exit 1
fi
rm -f /usr/local/bin/hw8-cleanup
echo "✅ CLEANUP COMPLETE -- the HW8 practice network has been removed."
CLEANUP_EOF
sudo chmod 755 "$CLEANCMD"

# ---------------------------------------------------------------------
# 6. Start everything (systemd units so the lab survives a reboot)
# ---------------------------------------------------------------------
if [ "$USE_SYSTEMD" -eq 1 ]; then
  sudo tee "$UNITDIR/hw8-lab.service" >/dev/null <<EOF
[Unit]
Description=BIT 2554 HW8 practice network
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$LABCMD up
ExecStop=$LABCMD down

[Install]
WantedBy=multi-user.target
EOF
  for s in $SERVICES; do
    if [ "$s" = brd-records ]; then EXEC="/usr/sbin/ip netns exec brd-srv $LIB/$s"; else EXEC="$LIB/$s"; fi
    sudo tee "$UNITDIR/hw8-$s.service" >/dev/null <<EOF
[Unit]
Description=BIT 2554 HW8 Blue Ridge Dental $s
Requires=hw8-lab.service
After=hw8-lab.service
PartOf=hw8-lab.service

[Service]
ExecStart=$EXEC
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
  done
  sudo systemctl daemon-reload
  sudo systemctl enable --now hw8-lab.service >/dev/null 2>&1
  for s in $SERVICES; do sudo systemctl enable --now "hw8-$s.service" >/dev/null 2>&1; done
else
  # No systemd (not expected on the Cyber Range): start directly; does not survive a reboot.
  sudo "$LABCMD" up
  for s in $SERVICES; do
    if [ "$s" = brd-records ]; then
      sudo setsid ip netns exec brd-srv "$LIB/$s" </dev/null >/dev/null 2>&1 &
    else
      sudo setsid "$LIB/$s" </dev/null >/dev/null 2>&1 &
    fi
  done
fi

# ---------------------------------------------------------------------
# 7. Check that the lab really came up before declaring success
# ---------------------------------------------------------------------
ok=0
for i in $(seq 1 15); do
  if ss -tln | grep -q "0.0.0.0:$PORTAL_PORT " &&
     ss -tln | grep -q "$LAN_IP:$DB_PORT " &&
     ss -tln | grep -q "127.0.0.1:$BACKUP_PORT " &&
     ss -uln | grep -q "0.0.0.0:$SYSLOG_PORT " &&
     ss -tn  | grep -q "$LAN_IP:$SYNC_PORT .*$SRV_IP:$SYNC_PEER_PORT"; then
    ok=1; break
  fi
  sleep 1
done
if [ "$ok" -ne 1 ] || ! ping -c 1 -W 2 "$SRV_IP" >/dev/null 2>&1; then
  echo ""
  echo "❌ SETUP FAILED -- the practice network did not start. Re-run the setup command."
  echo "   If it fails again, take a screenshot of this window and contact your instructor."
  exit 1
fi

# ---------------------------------------------------------------------
# 8. Student working directory + IT hand-off note
# ---------------------------------------------------------------------
mkdir -p "$BASE"
cat > "$BASE/it_handoff.txt" <<EOF
Blue Ridge Dental Group -- IT Hand-off Note
--------------------------------------------
Our contractor connected this workstation to the clinic's practice network.

  Interfaces on this workstation:
    $LAN_IF   clinic LAN link
    $BK_IF  backup link to the off-site office

  Other devices:
    brd-gw        clinic router / gateway      $GW_IP
    brd-records   patient records server       $SRV_IP
    brd-offsite   off-site office router       $OFF_IP

  Clinic programs running on this workstation:
    brd-portal, brd-db, brd-backup, brd-syslog, brd-sync

The contractor did not leave any other documentation. Use your networking
commands to find out how everything is configured.
EOF
chmod 644 "$BASE/it_handoff.txt"

# ---------------------------------------------------------------------
# 9. Confirmation banner
# ---------------------------------------------------------------------
echo ""
echo "==============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/HW8"
echo "==============================================================="
