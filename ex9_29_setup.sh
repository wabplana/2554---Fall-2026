#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
API_KEY="VT-API-80417"
LEDGER_ID="LDG-4471"
BANNER_CODE="BIT-7730"
AUDIT_TOKEN="SEC-5518"
REPORT_ID="Q3-2026-FIN"
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex9_29"

# Make sure new files in this script start from a known default, regardless of
# the student's current shell umask. Every graded permission is also set
# explicitly with chmod below.
umask 022

# 1. Remove and rebuild if folder exists (idempotent)
if [ -d "$BASE" ]; then
  # audit.log is made immutable (chattr +i) partway through the exercise. If a
  # student re-runs setup before removing the attribute, rm cannot delete it.
  if [ -e "$BASE/audit.log" ] && ! rm -f "$BASE/audit.log" 2>/dev/null; then
    echo "❌ audit.log is still immutable from Question 14."
    echo "   Run:  sudo chattr -i ~/BIT2554/ex9_29/audit.log"
    echo "   then re-run this setup script."
    exit 1
  fi
  # Restore owner access everywhere (e.g. vault/ with no execute bit) so the
  # recursive delete can traverse every directory.
  chmod -R u+rwx "$BASE" 2>/dev/null || true
  rm -rf "$BASE"
fi

# 2. Create directory structure
mkdir -p "$BASE/reports" "$BASE/vault" "$BASE/team_share"

# 3. Populate files with specific fixed content
cd "$BASE"

cat > payroll.csv <<EOF
employee_id,name,department,salary
1001,J. Alvarez,Finance,68000
1002,R. Chen,IT,74500
1003,M. Okafor,Marketing,61200
EOF

echo "API_KEY=${API_KEY}" > .api_key

cat > reports/q3_report.txt <<EOF
REPORT-ID: ${REPORT_ID}
Status: FINAL
EOF
ln -sf reports/q3_report.txt latest_report

echo "LEDGER-ID: ${LEDGER_ID}" > vault/ledger.txt

echo "Quarterly summary -- draft" > report.txt
echo "Budget worksheet placeholder" > budget.xlsx

cat > display.sh <<EOF
#!/bin/bash
echo "BANNER CODE: ${BANNER_CODE}"
EOF

echo "Team notes: stand-up moved to 9:30" > shared_notes.txt

cat > tool.sh <<EOF
#!/bin/bash
echo "maintenance tool"
EOF

echo "AUDIT-TOKEN: ${AUDIT_TOKEN}" > audit.log

# 4. Apply chmod permissions (explicit -- never rely on the umask)
chmod 640 payroll.csv          # -rw-r-----
chmod 400 .api_key             # -r--------
chmod 755 reports              # drwxr-xr-x
chmod 644 reports/q3_report.txt
chmod 644 vault/ledger.txt     # file itself is readable...
chmod 600 vault                # ...but the directory has no execute bit
chmod 600 report.txt           # -rw------- (changed with octal in Q5)
chmod 777 budget.xlsx          # -rwxrwxrwx (misconfiguration, fixed in Q6)
chmod 644 display.sh           # not executable yet (fixed in Q7)
chmod 666 shared_notes.txt     # -rw-rw-rw- (fixed in Q8)
chmod 775 team_share           # drwxrwxr-x (special bits added in Q12)
chmod 644 tool.sh              # -rw-r--r-- (SUID added in Q13)
chmod 644 audit.log            # -rw-r--r-- (chattr/chown in Q14-15)

# 5. Confirmation banner
echo ""
echo "=============================================================="
echo " BIT 2554 -- Exercise 9-29: File & Directory Permissions"
echo " Environment built at: $BASE"
echo "=============================================================="
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
