#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
REPORT_VERSION="4.1"
AUDIT_CODE="SR-9815"
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex9_15"

# 1. Remove and rebuild if folder exists (idempotent)
rm -rf "$BASE"
mkdir -p "$BASE"

# 2. Create sysreport.sh
#    - Deliberately left OUT of $PATH. This is what makes `which sysreport.sh`
#      (Q1) come up empty, forces `./sysreport.sh --help` (Q2), and gives
#      Q12's `echo $PATH` check something real to confirm.
cat > "$BASE/sysreport.sh" << 'EOF'
#!/bin/bash
# sysreport.sh -- fixed-format status report for BIT2554 Exercise 9-15

if [ "$1" == "--help" ]; then
  echo "Usage: sysreport.sh [--help]"
  echo "Generates a fixed-format system status report for the BIT2554 audit exercise."
  echo ""
  echo "Options:"
  echo "  --help    Show this help message and exit"
  exit 0
fi

echo "========================================"
echo " BIT2554 SYSTEM STATUS REPORT"
echo "========================================"
echo "Report Version : REPORT_VERSION_PLACEHOLDER"
echo "Audit Code     : AUDIT_CODE_PLACEHOLDER"
echo "Status         : OK"
echo "========================================"
EOF
sed -i "s/REPORT_VERSION_PLACEHOLDER/$REPORT_VERSION/" "$BASE/sysreport.sh"
sed -i "s/AUDIT_CODE_PLACEHOLDER/$AUDIT_CODE/" "$BASE/sysreport.sh"
chmod 755 "$BASE/sysreport.sh"

# 3. Register the diskcheck alias in ~/.bashrc (idempotent -- only add once).
#    This is intentionally the ONLY alias written to a startup file. It's what
#    lets Section 5 (Q11) contrast a startup-file alias (diskcheck, survives a
#    new terminal) against a session-only alias the student types themselves
#    at the prompt (coursecheck, Sections 4-5 -- gone the moment the shell
#    closes). `source ~/.bashrc` (Setup step 2) activates it for the current
#    terminal without needing to fully log out and back in.
MARKER="# BIT2554 ex9_15 alias (added by setup script)"
if ! grep -qF "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ""
    echo "$MARKER"
    echo "alias diskcheck='df -h'"
  } >> "$HOME/.bashrc"
fi

# 4. Confirmation banner -- must match the Setup box subtitle in the document
#    exactly, since that's how students know the script actually ran.
echo ""
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "NOTE: run 'source ~/.bashrc' (or open a new terminal tab) so the diskcheck alias is active."
