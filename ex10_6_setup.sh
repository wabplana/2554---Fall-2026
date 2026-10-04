#!/bin/bash
# ============================================================
#  BIT 2554 -- Exercise 10-6 Setup: Search (locate, find, xargs, grep)
#  Builds a fixed "Cardinal Freight" file share for searching.
#  Safe to re-run: the exercise folder is deleted and rebuilt.
# ============================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
LOCATE_TOKEN="vantora"      # unique substring used for the locate questions
BIG_LOG_BYTES=2097152       # 2 MB archived log   (find -size)
BIG_IMG_BYTES=307200        # 300 KB banner image (find -size)
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex10_6"

# 1. Remove and rebuild if folder exists (idempotent)
if [ -d "$BASE" ]; then
  chmod -R u+rwX "$BASE" 2>/dev/null || true
  rm -rf "$BASE"
fi

# 2. Directory structure
mkdir -p "$BASE"/{finance,hr/policies,logs/archive,scripts,cache,media/icons.png,.archive}
cd "$BASE"

# 3. Files ---------------------------------------------------

# ---- finance: quarterly sales CSVs (fixed line counts + "refund" counts) ----
{
  echo "order_id,region,amount,status"
  echo "1001,East,420.00,paid"
  echo "1002,West,150.00,refund"
  echo "1003,East,980.50,paid"
  echo "1004,North,75.25,refund"
  echo "1005,South,310.00,paid"
  echo "1006,West,640.00,paid"
  echo "1007,East,55.00,refund"
  echo "1008,North,1200.00,paid"
  echo "1009,South,89.99,paid"
  echo "1010,West,410.00,refund"
  echo "1011,East,230.00,paid"
  echo "1012,North,715.40,paid"
} > finance/q1_sales.csv   # 13 lines, 4 refund

{
  echo "order_id,region,amount,status"
  echo "2001,East,510.00,paid"
  echo "2002,West,99.00,paid"
  echo "2003,North,1450.00,paid"
  echo "2004,South,300.00,paid"
  echo "2005,East,82.10,paid"
  echo "2006,West,660.00,paid"
  echo "2007,North,45.00,paid"
  echo "2008,South,905.75,paid"
} > finance/q2_sales.csv   # 9 lines, 0 refund

{
  echo "order_id,region,amount,status"
  echo "3001,East,120.00,refund"
  echo "3002,West,875.00,paid"
  echo "3003,North,64.00,refund"
  echo "3004,South,390.00,paid"
  echo "3005,East,1100.00,paid"
  echo "3006,West,215.50,refund"
  echo "3007,North,540.00,paid"
  echo "3008,South,72.00,refund"
  echo "3009,East,660.00,paid"
  echo "3010,West,310.00,paid"
  echo "3011,North,95.00,refund"
  echo "3012,South,1280.00,paid"
  echo "3013,East,430.00,paid"
  echo "3014,West,58.25,paid"
  echo "3015,North,700.00,paid"
} > finance/q3_sales.csv   # 16 lines, 5 refund

{
  echo "order_id,region,amount,status"
  echo "4001,East,340.00,paid"
  echo "4002,West,125.00,refund"
  echo "4003,North,880.00,paid"
  echo "4004,South,62.50,refund"
  echo "4005,East,915.00,paid"
} > finance/q4_sales.csv   # 6 lines, 2 refund

cat > finance/budget_notes.txt <<'EOF'
FY2026 Budget Notes -- Cardinal Freight
Fuel line item increased 8 percent over FY2025.
Warehouse lease renewal due in March.
Owner: Finance Operations
EOF
chmod 640 finance/budget_notes.txt

echo "Placeholder spreadsheet export -- Budget 2026" > finance/Budget_2026.XLSX

echo "Invoice 01 -- ${LOCATE_TOKEN^} Logistics -- Net 30" > "finance/${LOCATE_TOKEN}_invoice_01.txt"
echo "Invoice 02 -- ${LOCATE_TOKEN^} Logistics -- Net 30" > "finance/${LOCATE_TOKEN}_invoice_02.txt"

# ---- hr ----
{
  echo "emp_id,name,dept"
  echo "E100,Maria Reyes,IT"
  echo "E101,James Park,Finance"
  echo "E102,Aisha Grant,HR"
  echo "E103,Tom Becker,Operations"
} > hr/staff_roster.csv

cat > hr/Onboarding.TXT <<'EOF'
Welcome to Cardinal Freight!
Day 1: Collect your badge from the front desk.
Day 1: Set your Password on first login.
Day 2: Complete safety training.
EOF

echo "Master Services Agreement -- ${LOCATE_TOKEN^} Logistics" > "hr/${LOCATE_TOKEN^}_Contract.pdf"
echo "SUMMARY -- ${LOCATE_TOKEN^^} vendor review" > "hr/policies/${LOCATE_TOKEN^^}_summary.txt"

cat > hr/policies/remote_work.txt <<'EOF'
Remote Work Policy
Always connect through the company VPN.
Never share your password with coworkers.
Lock your screen when you step away.
Change your password every 90 days.
EOF

cat > hr/policies/travel_policy.txt <<'EOF'
Travel Policy
Book flights at least 14 days in advance.
Submit receipts within 5 business days.
EOF

# Restricted file: nobody (not even the owner) can read it -> grep "Permission denied"
echo "payroll portal password: REDACTED" > hr/payroll_keys.txt
chmod 000 hr/payroll_keys.txt

# ---- logs ----
cat > logs/app.log <<'EOF'
2026-10-05 08:00:01 INFO  service started
2026-10-05 08:02:14 error failed to read config cache
2026-10-05 08:05:33 WARN  disk usage at 81%
2026-10-05 08:07:09 ERROR payment gateway timeout
2026-10-05 08:09:45 INFO  user login: mreyes
2026-10-05 08:12:00 Error retry limit reached
2026-10-05 08:15:27 INFO  nightly export complete
2026-10-05 08:18:02 error queue worker crashed
2026-10-05 08:20:40 INFO  errors cleared by admin
2026-10-05 08:22:11 ERROR database connection refused
2026-10-05 08:25:59 INFO  user logout: mreyes
2026-10-05 08:30:00 WARN  certificate expires in 12 days
EOF

cat > logs/auth.log <<'EOF'
Oct  5 07:58:12 bit2554 sshd: Accepted publickey for student
Oct  5 08:14:40 bit2554 sudo: student : TTY=pts/0 ; COMMAND=/usr/bin/apt update
EOF

echo "rotate weekly; keep 4" > logs/archive/rotation.conf
head -c "$BIG_LOG_BYTES" /dev/zero > logs/archive/app_2025.log
echo "export scratch" > logs/export.tmp

# ---- scripts (deliberately NOT executable) ----
cat > scripts/backup.sh <<'EOF'
#!/bin/bash
# Nightly backup -- the database password is stored in the vault, not here.
echo "Backing up finance share..."
EOF
cat > scripts/cleanup.sh <<'EOF'
#!/bin/bash
echo "Cleaning cache folder..."
EOF
cat > scripts/report.sh <<'EOF'
#!/bin/bash
echo "Generating weekly report..."
EOF
echo "Scripts in this folder are run by the ops team." > scripts/README.txt
chmod 644 scripts/*.sh scripts/README.txt

# ---- cache: temp files to be deleted with find -delete ----
for i in 1 2 3 4 5; do
  echo "session $i" > "cache/session$i.tmp"
done

# ---- media (icons.png is a DIRECTORY -- the -or precedence trap) ----
head -c "$BIG_IMG_BYTES" /dev/zero > media/banner.jpg
echo "team photo placeholder" > media/team.jpg
echo "logo placeholder" > media/logo.png
echo "Brand assets live here." > media/readme.txt
echo "icon set placeholder" > media/icons.png/truck.svg

# ---- hidden archive directory ----
{
  echo "order_id,region,amount,status"
  echo "0901,East,300.00,paid"
  echo "0902,West,120.00,refund"
} > .archive/old_sales.csv
echo "Old admin password rotated in 2024." > .archive/old_notes.txt

# ---- symbolic link ----
ln -sf logs/app.log current_log

# 4. Standard permissions on directories
find "$BASE" -type d -exec chmod 755 {} +

# 5. Confirmation banner
echo ""
echo "=============================================================="
echo "  BIT 2554 -- Exercise 10-6: Search"
echo "  Environment built at: $BASE"
echo "=============================================================="
if ! command -v locate >/dev/null 2>&1; then
  echo "  NOTE: the locate command was not found on this VM."
  echo "        Tell your instructor before starting Section 1."
fi
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo ""
