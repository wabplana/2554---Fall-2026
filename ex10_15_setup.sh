#!/bin/bash
# =====================================================================
# BIT 2554 -- In-Class Exercise 10-15 setup script
# The Environment and Shell Variables
#
# Scenario: HokiePay, a small payroll system. The script builds:
#   ~/BIT2554/ex10_15/config/hokiepay.env  payroll settings written as variable
#                                          assignments: 4 plain (shell) variables
#                                          and 2 "export" (environment) variables
#   ~/BIT2554/ex10_15/bin/hokiepay         payroll report program. It runs as a
#                                          CHILD process, so it can only see
#                                          ENVIRONMENT variables. Prints a Report
#                                          ID once all 4 required settings are set.
#   ~/BIT2554/ex10_15/home_demo/           sample home directory: README.txt plus
#                                          hidden .bash_login, .profile, .bash_logout
#
# No sudo needed. Idempotent: re-running deletes and rebuilds the folder.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ───────────────────
HP_COMPANY_VAL="Drillfield Supply Co."
HP_REGION_VAL="SW-VA-07"
HP_BATCH_VAL="PR-2026-4410"      # students later export a NEW value (PR-2026-5520)
HP_APIKEY_VAL="hpk_7Q2M9X41"
HP_TAXRATE_VAL="5.75"
HP_SERVER_VAL="payroll03.hokie.local"
LOGIN_REGION="NE-VA-03"          # set in home_demo/.bash_login
PROFILE_REGION="CEN-VA-11"       # set in home_demo/.profile
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex10_15"

# 1. Remove and rebuild if the folder already exists
rm -rf "$BASE"
mkdir -p "$BASE/config" "$BASE/bin" "$BASE/home_demo"

# 2. Payroll settings file (sourced by the student in Section 2)
cat > "$BASE/config/hokiepay.env" <<EOF
# HokiePay payroll settings -- load with:  source config/hokiepay.env
HP_COMPANY="$HP_COMPANY_VAL"
HP_REGION=$HP_REGION_VAL
HP_BATCH=$HP_BATCH_VAL
HP_APIKEY=$HP_APIKEY_VAL
export HP_TAXRATE=$HP_TAXRATE_VAL
export HP_SERVER=$HP_SERVER_VAL
EOF

# 3. Payroll report program (child process -- reads environment variables only)
cat > "$BASE/bin/hokiepay" <<'EOF'
#!/bin/bash
# HokiePay payroll report. Runs as a child process of your shell, so it only
# receives ENVIRONMENT (exported) variables.
echo "HokiePay Payroll Report v2.4"
missing=0
show() {   # show <VARNAME> <label> <required:yes|no>
  local name=$1 label=$2 req=$3
  if [ -n "${!name}" ]; then
    printf '%-10s: %s\n' "$label" "${!name}"
  else
    printf '%-10s: (not set)\n' "$label"
    [ "$req" = yes ] && missing=$((missing + 1))
  fi
  return 0
}
show HP_COMPANY Company  no
show HP_SERVER  Server   yes
show HP_TAXRATE "Tax rate" yes
show HP_REGION  Region   yes
show HP_BATCH   Batch    yes
if [ "$missing" -eq 0 ]; then
  n=$(printf '%s|%s|%s|%s' "$HP_SERVER" "$HP_TAXRATE" "$HP_REGION" "$HP_BATCH" | cksum | cut -d' ' -f1)
  echo "Status    : COMPLETE"
  echo "Report ID : HPR-$(( n % 90000 + 10000 ))"
else
  echo "Status    : INCOMPLETE -- $missing required setting(s) missing"
  echo "Report ID : (none)"
fi
EOF
chmod 755 "$BASE/bin/hokiepay"

# 4. Sample home directory with hidden startup files
cat > "$BASE/home_demo/README.txt" <<'EOF'
Sample home directory for a HokiePay payroll clerk.
The startup files here are hidden -- use ls -a to see them.
EOF
cat > "$BASE/home_demo/.bash_login" <<EOF
# Payroll clerk login settings
export HP_LOGIN_REGION=$LOGIN_REGION
export HP_PRINTER=PAYROLL-LJ2
EOF
cat > "$BASE/home_demo/.profile" <<EOF
# Fallback login settings (only read if no .bash_profile or .bash_login exists)
export HP_LOGIN_REGION=$PROFILE_REGION
EOF
cat > "$BASE/home_demo/.bash_logout" <<'EOF'
# Runs when a login shell exits
clear
EOF
chmod 644 "$BASE/config/hokiepay.env" "$BASE"/home_demo/README.txt "$BASE"/home_demo/.[a-z]*

# 5. Confirmation banner
echo ""
echo "=============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/ex10_15"
echo "=============================================================="
