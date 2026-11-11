#!/bin/bash
# =====================================================================
# BIT 2554 -- Homework Assignment 9 setup script
# Securing Linux and Security Tools
#
# Scenario: Tidewater Marine Supply (TMS), a boat-parts distributor in
# Norfolk. Your VM plays the role of workstation tms-ws14. The company's
# server, tms-srv02, was reviewed by a contractor who left copies of its
# files and logs. You finish the security review.
#
# REAL changes to your VM (all removed by "sudo hw9-cleanup", the last step):
#   Practice accounts (no home folders):
#     pcarter    UID 2410  /bin/bash          (active employee, IT admin)
#     dsimmons   UID 2411  /bin/bash          (LEFT the company 10/30/2026;
#                                              password set -> passwd -S shows P)
#     rgalloway  UID 2412  /bin/bash          (warehouse)
#     tmsbackup  UID 2413  /usr/sbin/nologin  (service account)
#   Practice services (systemd units, restart automatically, survive a reboot):
#     tms-inventory.service -> program tms-inventory  TCP 0.0.0.0:8081 (APPROVED)
#     tms-telnet.service    -> program tms-telnetd    TCP 0.0.0.0:2323 (remove)
#     tms-ftp.service       -> program tms-ftpd       TCP 0.0.0.0:2121 (remove)
#   Command: /usr/local/bin/hw9-cleanup
#   Students only LOOK at the services in HW9 (nmap, ss, systemctl status);
#   nothing is stopped or disabled until the cleanup step.
#
# Files (copies -- safe to change) under ~/BIT2554/HW9:
#   hr/departures.txt                     HR separations list
#   review/approved_services.txt          which TMS programs may run
#   review/sshd_config                    copy of the server's sshd_config
#   srv/                                  copy of the server's folders
#                                         (SUID and world-writable files)
#   logs/auth.log                         server auth log (Nov 7)
#   logs/fail2ban/jail.local              server fail2ban settings
#   logs/lynis-report.dat                 server Lynis report
#
# FIRST it removes leftovers from Homework 8 and Exercise 11-10.
# Uses sudo. Idempotent: re-running removes and rebuilds EVERYTHING
# (accounts, services, and files go back to their starting state).
# Every value below is FIXED. Changing any of them changes the answer key --
# re-verify the key (run each question's commands) after any edit.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# =====================================================================
# BIT 2554 -- HW8 leftover check
#
# Looks for anything HW8_Setup.sh left behind (a student who never ran
# "sudo hw8-cleanup") and removes it. If nothing is left, it prints one line
# and does not ask for sudo.
# Written so it never trips set -e. Leaves ~/BIT2554/HW8 (student files) alone.
# =====================================================================
hw8_leftovers() {
  local found=""
  ip link show brd-lan0  >/dev/null 2>&1 && found="$found brd-lan0"
  ip link show brd-bkup0 >/dev/null 2>&1 && found="$found brd-bkup0"
  ip netns list 2>/dev/null | grep -qE '^brd-(rtr|srv|off)\b' && found="$found namespaces"
  ls /etc/systemd/system/hw8-*.service >/dev/null 2>&1 && found="$found services"
  [ -e /usr/local/lib/bit2554-hw8 ] || [ -e /usr/local/sbin/hw8-lab ] || [ -e /usr/local/bin/hw8-cleanup ] \
    && found="$found programs"
  grep -q 'BIT2554-HW8' /etc/hosts 2>/dev/null && found="$found hosts-entries"
  [ -e /etc/NetworkManager/conf.d/bit2554-hw8.conf ] && found="$found nm-config"
  echo "$found"
}

HW8_LEFT="$(hw8_leftovers)"
if [ -z "$HW8_LEFT" ]; then
  echo "Checked for Homework 8 leftovers: none found."
else
  echo "Homework 8 practice network is still installed ($HW8_LEFT ) -- removing it now."
  echo "(This uses sudo -- enter your password if asked.)"
  sudo bash <<'HW8_CLEAN_EOF' || true
SERVICES="brd-portal brd-db brd-backup brd-syslog brd-records brd-sync"
if [ -d /run/systemd/system ]; then
  for s in $SERVICES; do systemctl disable --now "hw8-$s.service" >/dev/null 2>&1; done
  systemctl disable --now hw8-lab.service >/dev/null 2>&1
fi
for s in $SERVICES; do pkill -x "$s" >/dev/null 2>&1; done
ip link del brd-lan0  >/dev/null 2>&1
ip link del brd-bkup0 >/dev/null 2>&1
for ns in brd-rtr brd-srv brd-off; do ip netns del "$ns" >/dev/null 2>&1; done
rm -f /etc/systemd/system/hw8-*.service
[ -d /run/systemd/system ] && systemctl daemon-reload >/dev/null 2>&1
rm -rf /usr/local/lib/bit2554-hw8 /usr/local/sbin/hw8-lab /usr/local/bin/hw8-cleanup
if [ -f /etc/NetworkManager/conf.d/bit2554-hw8.conf ]; then
  rm -f /etc/NetworkManager/conf.d/bit2554-hw8.conf
  nmcli general reload >/dev/null 2>&1
fi
sed -i '/# BIT2554-HW8 BEGIN/,/# BIT2554-HW8 END/d' /etc/hosts
exit 0
HW8_CLEAN_EOF
  sleep 1
  HW8_LEFT="$(hw8_leftovers)"
  if [ -n "$HW8_LEFT" ]; then
    echo "❌ Could not remove the Homework 8 practice network ($HW8_LEFT )."
    echo "   Take a screenshot of this window and contact your instructor."
    exit 1
  fi
  echo "Homework 8 practice network removed."
fi
# ── end of HW8 leftover check ────────────────────────────────────────

# ── FIXED VALUES (update this block each semester) ───────────────────
COMPANY="Tidewater Marine Supply"
SERVER="tms-srv02"
USERS="pcarter dsimmons rgalloway tmsbackup"   # created in this order
DS_PW="Harbor#2411"                # dsimmons's password (never given to students)
PW_DATE="2026-10-01"               # fixed "last password change" date
INV_PORT=8081; TELNET_PORT=2323; FTP_PORT=2121
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/HW9"
LIB="/usr/local/lib/bit2554-hw9"
UNITDIR="/etc/systemd/system"
CLEANCMD="/usr/local/bin/hw9-cleanup"
UNITS="tms-inventory tms-telnet tms-ftp"
PROGS="tms-inventory tms-telnetd tms-ftpd"

if [ -d /run/systemd/system ]; then USE_SYSTEMD=1; else USE_SYSTEMD=0; fi

echo "Setting up Homework 9 (this uses sudo -- enter your password if asked)..."
sudo -v

# Exercise 11-10 leftover: the mkeller practice account (if the student skipped
# the cleanup step in Section 2).
if [ -x /usr/local/bin/ex11-10-cleanup ]; then
  echo "Removing the Exercise 11-10 practice account that was left behind..."
  sudo /usr/local/bin/ex11-10-cleanup >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------
# 1. Remove anything left from an earlier run of this script
# ---------------------------------------------------------------------
if [ "$USE_SYSTEMD" -eq 1 ]; then
  for u in $UNITS; do sudo systemctl disable --now "$u.service" >/dev/null 2>&1 || true; done
fi
for p in $PROGS; do sudo pkill -x "$p" >/dev/null 2>&1 || true; done
sudo rm -f "$UNITDIR"/tms-inventory.service "$UNITDIR"/tms-telnet.service "$UNITDIR"/tms-ftp.service
[ "$USE_SYSTEMD" -eq 1 ] && sudo systemctl daemon-reload
sudo rm -rf "$LIB"
sudo rm -f "$CLEANCMD" /usr/local/bin/hw9-catchup
uid=2410
for u in $USERS; do
  owner="$(getent passwd "$uid" | cut -d: -f1 || true)"
  if [ -n "$owner" ] && [ "$owner" != "$u" ]; then
    echo "❌ SETUP FAILED -- UID $uid is already used by the account $owner."
    echo "   Take a screenshot of this window and contact your instructor."
    exit 1
  fi
  getent passwd "$u" >/dev/null 2>&1 && sudo userdel "$u" >/dev/null 2>&1 || true
  getent group  "$u" >/dev/null 2>&1 && sudo groupdel "$u" >/dev/null 2>&1 || true
  uid=$((uid + 1))
done
rm -rf "$BASE"

# Make sure the ports are free (something other than this homework using them)
for port in $INV_PORT $TELNET_PORT $FTP_PORT; do
  if ss -tln | grep -q ":$port "; then
    sleep 2
    if ss -tln | grep -q ":$port "; then
      echo "❌ SETUP FAILED -- TCP port $port is already in use on this VM."
      echo "   Take a screenshot of this window and contact your instructor."
      exit 1
    fi
  fi
done

# ---------------------------------------------------------------------
# 2. Practice accounts (Section 1)
# ---------------------------------------------------------------------
sudo useradd -u 2410 -M -c "Pat Carter - Tidewater IT"         -s /bin/bash         pcarter
sudo useradd -u 2411 -M -c "Dana Simmons - Tidewater Sales"    -s /bin/bash         dsimmons
sudo useradd -u 2412 -M -c "Rob Galloway - Tidewater Warehouse" -s /bin/bash        rgalloway
sudo useradd -u 2413 -M -c "Tidewater Backup Service"          -s /usr/sbin/nologin tmsbackup
echo "dsimmons:$DS_PW" | sudo chpasswd
sudo chage -d "$PW_DATE" -m 0 -M 99999 -W 7 -I -1 dsimmons

# ---------------------------------------------------------------------
# 3. Practice services. One Python file, installed under three names; the
#    name it is started as decides its port (and is the name ss -p shows).
# ---------------------------------------------------------------------
sudo mkdir -p "$LIB"
sudo tee "$LIB/tms-inventory" >/dev/null <<EOF
#!/usr/bin/python3
# BIT 2554 HW9 -- Tidewater Marine Supply practice service (port depends on program name)
PORTS = {"tms-inventory": $INV_PORT, "tms-telnetd": $TELNET_PORT, "tms-ftpd": $FTP_PORT}
EOF
sudo tee -a "$LIB/tms-inventory" >/dev/null <<'EOF'
import os, socket, sys, threading, time

def hold(conn):
    try:
        while conn.recv(1024):
            pass
    except OSError:
        pass
    finally:
        conn.close()

name = os.path.basename(sys.argv[0])
port = PORTS[name]
while True:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("0.0.0.0", port))
        s.listen(16)
        break
    except OSError:
        time.sleep(2)
while True:
    conn, _ = s.accept()
    threading.Thread(target=hold, args=(conn,), daemon=True).start()
EOF
sudo cp "$LIB/tms-inventory" "$LIB/tms-telnetd"
sudo cp "$LIB/tms-inventory" "$LIB/tms-ftpd"
sudo chmod 755 "$LIB"/*

if [ "$USE_SYSTEMD" -eq 1 ]; then
  mkunit() {  # unit-name program description
    sudo tee "$UNITDIR/$1.service" >/dev/null <<EOF
[Unit]
Description=$COMPANY -- $3
After=network.target

[Service]
ExecStart=$LIB/$2
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
  }
  mkunit tms-inventory tms-inventory "inventory web app"
  mkunit tms-telnet    tms-telnetd   "remote console (telnet)"
  mkunit tms-ftp       tms-ftpd      "file drop (FTP)"
  sudo systemctl daemon-reload
  for u in $UNITS; do sudo systemctl enable --now "$u.service" >/dev/null 2>&1; done
else
  # No systemd (not expected on the Cyber Range): start directly; does not survive a reboot.
  for p in $PROGS; do sudo setsid "$LIB/$p" </dev/null >/dev/null 2>&1 & done
fi

# ---------------------------------------------------------------------
# 4. Cleanup command: sudo hw9-cleanup (last step of the homework)
# ---------------------------------------------------------------------
sudo tee "$CLEANCMD" >/dev/null <<'CLEANUP_EOF'
#!/bin/bash
# BIT 2554 HW9 -- removes the Tidewater practice accounts and services from this VM.
# Only run this when you are completely done with Homework 9.
# Safe to run more than once. Leaves ~/BIT2554/HW9 (your files) alone.
if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi

USERS="pcarter dsimmons rgalloway tmsbackup"
UNITS="tms-inventory tms-telnet tms-ftp"
PROGS="tms-inventory tms-telnetd tms-ftpd"
echo "Removing the HW9 practice accounts and services..."

if [ -d /run/systemd/system ]; then
  for u in $UNITS; do systemctl disable --now "$u.service" >/dev/null 2>&1; done
fi
for p in $PROGS; do pkill -x "$p" >/dev/null 2>&1; done
for u in $UNITS; do rm -f "/etc/systemd/system/$u.service"; done
[ -d /run/systemd/system ] && systemctl daemon-reload >/dev/null 2>&1
rm -rf /usr/local/lib/bit2554-hw9
for u in $USERS; do
  getent passwd "$u" >/dev/null 2>&1 && userdel "$u" >/dev/null 2>&1
  getent group  "$u" >/dev/null 2>&1 && groupdel "$u" >/dev/null 2>&1
done

sleep 1
left=""
for u in $USERS; do getent passwd "$u" >/dev/null 2>&1 && left="$left $u"; done
for p in $PROGS; do pgrep -x "$p" >/dev/null 2>&1 && left="$left $p"; done
for u in $UNITS; do [ -e "/etc/systemd/system/$u.service" ] && left="$left $u.service"; done
if [ -n "$left" ]; then
  echo "⚠ CLEANUP INCOMPLETE -- still found:$left"
  echo "  Run sudo hw9-cleanup again. If this message repeats, contact your instructor."
  exit 1
fi
rm -f /usr/local/bin/hw9-cleanup
echo "✅ CLEANUP COMPLETE -- the HW9 practice accounts and services have been removed."
CLEANUP_EOF
sudo chmod 755 "$CLEANCMD"

# ---------------------------------------------------------------------
# 6. Folders
# ---------------------------------------------------------------------
mkdir -p "$BASE/hr" "$BASE/review" "$BASE/logs/fail2ban"
S="$BASE/srv"
mkdir -p "$S/usr/bin" "$S/opt/tms/bin" "$S/var/www/html" "$S/var/tmp/.x11-cache" "$S/tmp"

# ---------------------------------------------------------------------
# 7. Section 1 -- HR separations list
#    Of the three people listed, only dsimmons has an account on this VM.
# ---------------------------------------------------------------------
cat > "$BASE/hr/departures.txt" <<EOF
$COMPANY -- HR Separations Report (July - November 2026)
Prepared by Human Resources. IT: please remove access for everyone listed.

Name            Username    Department   Last Day
Jo Hargrove     jhargrove   Accounting   09/12/2026
Dana Simmons    dsimmons    Sales        10/30/2026
Luis Ortega     lortega     Warehouse    11/02/2026
EOF

# ---------------------------------------------------------------------
# 8. Section 2 -- the server folder copy
#    SUID (-perm -4000 -type f): 4 = passwd, sudo, chsh, and
#          var/tmp/.x11-cache/python3 (hidden folder -- the back door)
#    SGID only (NOT matched by -4000): usr/bin/wall
#    World-writable files (-perm -0002 -type f): 2 =
#          opt/tms/bin/nightly_sync.sh (757) and var/www/html/price_feed.csv (666)
#    Decoy: tmp is 1777 (a folder)
# ---------------------------------------------------------------------
for f in usr/bin/passwd usr/bin/sudo usr/bin/chsh usr/bin/wall usr/bin/ls \
         var/tmp/.x11-cache/python3 opt/tms/bin/nightly_sync.sh opt/tms/bin/label_print.sh; do
  echo "# Homework 9 practice file -- not a real program" > "$S/$f"
done
echo "sku,price" > "$S/var/www/html/price_feed.csv"
echo "<h1>Tidewater Marine Supply</h1>" > "$S/var/www/html/index.html"
chmod 4755 "$S/usr/bin/passwd" "$S/usr/bin/sudo" "$S/usr/bin/chsh" "$S/var/tmp/.x11-cache/python3"
chmod 2755 "$S/usr/bin/wall"
chmod 755  "$S/usr/bin/ls" "$S/opt/tms/bin/label_print.sh"
chmod 757  "$S/opt/tms/bin/nightly_sync.sh"
chmod 666  "$S/var/www/html/price_feed.csv"
chmod 644  "$S/var/www/html/index.html"
chmod 1777 "$S/tmp"

# ---------------------------------------------------------------------
# 9. Section 3 -- approved programs list
# ---------------------------------------------------------------------
cat > "$BASE/review/approved_services.txt" <<EOF
$COMPANY -- Approved Programs for Workstation tms-ws14
Policy: any Tidewater program that is not APPROVED must be stopped
and kept from starting at boot.

Service          Status
tms-inventory    APPROVED   (inventory web app)
tms-telnet       NOT APPROVED -- telnet sends passwords in plain text
tms-ftp          NOT APPROVED -- replaced by SFTP in 2025
EOF

# ---------------------------------------------------------------------
# 10. Section 7 -- SSH configuration copy (students back it up, then edit it)
#     Active lines: PermitRootLogin yes, MaxAuthTries 6
# ---------------------------------------------------------------------
cat > "$BASE/review/sshd_config" <<EOF
# $COMPANY -- sshd_config (copy from $SERVER)

Include /etc/ssh/sshd_config.d/*.conf

#Port 22
#AddressFamily any
#ListenAddress 0.0.0.0

# Authentication:

#LoginGraceTime 2m
#PermitRootLogin prohibit-password
PermitRootLogin yes
#StrictModes yes
MaxAuthTries 6
#MaxSessions 10

PasswordAuthentication yes
KbdInteractiveAuthentication no
UsePAM yes

X11Forwarding yes
PrintMotd no
EOF

# ---------------------------------------------------------------------
# 11. Sections 4-5 -- auth.log copy (Nov 7) and fail2ban settings
#     "Failed password" lines: 11 total
#       198.51.100.23  6 (08:14:02 - 08:15:31, about 90 seconds)  -> banned
#       192.0.2.77     3 (09:02:44, 09:41:10, 10:27:53)           -> NOT banned
#       203.0.113.45   2 (21:47:05, 21:47:19), then Accepted dsimmons -> NOT banned
#     "Accepted password" lines: 2 (pcarter 07:58:12, dsimmons 21:47:36)
#     sshd jail: maxretry 3, bantime 1h, findtime 10m (inherited from DEFAULT)
# ---------------------------------------------------------------------
cat > "$BASE/logs/auth.log" <<EOF
Nov  7 07:58:12 $SERVER sshd[2101]: Accepted password for pcarter from 10.40.1.22 port 50112 ssh2
Nov  7 07:58:12 $SERVER sshd[2101]: pam_unix(sshd:session): session opened for user pcarter(uid=2410) by (uid=0)
Nov  7 07:58:13 $SERVER systemd-logind[588]: New session 7 of user pcarter.
Nov  7 08:03:27 $SERVER sudo:  pcarter : TTY=pts/0 ; PWD=/home/pcarter ; USER=root ; COMMAND=/usr/bin/systemctl status tms-inventory
Nov  7 08:14:02 $SERVER sshd[2187]: Failed password for root from 198.51.100.23 port 41001 ssh2
Nov  7 08:14:19 $SERVER sshd[2187]: Failed password for root from 198.51.100.23 port 41003 ssh2
Nov  7 08:14:37 $SERVER sshd[2190]: Failed password for invalid user admin from 198.51.100.23 port 41007 ssh2
Nov  7 08:14:55 $SERVER sshd[2190]: Failed password for root from 198.51.100.23 port 41012 ssh2
Nov  7 08:15:12 $SERVER sshd[2194]: Failed password for invalid user oracle from 198.51.100.23 port 41016 ssh2
Nov  7 08:15:31 $SERVER sshd[2194]: Failed password for root from 198.51.100.23 port 41020 ssh2
Nov  7 08:15:31 $SERVER sshd[2194]: Disconnecting authenticating user root 198.51.100.23 port 41020: Too many authentication failures [preauth]
Nov  7 09:02:44 $SERVER sshd[2231]: Failed password for pcarter from 192.0.2.77 port 52210 ssh2
Nov  7 09:41:10 $SERVER sshd[2264]: Failed password for pcarter from 192.0.2.77 port 52288 ssh2
Nov  7 10:27:53 $SERVER sshd[2302]: Failed password for pcarter from 192.0.2.77 port 52341 ssh2
Nov  7 12:30:01 $SERVER CRON[2350]: pam_unix(cron:session): session opened for user root(uid=0) by (uid=0)
Nov  7 12:30:01 $SERVER CRON[2350]: pam_unix(cron:session): session closed for user root
Nov  7 16:45:09 $SERVER sudo:  pcarter : TTY=pts/0 ; PWD=/home/pcarter ; USER=root ; COMMAND=/usr/bin/apt update
Nov  7 21:47:05 $SERVER sshd[2518]: Failed password for dsimmons from 203.0.113.45 port 60114 ssh2
Nov  7 21:47:19 $SERVER sshd[2518]: Failed password for dsimmons from 203.0.113.45 port 60114 ssh2
Nov  7 21:47:36 $SERVER sshd[2518]: Accepted password for dsimmons from 203.0.113.45 port 60114 ssh2
Nov  7 21:47:36 $SERVER sshd[2518]: pam_unix(sshd:session): session opened for user dsimmons(uid=2411) by (uid=0)
Nov  7 21:47:37 $SERVER systemd-logind[588]: New session 12 of user dsimmons.
Nov  7 22:31:50 $SERVER sshd[2518]: pam_unix(sshd:session): session closed for user dsimmons
EOF

cat > "$BASE/logs/fail2ban/jail.local" <<EOF
# $COMPANY -- fail2ban settings (copy from $SERVER)
# Settings in [DEFAULT] apply to every jail unless the jail sets its own value.

[DEFAULT]
bantime  = 10m
findtime = 10m
maxretry = 5

[sshd]
enabled  = true
port     = ssh
maxretry = 3
bantime  = 1h
EOF

# ---------------------------------------------------------------------
# 12. Section 6 -- Lynis report copy
#     hardening_index=58, lynis_tests_done=262
#     warning lines: 3 (PKGS-7392, AUTH-9283, NETW-2705)
#     suggestion lines: 8; SSH-7408 lines: 4
#       (PermitRootLogin YES->NO, MaxAuthTries 6->3, X11Forwarding YES->NO,
#        AllowTcpForwarding YES->NO)
#     The word "warning" appears ONLY on the 3 warning lines.
# ---------------------------------------------------------------------
cat > "$BASE/logs/lynis-report.dat" <<EOF
# Lynis Report
report_version_major=1
report_version_minor=0
report_datetime_start=2026-11-08 07:42:10
auditor=Tidewater IT
lynis_version=3.1.2
os=Linux
os_name=Kali GNU/Linux
hostname=$SERVER
plugins_enabled=0
suggestion[]=AUTH-9230|Configure password hashing rounds in /etc/login.defs|-|-|
suggestion[]=AUTH-9262|Install a PAM module for password strength testing like pam_cracklib or pam_passwdqc|-|-|
warning[]=AUTH-9283|Found one or more accounts without a password|tmsbackup|-|
suggestion[]=PKGS-7346|Purge old/removed packages (4 found) with aptitude purge or dpkg --purge command.|-|-|
warning[]=PKGS-7392|Found one or more vulnerable packages.|-|-|
suggestion[]=PKGS-7392|Update your system with apt-get update, apt-get upgrade, apt-get dist-upgrade and/or unattended-upgrades|-|-|
warning[]=NETW-2705|Could not find 2 responsive nameservers|-|-|
suggestion[]=SSH-7408|Consider hardening SSH configuration|AllowTcpForwarding (YES --> NO)|-|
suggestion[]=SSH-7408|Consider hardening SSH configuration|MaxAuthTries (6 --> 3)|-|
suggestion[]=SSH-7408|Consider hardening SSH configuration|PermitRootLogin (YES --> NO)|-|
suggestion[]=SSH-7408|Consider hardening SSH configuration|X11Forwarding (YES --> NO)|-|
manual[]=Verify if there is a formal process for testing and applying patches
lynis_tests_done=262
hardening_index=58
report_datetime_end=2026-11-08 07:44:37
EOF

chmod 644 "$BASE"/hr/departures.txt "$BASE"/review/approved_services.txt "$BASE"/review/sshd_config \
          "$BASE"/logs/auth.log "$BASE"/logs/fail2ban/jail.local "$BASE"/logs/lynis-report.dat

# ---------------------------------------------------------------------
# 13. Check that everything really built before declaring success
# ---------------------------------------------------------------------
ok=0
for i in $(seq 1 15); do
  if ss -tln | grep -q "0.0.0.0:$INV_PORT " &&
     ss -tln | grep -q "0.0.0.0:$TELNET_PORT " &&
     ss -tln | grep -q "0.0.0.0:$FTP_PORT "; then
    ok=1; break
  fi
  sleep 1
done
[ "$(sudo passwd -S dsimmons 2>/dev/null | awk '{print $2}')" = "P" ] || ok=0
[ "$(grep -c Tidewater /etc/passwd)" -eq 4 ] || ok=0
[ "$(find "$S" -xdev -perm -4000 -type f | wc -l)" -eq 4 ] || ok=0
[ "$(find "$S" -xdev -perm -0002 -type f | wc -l)" -eq 2 ] || ok=0
[ -x "$CLEANCMD" ] || ok=0
if [ "$ok" -ne 1 ]; then
  echo ""
  echo "❌ SETUP FAILED -- the homework did not build. Re-run the setup command."
  echo "   If it fails again, take a screenshot of this window and contact your instructor."
  exit 1
fi

# ---------------------------------------------------------------------
# 14. Confirmation banner
# ---------------------------------------------------------------------
echo ""
echo "==============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/HW9"
echo "==============================================================="
