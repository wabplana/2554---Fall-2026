#!/bin/bash
# =====================================================================
# BIT 2554 -- In-Class Exercise 10-20 setup script
# Regular Expressions
#
# Scenario: Drillfield Distributors, a small office-supply company. Its
# data files were exported from several systems and are full of
# inconsistent entries -- exactly the kind of text regex is built to search.
# The script builds:
#   ~/BIT2554/ex10_20/data/staff.txt     employee first names (with blank lines)
#   ~/BIT2554/ex10_20/data/skus.txt      inventory SKU codes
#   ~/BIT2554/ex10_20/data/badges.txt    5-digit badge IDs (some mistyped)
#   ~/BIT2554/ex10_20/data/catalog.txt   product colors from two suppliers
#   ~/BIT2554/ex10_20/data/orders.txt    order numbers entered by hand
#   ~/BIT2554/ex10_20/data/zips.txt      customer ZIP codes
#   ~/BIT2554/ex10_20/data/phones.txt    customer phone numbers (one blank line)
#   ~/BIT2554/ex10_20/data/invoices.txt  invoice lines with dollar amounts
#   ~/BIT2554/ex10_20/logs/app.log       application log (levels at line start)
#
# No sudo needed. Idempotent: re-running deletes and rebuilds the folder.
# Every file below is FIXED text. Changing any line changes the answer key --
# re-verify the key (run each question's command) after any edit.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ───────────────────
COMPANY="Drillfield Distributors"
LOG_HOST="payroll03"     # appears in logs/app.log
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex10_20"

# 1. Remove and rebuild if the folder already exists
rm -rf "$BASE"
mkdir -p "$BASE/data" "$BASE/logs"

# 2. Section 1 -- the dot and anchors (3 blank lines on purpose)
cat > "$BASE/data/staff.txt" <<'EOF'
Alana
Brandon
Carla
Dana

Dawn
Devon
Jean
Joan
Johan

John
Jon
Jonah
Kayla

Logan
Marla
Shana
EOF

# 3. Section 2 -- character sets
cat > "$BASE/data/skus.txt" <<'EOF'
AB-1042
bx-2201
CX-3307
Q-4410
TR-77A1
pk-5503
HD-0045
MNO-8812
EOF

cat > "$BASE/data/badges.txt" <<'EOF'
40517
40522
4O533
40541
A40550
40566
4058
40-579
EOF

# 4. Section 4 -- ? and * quantifiers
cat > "$BASE/data/catalog.txt" <<'EOF'
Desk lamp      color: black
Office chair   colour: grey
Notebook       colouur: blue
Monitor stand  color: gray
Stapler        colr: red
EOF

cat > "$BASE/data/orders.txt" <<'EOF'
ORD-1001   Lane Stadium catering
ORD--1002  Drillfield banners
ORD1003    Burruss Hall chairs
ORDER 1004 manual entry
REF-1005   customer return
EOF

# 5. Section 5 -- + and {} quantifiers
cat > "$BASE/data/zips.txt" <<'EOF'
24061
2406
240611
24060-1234
22030
9021O
EOF

cat > "$BASE/data/phones.txt" <<'EOF'
540-231-6000
540-231-600
(540) 231-6000
5402316000

703-555-0142
540-231-60001
EOF

# 6. Section 6 -- escaping
cat > "$BASE/data/invoices.txt" <<'EOF'
INV-2201  Office chairs  $149.99
INV-2202  Toner 4-pack   $89.50
INV-2203  Desk lamps     149X99
INV-2204  Monitor arms   $1499.00
EOF

# 7. Sections 3 and 6 -- log file (level is the first word of each line)
cat > "$BASE/logs/app.log" <<EOF
INFO     scheduler started for $COMPANY
ERROR    disk quota exceeded on /srv/orders
WARN     retrying connection to $LOG_HOST
INFO     backup job queued
FAIL     nightly export aborted
INFO     user jdoe logged in
ERROR    invoice 5521 rejected
INFO     retry after FAIL on node 2
CRITICAL database replica offline
WARN     certificate expires in 9 days
FAIL     login for user kwong
INFO     cleanup finished
EOF

chmod 644 "$BASE"/data/*.txt "$BASE/logs/app.log"

# 8. Confirmation banner
echo ""
echo "=============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/ex10_20"
echo "=============================================================="
