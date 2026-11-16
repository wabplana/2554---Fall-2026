#!/bin/bash
# =====================================================================
# BIT 2554 -- In-Class Exercise 11-17 setup script
# Introduction to Shell Scripting
#
# Scenario: Laurel Ridge Outfitters (Store 417), an outdoor gear shop that
# rents and repairs camping and paddling gear. The store manager wrote a few
# small Bash scripts for daily tasks. You read them, fix the permissions, run
# them, write one of your own, and fix two that have mistakes in them.
#
# The script builds (all in ~/BIT2554/ex11_17):
#   open_store.sh     morning checklist   664 (NOT executable -- Section 2)
#   sale_sign.sh      pasted from Google Docs, has curly quotes   755
#   welcome.sh        variable mistake: spaces around =           755
#   daily_count.sh    $(command) and environment variables        755
#   closing_report.sh function defined first, called 3 times     755
#   broken_close.sh   function called before it is defined        755
#   returns/  4 files      repairs/  6 files + 1 hidden file      rentals/  9 files
#   Students create shift_note.sh themselves in Section 3.
#
# FIRST it checks for leftovers from Homework 9 (a student who never ran
# "sudo hw9-cleanup") and Exercise 11-10, and removes them. Only that step
# uses sudo -- if nothing is left over, the script never asks for a password.
#
# Idempotent: re-running removes and rebuilds ~/BIT2554/ex11_17 (this also
# deletes a shift_note.sh the student already wrote there).
# Every value below is FIXED. Changing any of them changes the answer key --
# re-verify the key (run each question's commands) after any edit.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# =====================================================================
# Leftover check: Homework 9 and Exercise 11-10
# Written so it never trips set -e. Leaves ~/BIT2554/HW9 (student files) alone.
# =====================================================================
hw9_leftovers() {
  local found=""
  for u in pcarter dsimmons rgalloway tmsbackup; do
    getent passwd "$u" >/dev/null 2>&1 && found="$found $u"
  done
  ls /etc/systemd/system/tms-*.service >/dev/null 2>&1 && found="$found services"
  for p in tms-inventory tms-telnetd tms-ftpd; do
    pgrep -x "$p" >/dev/null 2>&1 && found="$found $p"
  done
  [ -e /usr/local/lib/bit2554-hw9 ] || [ -e /usr/local/bin/hw9-cleanup ] && found="$found programs"
  echo "$found"
}

HW9_LEFT="$(hw9_leftovers)"
if [ -z "$HW9_LEFT" ]; then
  echo "Checked for Homework 9 leftovers: none found."
else
  echo "Homework 9 practice accounts/services are still installed ($HW9_LEFT ) -- removing them now."
  echo "(This uses sudo -- enter your password if asked.)"
  sudo bash <<'HW9_CLEAN_EOF' || true
USERS="pcarter dsimmons rgalloway tmsbackup"
UNITS="tms-inventory tms-telnet tms-ftp"
PROGS="tms-inventory tms-telnetd tms-ftpd"
if [ -d /run/systemd/system ]; then
  for u in $UNITS; do systemctl disable --now "$u.service" >/dev/null 2>&1; done
fi
for p in $PROGS; do pkill -x "$p" >/dev/null 2>&1; done
for u in $UNITS; do rm -f "/etc/systemd/system/$u.service"; done
[ -d /run/systemd/system ] && systemctl daemon-reload >/dev/null 2>&1
rm -rf /usr/local/lib/bit2554-hw9 /usr/local/bin/hw9-cleanup
for u in $USERS; do
  getent passwd "$u" >/dev/null 2>&1 && userdel "$u" >/dev/null 2>&1
  getent group  "$u" >/dev/null 2>&1 && groupdel "$u" >/dev/null 2>&1
done
exit 0
HW9_CLEAN_EOF
  sleep 1
  HW9_LEFT="$(hw9_leftovers)"
  if [ -n "$HW9_LEFT" ]; then
    echo "❌ Could not remove the Homework 9 practice accounts/services ($HW9_LEFT )."
    echo "   Take a screenshot of this window and contact your instructor."
    exit 1
  fi
  echo "Homework 9 practice accounts and services removed."
fi

# Exercise 11-10 leftover: the mkeller practice account
if [ -x /usr/local/bin/ex11-10-cleanup ] || getent passwd mkeller >/dev/null 2>&1; then
  echo "Removing the Exercise 11-10 practice account that was left behind..."
  echo "(This uses sudo -- enter your password if asked.)"
  sudo bash -c 'getent passwd mkeller >/dev/null 2>&1 && userdel mkeller >/dev/null 2>&1;
                getent group mkeller >/dev/null 2>&1 && groupdel mkeller >/dev/null 2>&1;
                rm -f /usr/local/bin/ex11-10-cleanup; exit 0' || true
fi
# ── end of leftover check ────────────────────────────────────────────

# ── FIXED VALUES (update this block each semester) ───────────────────
STORE="Laurel Ridge Outfitters"
STORE_NUM=417
MANAGER="Marisol"
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex11_17"

echo "Setting up Exercise 11-17..."

# ---------------------------------------------------------------------
# 1. Remove anything left from an earlier run of this script
# ---------------------------------------------------------------------
rm -rf "$BASE"
mkdir -p "$BASE/returns" "$BASE/repairs" "$BASE/rentals"
cd "$BASE"

# ---------------------------------------------------------------------
# 2. Data folders. Every name in a folder starts with a different letter,
#    so ls prints them in the same order in every locale.
#    returns: 4   repairs: 6 + 1 hidden (.rush_4419.txt)   rentals: 9
# ---------------------------------------------------------------------
for f in backpack_1180 lantern_1174 stove_1191 tent_1167; do
  echo "Rental return $f -- check for damage before restocking" > "returns/$f.txt"
done
for f in binding_4412 canoe_4408 ebike_4415 kayak_4403 pump_4410 zipper_4417; do
  echo "Repair ticket $f -- waiting for a technician" > "repairs/$f.txt"
done
echo "RUSH repair ticket 4419 -- customer leaves on a trip Friday" > "repairs/.rush_4419.txt"
for f in bike_2201 canoe_2202 daypack_2203 hammock_2204 kayak_2205 paddle_2206 \
         snowshoes_2207 tent_2208 wetsuit_2209; do
  echo "Rental $f -- out with a customer" > "rentals/$f.txt"
done

# ---------------------------------------------------------------------
# 3. Sections 1-2 -- open_store.sh (7 lines; 3 comment lines after the
#    shebang; grep -c '^#' prints 4). Left NOT executable on purpose.
# ---------------------------------------------------------------------
cat > open_store.sh <<EOF
#!/bin/bash
# open_store.sh: morning checklist for $STORE
# Written by the store manager. Run once when the store opens.
# Prints the opening message and lists the rental returns.
echo '$STORE -- Store $STORE_NUM is OPEN'
echo 'Rental returns waiting to be checked in:'
ls returns
EOF
chmod 664 open_store.sh

# ---------------------------------------------------------------------
# 4. Section 3 -- sale_sign.sh, typed in Google Docs and pasted in.
#    The quotes on lines 3 and 4 are curly quotes (“ ”), not real quotes.
# ---------------------------------------------------------------------
cat > sale_sign.sh <<'EOF'
#!/bin/bash
# sale_sign.sh: typed in Google Docs, then pasted into nano
echo “Spring sale starts Monday”
ls “rentals”
EOF
chmod 755 sale_sign.sh

# ---------------------------------------------------------------------
# 5. Section 4 -- welcome.sh. Line 3 has spaces around = (the mistake);
#    line 7 uses single quotes, so $manager is printed as-is.
# ---------------------------------------------------------------------
cat > welcome.sh <<EOF
#!/bin/bash
# welcome.sh: greeting for the front-counter screen
store = "$STORE"
manager=$MANAGER
echo "Welcome to \$store"
echo "Manager on duty: \$manager"
echo 'Ask \$manager about gear rentals'
EOF
chmod 755 welcome.sh

# ---------------------------------------------------------------------
# 6. Section 5 -- daily_count.sh: command substitution + environment vars
# ---------------------------------------------------------------------
cat > daily_count.sh <<'EOF'
#!/bin/bash
# daily_count.sh: counts for the store manager's end-of-day email
tickets=$(ls repairs | wc -l)
rented=$(ls rentals | wc -l)
echo "Repair tickets waiting: $tickets"
echo "Rentals out: $rented"
echo "Report run by $USER in $PWD"
echo "Home folder: $HOME"
EOF
chmod 755 daily_count.sh

# ---------------------------------------------------------------------
# 7. Section 6 -- functions
#    closing_report.sh: divider() defined on lines 4-7, called 3 times.
#    broken_close.sh:   print_header called on line 3, defined on lines 5-7.
# ---------------------------------------------------------------------
cat > closing_report.sh <<EOF
#!/bin/bash
# closing_report.sh: end-of-day report for $STORE
# divider keeps every part of the report looking the same.
divider() {
  echo "----- Store $STORE_NUM -----"
  return
}

divider
echo "Rentals out: \$(ls rentals | wc -l)"
divider
echo "Returns to check in: \$(ls returns | wc -l)"
divider
EOF
chmod 755 closing_report.sh

cat > broken_close.sh <<EOF
#!/bin/bash
# broken_close.sh: same idea, but the steps are in the wrong order
print_header
echo "Repair tickets: \$(ls repairs | wc -l)"
print_header() {
  echo "===== $STORE ====="
}
print_header
EOF
chmod 755 broken_close.sh

chmod 644 returns/* repairs/* repairs/.rush_4419.txt rentals/*
chmod 755 returns repairs rentals

# ---------------------------------------------------------------------
# 8. Check that everything really built before declaring success
# ---------------------------------------------------------------------
ok=1
[ "$(ls returns | wc -l)" -eq 4 ] || ok=0
[ "$(ls repairs | wc -l)" -eq 6 ] || ok=0
[ "$(ls -A repairs | wc -l)" -eq 7 ] || ok=0
[ "$(ls rentals | wc -l)" -eq 9 ] || ok=0
[ "$(wc -l < open_store.sh)" -eq 7 ] || ok=0
[ -x open_store.sh ] && ok=0
for s in sale_sign.sh welcome.sh daily_count.sh closing_report.sh broken_close.sh; do
  [ -x "$s" ] || ok=0
done
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
echo "  Working directory: ~/BIT2554/ex11_17"
echo "==============================================================="
