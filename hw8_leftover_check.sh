# =====================================================================
# BIT 2554 -- HW8 leftover check (paste into the Exercise 11-10 setup script)
#
# PLAN: the Nov 10 in-class exercise setup script (ex11_10_setup.sh) runs this
# block right after "set -e / set -o pipefail" and before it builds anything.
# It looks for anything HW8_Setup.sh left behind (a student who never ran
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
