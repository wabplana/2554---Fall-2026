#!/bin/bash
# =====================================================================
# BIT 2554 -- Homework Assignment 7 setup script
# Regular Expressions
#
# Scenario: New River Credit Union (NRCU). Its IT team needs to audit files
# exported from several systems. Every file contains LOOK-ALIKE entries
# designed to catch patterns that are too loose (an unescaped dot, a missing
# anchor, a missing boundary), so students must build precise patterns.
# The script builds:
#   ~/BIT2554/HW7/config/.branch.conf     HIDDEN branch server settings: comments,
#                                         an indented commented-out setting, blanks
#   ~/BIT2554/HW7/data/members.csv        member records (ID, name, email, phone, join date)
#   ~/BIT2554/HW7/data/transactions.txt   transaction register (amounts + descriptions)
#   ~/BIT2554/HW7/logs/auth.log           online-banking sign-in log
#
# No sudo needed. Idempotent: re-running deletes and rebuilds the folder.
# No question changes any file, so every question is independent.
# Every file below is FIXED text. Changing any line changes the answer key --
# re-verify the key (run each question's commands) after any edit.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ───────────────────
BRANCH_ID="BR-014"
CHANGE_TICKET="CHG-2291"
LOG_DATE="2026-10-21"
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/HW7"

# 1. Remove and rebuild if the folder already exists
rm -rf "$BASE"
mkdir -p "$BASE/config" "$BASE/data" "$BASE/logs"

# 2. Section 1 -- hidden config file (anchors + negated sets)
#    Note the INDENTED commented-out line and the two blank lines.
cat > "$BASE/config/.branch.conf" <<EOF
# New River Credit Union -- Branch Server Settings
# Branch: Blacksburg Main ($BRANCH_ID)

branch_id=$BRANCH_ID
teller_port=7310
    # max_sessions=40   (disabled by IT, ticket $CHANGE_TICKET)
max_sessions=25
#audit_mode=strict

timeout_minutes=15
vault_alarm=enabled
EOF

# 3. Sections 2-3 and 6 -- member records
cat > "$BASE/data/members.csv" <<'EOF'
member_id,last,first,email,phone,joined
NRC-104512,Alvarez,Maria,malvarez@nrcu.org,540-555-0187,2019-04-12
NRC-10451,Brooks,Devin,dbrooks@vt.edu,540-555-0122,2021-11-03
NRC-220931,Chen,Jia,jchen@nrcu.org,(540) 555-0164,2020-07-28
nrc-305118,Dawson,Kyle,kdawson@gmail.com,703-555-0199,2018-13-09
NRC-412077,Ellis,Rena,rellis@nrcu-org.com,540-555-0110,2022-02-30
NRC-5180923,Foster,Liam,lfoster@nrcu.org,540-555-0175,2023-09-15
NRC-603344,Garcia,Ana,agarcia@outlook.com,(276) 555-0133,2024-00-21
NRC604415,Hughes,Omar,ohughes@nrcu.org,540-555-0148,2017-10-05
NRC-708256,Ito,Kenji,kito@nrcuXorg.net,(434) 555-0191,2025-12-01
NRC-811902,Jones,Priya,pjones@nrcu.org,540-555-0156,2016-01-31
EOF

# 4. Section 4 -- sign-in log
cat > "$BASE/logs/auth.log" <<EOF
$LOG_DATE 07:52:10 LOGIN_OK       user=mbrown    ip=10.20.4.17
$LOG_DATE 08:03:44 LOGIN_FAIL     user=tpatel    ip=203.0.113.45
$LOG_DATE 08:04:02 LOGIN_FAIL     user=tpatel    ip=203.0.113.45
$LOG_DATE 08:04:31 LOCKED         user=tpatel    ip=203.0.113.45
$LOG_DATE 08:15:09 LOGIN_OK       user=jchen     ip=10.20.4.22
$LOG_DATE 08:47:55 LOGIN_OK       user=tpatelson ip=10.200.8.3
$LOG_DATE 09:12:30 LOGIN_FAIL     user=jchen     ip=110.20.6.9
$LOG_DATE 09:58:01 PASSWORD_RESET user=jchen     ip=10.20.4.22
$LOG_DATE 10:02:17 LOGIN_FAIL     user=rkhan     ip=10.20.9.140
$LOG_DATE 10:30:45 LOCKED         user=rkhan     ip=10.20.9.140
EOF

# 5. Section 5 -- transaction register
cat > "$BASE/data/transactions.txt" <<'EOF'
TXN-88101  2026-10-19  DEPOSIT     $1,250.00   payroll direct deposit
TXN-88102  2026-10-19  WITHDRAWAL  $85.00      ATM Blacksburg
TXN-88103  2026-10-19  TRANSFER    $12,400.00  Wire Transfer to Roanoke Title
TXN-88104  2026-10-20  WITHDRAWAL  $999.99     wire transfer fee waived
TXN-88105  2026-10-20  DEPOSIT     $3,075.50   mobile check deposit
TXN-88106  2026-10-20  TRANSFER    $640.00     WIRE-TRANSFER to vendor
TXN-88107  2026-10-21  TRANSFER    $1,000.00   WIRE  TRANSFER intl
TXN-88108  2026-10-21  WITHDRAWAL  $40.00      wired funds hold
TXN-88109  2026-10-21  FEE         $25.00      transfer fee
EOF

chmod 644 "$BASE/config/.branch.conf" "$BASE"/data/* "$BASE/logs/auth.log"

# 6. Confirmation banner
echo ""
echo "=============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/HW7"
echo "=============================================================="
