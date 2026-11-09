#!/bin/bash
# =====================================================================
# BIT 2554 -- In-Class Exercise 11-10 setup script
# Securing a Linux System
#
# Scenario: Cascades Brewing Co., a small craft brewery. The brewery's old
# IT contractor left, and you have been asked to review the server (brew-srv01)
# using the hardening checklist from class. To keep your VM safe, you work on
# COPIES of the server's files. The only change to the VM itself is one
# practice user account (mkeller) in Section 2, which Section 2 removes again.
#
# The script builds:
#   ~/BIT2554/ex11_10/audit/passwd_copy        copy of the server's /etc/passwd
#   ~/BIT2554/ex11_10/audit/sudoers_copy       copy of the server's /etc/sudoers
#   ~/BIT2554/ex11_10/audit/sshd_config_copy   copy of the server's sshd_config
#   ~/BIT2554/ex11_10/audit/auth.log           sudo/ssh entries from the server
#   ~/BIT2554/ex11_10/audit/etc/               permission-practice copies
#   ~/BIT2554/ex11_10/server/                  folder tree with SUID and
#                                              world-writable practice files
#   practice account mkeller (UID 2310, nologin) and /usr/local/bin/ex11-10-cleanup
#
# FIRST it checks for Homework 8 leftovers (a student who never ran
# "sudo hw8-cleanup") and removes them.
#
# Uses sudo. Idempotent: re-running removes and rebuilds everything.
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
COMPANY="Cascades Brewing Co."
SERVER="brew-srv01"
LAB_USER="mkeller"            # practice account for Section 2
LAB_UID=2310
LAB_FULLNAME="Mark Keller"
LAB_SHELL="/usr/sbin/nologin"
LAB_PW="Keller2310"           # given to students in Q3 so they can try su while locked
LAB_PW_DATE="2026-10-01"      # fixed "last password change" date
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex11_10"
CLEANCMD="/usr/local/bin/ex11-10-cleanup"

echo "Setting up Exercise 11-10 (this uses sudo -- enter your password if asked)..."
sudo -v

# ---------------------------------------------------------------------
# 1. Remove anything left from an earlier run of this script
# ---------------------------------------------------------------------
if getent passwd "$LAB_UID" >/dev/null 2>&1 && [ "$(getent passwd "$LAB_UID" | cut -d: -f1)" != "$LAB_USER" ]; then
  echo "❌ SETUP FAILED -- UID $LAB_UID is already used by another account."
  echo "   Take a screenshot of this window and contact your instructor."
  exit 1
fi
if getent passwd "$LAB_USER" >/dev/null 2>&1; then
  sudo userdel "$LAB_USER" >/dev/null 2>&1 || true
fi
if getent group "$LAB_USER" >/dev/null 2>&1; then
  sudo groupdel "$LAB_USER" >/dev/null 2>&1 || true
fi
sudo rm -f "$CLEANCMD"
rm -rf "$BASE"

# ---------------------------------------------------------------------
# 2. Section 2 -- the practice account (a former employee's account).
#    Login shell is nologin, so nobody can open a shell as this account.
#    The password is fixed (students use it with su in Q3). The "last password
#    change" date is fixed too.
# ---------------------------------------------------------------------
sudo useradd -u "$LAB_UID" -M -c "$LAB_FULLNAME" -s "$LAB_SHELL" "$LAB_USER"
echo "$LAB_USER:$LAB_PW" | sudo chpasswd
sudo chage -d "$LAB_PW_DATE" -m 0 -M 99999 -W 7 -I -1 "$LAB_USER"

# Cleanup command: sudo ex11-10-cleanup (end of Section 2). Removes itself.
sudo tee "$CLEANCMD" >/dev/null <<EOF
#!/bin/bash
LAB_USER="$LAB_USER"
EOF
sudo tee -a "$CLEANCMD" >/dev/null <<'CLEANUP_EOF'
# BIT 2554 Exercise 11-10 -- removes the practice account from this VM.
# Safe to run more than once. Leaves ~/BIT2554/ex11_10 (your files) alone.
if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi

echo "Removing the Exercise 11-10 practice account..."
if getent passwd "$LAB_USER" >/dev/null 2>&1; then
  userdel "$LAB_USER" >/dev/null 2>&1
fi
if getent group "$LAB_USER" >/dev/null 2>&1; then
  groupdel "$LAB_USER" >/dev/null 2>&1
fi

if getent passwd "$LAB_USER" >/dev/null 2>&1 || getent group "$LAB_USER" >/dev/null 2>&1; then
  echo "⚠ CLEANUP INCOMPLETE -- the practice account is still on this VM."
  echo "  Run sudo ex11-10-cleanup again. If this message repeats, contact your instructor."
  exit 1
fi
rm -f /usr/local/bin/ex11-10-cleanup
echo "✅ CLEANUP COMPLETE -- the Exercise 11-10 practice account has been removed."
CLEANUP_EOF
sudo chmod 755 "$CLEANCMD"

# ---------------------------------------------------------------------
# 3. Folders
# ---------------------------------------------------------------------
mkdir -p "$BASE/audit/etc"
mkdir -p "$BASE/server/usr/bin" "$BASE/server/usr/local/bin" "$BASE/server/etc"
mkdir -p "$BASE/server/home/lchen/.cache" "$BASE/server/home/rpatel"
mkdir -p "$BASE/server/srv/shared" "$BASE/server/tmp"

# ---------------------------------------------------------------------
# 4. Section 1 -- copy of the server's /etc/passwd (14 lines).
#    Line 10 is a second UID 0 account (tapsync); jhargrove left the company but
#    still has a login shell. 7 lines do not contain "nologin".
# ---------------------------------------------------------------------
cat > "$BASE/audit/passwd_copy" <<'EOF'
root:x:0:0:root:/root:/usr/bin/zsh
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
mysql:x:105:111:MySQL Server,,,:/nonexistent:/usr/sbin/nologin
brewadmin:x:1000:1000:Brew Admin:/home/brewadmin:/usr/bin/zsh
rpatel:x:1001:1001:Rina Patel:/home/rpatel:/bin/bash
tkessler:x:1002:1002:Tom Kessler:/home/tkessler:/bin/bash
jhargrove:x:1003:1003:Jo Hargrove:/home/jhargrove:/bin/bash
tapsync:x:0:0:Tap Sync Service:/root:/bin/bash
lchen:x:1004:1004:Lena Chen:/home/lchen:/bin/bash
kegmon:x:998:998:Keg Monitor:/var/lib/kegmon:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
EOF

# ---------------------------------------------------------------------
# 5. Section 3 -- sudoers copy, sshd_config copy, auth.log
# ---------------------------------------------------------------------
cat > "$BASE/audit/sudoers_copy" <<EOF
# $COMPANY -- sudoers (copy from $SERVER)
#
# User privilege specification
root	ALL=(ALL:ALL) ALL
# Members of the sudo group may run any command
%sudo	ALL=(ALL:ALL) ALL
# Front desk staff may restart the label printer service
%frontdesk	ALL=(root) /usr/bin/systemctl restart cups
# Added by the previous admin
tkessler	ALL=(ALL:ALL) ALL
EOF

cat > "$BASE/audit/sshd_config_copy" <<EOF
# $COMPANY -- sshd_config (copy from $SERVER)

#Port 22
#AddressFamily any

# Authentication:

#LoginGraceTime 2m
#PermitRootLogin prohibit-password
# The old contractor set PermitRootLogin to yes so a vendor could connect.
PermitRootLogin yes
#StrictModes yes
#MaxAuthTries 6

PasswordAuthentication yes
EOF

# 5 lines contain COMMAND; the 3rd (lchen) was refused.
cat > "$BASE/audit/auth.log" <<EOF
Nov  3 08:02:11 $SERVER sshd[1204]: Accepted password for rpatel from 10.20.0.15 port 51822 ssh2
Nov  3 08:02:12 $SERVER systemd-logind[612]: New session 4 of user rpatel.
Nov  3 08:05:40 $SERVER sudo:   rpatel : TTY=pts/0 ; PWD=/home/rpatel ; USER=root ; COMMAND=/usr/bin/apt update
Nov  3 08:06:03 $SERVER sudo: pam_unix(sudo:session): session opened for user root(uid=0) by rpatel(uid=1001)
Nov  3 08:06:21 $SERVER sudo:   rpatel : TTY=pts/0 ; PWD=/home/rpatel ; USER=root ; COMMAND=/usr/bin/systemctl restart nginx
Nov  3 09:31:27 $SERVER sshd[1311]: Failed password for root from 203.0.113.77 port 40122 ssh2
Nov  3 09:31:29 $SERVER sshd[1311]: Failed password for root from 203.0.113.77 port 40124 ssh2
Nov  3 10:15:09 $SERVER sudo:    lchen : user NOT in sudoers ; TTY=pts/1 ; PWD=/home/lchen ; USER=root ; COMMAND=/usr/bin/cat /etc/shadow
Nov  3 10:15:44 $SERVER sudo: tkessler : TTY=pts/2 ; PWD=/home/tkessler ; USER=root ; COMMAND=/usr/bin/nano /etc/ssh/sshd_config
Nov  3 11:40:02 $SERVER sudo:   rpatel : TTY=pts/0 ; PWD=/home/rpatel ; USER=root ; COMMAND=/usr/bin/apt full-upgrade -y
Nov  3 11:58:30 $SERVER sudo: pam_unix(sudo:session): session closed for user root
EOF

# ---------------------------------------------------------------------
# 6. Section 4 -- permission-practice copies (shadow copy is too open)
# ---------------------------------------------------------------------
echo "# practice copy of the server's /etc/passwd -- not a real file" > "$BASE/audit/etc/passwd"
echo "# practice copy of the server's /etc/shadow -- not a real file" > "$BASE/audit/etc/shadow"
echo "# practice copy of the server's /etc/sudoers -- not a real file" > "$BASE/audit/etc/sudoers"
chmod 644 "$BASE/audit/etc/passwd"
chmod 666 "$BASE/audit/etc/shadow"
chmod 440 "$BASE/audit/etc/sudoers"

# ---------------------------------------------------------------------
# 7. Section 5 -- the server folder tree
#    SUID (-perm -4000) files: 4 (passwd, sudo, su, and a bash copy in lchen's
#    hidden .cache folder). wall is setgid only -- NOT matched.
#    World-writable files (-perm -0002, -type f): 2 (backup.sh and price_list.txt).
#    Decoys: a 777 folder, a 1777 folder, and a 664 (group-writable) file.
# ---------------------------------------------------------------------
S="$BASE/server"
for f in usr/bin/passwd usr/bin/sudo usr/bin/su usr/bin/ls usr/bin/wall \
         usr/local/bin/backup.sh usr/local/bin/report.sh \
         home/lchen/.cache/bash home/lchen/notes.txt home/rpatel/schedule.txt \
         srv/shared/price_list.txt srv/shared/readme.txt etc/brew.conf; do
  echo "# Exercise 11-10 practice file -- not a real program" > "$S/$f"
done
chmod 4755 "$S/usr/bin/passwd" "$S/usr/bin/sudo" "$S/usr/bin/su" "$S/home/lchen/.cache/bash"
chmod 755  "$S/usr/bin/ls" "$S/usr/local/bin/report.sh"
chmod 2755 "$S/usr/bin/wall"
chmod 777  "$S/usr/local/bin/backup.sh"
chmod 666  "$S/srv/shared/price_list.txt"
chmod 644  "$S/srv/shared/readme.txt" "$S/home/lchen/notes.txt" "$S/home/rpatel/schedule.txt"
chmod 664  "$S/etc/brew.conf"
chmod 777  "$S/srv/shared"
chmod 1777 "$S/tmp"

chmod 644 "$BASE"/audit/passwd_copy "$BASE"/audit/sudoers_copy "$BASE"/audit/sshd_config_copy \
          "$BASE"/audit/auth.log

# ---------------------------------------------------------------------
# 8. Check that everything really built before declaring success
# ---------------------------------------------------------------------
ok=1
[ "$(sudo passwd -S "$LAB_USER" 2>/dev/null | awk '{print $2}')" = "P" ] || ok=0
[ "$(getent passwd "$LAB_USER" | cut -d: -f3)" = "$LAB_UID" ] || ok=0
[ -x "$CLEANCMD" ] || ok=0
[ "$(find "$S" -xdev -perm -4000 -type f | wc -l)" -eq 4 ] || ok=0
[ "$(find "$S" -xdev -perm -0002 -type f | wc -l)" -eq 2 ] || ok=0
[ "$(wc -l < "$BASE/audit/passwd_copy")" -eq 14 ] || ok=0
if [ "$ok" -ne 1 ]; then
  echo ""
  echo "❌ SETUP FAILED -- the exercise did not build. Re-run the setup command."
  echo "   If it fails again, take a screenshot of this window and contact your instructor."
  exit 1
fi

# ---------------------------------------------------------------------
# 9. Confirmation banner
# ---------------------------------------------------------------------
echo ""
echo "==============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/ex11_10"
echo "==============================================================="
