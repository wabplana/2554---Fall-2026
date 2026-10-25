#!/bin/bash
# =====================================================================
# BIT 2554 -- In-Class Exercise 10-27 setup script
# Text Processing
#
# Scenario: New River Outfitters, a small outdoor-gear shop in Blacksburg.
# Its exports and lists are plain text -- exactly what today's text
# processing commands are built for. The script builds:
#   ~/BIT2554/ex10_27/data/staff.txt        staff names (hidden tabs, trailing spaces, a ^M)
#   ~/BIT2554/ex10_27/data/memo.txt         staff memo with runs of blank lines
#   ~/BIT2554/ex10_27/data/sizes.txt        backup file sizes in MB (one per line)
#   ~/BIT2554/ex10_27/data/sales.csv        order export (header + 12 orders)
#   ~/BIT2554/ex10_27/data/rentals.txt      gear rental log, one item per line
#   ~/BIT2554/ex10_27/data/products.txt     product names (5 lines)
#   ~/BIT2554/ex10_27/data/prices.txt       product prices (4 lines -- one missing)
#   ~/BIT2554/ex10_27/data/members_sep.txt  loyalty members, September (sorted)
#   ~/BIT2554/ex10_27/data/members_oct.txt  loyalty members, October (sorted)
#   ~/BIT2554/ex10_27/data/skus.txt         lowercase SKU codes
#   ~/BIT2554/ex10_27/data/.manager_note    hidden ROT13-encoded note
#
# No sudo needed. Idempotent: re-running deletes and rebuilds the folder.
# Every file below is FIXED text. Changing any line changes the answer key --
# re-verify the key (run each question's command) after any edit.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ───────────────────
COMPANY="New River Outfitters"
DISCOUNT_CODE="FIRESIDE20"   # hidden in data/.manager_note (ROT13-encoded)
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex10_27"

# 1. Remove and rebuild if the folder already exists
rm -rf "$BASE"
mkdir -p "$BASE/data"

# 2. Section 1 -- cat -A (tabs, trailing spaces, one Windows line ending)
printf '\tPriya Raman\n'   >  "$BASE/data/staff.txt"
printf 'Marcus Webb   \n'  >> "$BASE/data/staff.txt"   # 3 trailing spaces
printf 'Elena Torres\n'    >> "$BASE/data/staff.txt"
printf 'Marcus Webb\n'     >> "$BASE/data/staff.txt"
printf '\tOwen Fischer\n'  >> "$BASE/data/staff.txt"
printf 'Dana Kim\r\n'      >> "$BASE/data/staff.txt"   # Windows line ending

# 3. Section 1 -- cat -n / -s (15 lines; runs of blank lines on purpose)
cat > "$BASE/data/memo.txt" <<EOF
$COMPANY -- Staff Memo



Winter hours start November 2.

Inventory count is Saturday at 8 AM.


Return policy: 30 days with receipt.




Questions? See the store manager.
EOF

# 4. Section 2 -- sort -n
cat > "$BASE/data/sizes.txt" <<'EOF'
9
120
15
2048
64
512
7
300
EOF

# 5. Sections 2 and 4 -- sales export (every amount is unique: no ties)
cat > "$BASE/data/sales.csv" <<'EOF'
order,region,rep,amount
2001,East,Lopez,450
2002,West,Chen,1275
2003,North,Patel,95
2004,East,Okafor,2310
2005,South,Chen,880
2006,West,Nguyen,1650
2007,East,Patel,310
2008,North,Lopez,1020
2009,South,Okafor,75
2010,East,Chen,540
2011,West,Patel,915
2012,East,Nguyen,1990
EOF

# 6. Section 3 -- uniq (16 lines; exactly one adjacent duplicate: lines 4-5)
cat > "$BASE/data/rentals.txt" <<'EOF'
kayak
tent
bike
kayak
kayak
hammock
tent
paddleboard
kayak
bike
tent
snowshoes
hammock
kayak
bike
tent
EOF

# 7. Section 4 -- paste (prices.txt is one line short on purpose)
cat > "$BASE/data/products.txt" <<'EOF'
Rain jacket
Trail shoes
Headlamp
Water filter
Sleeping bag
EOF

cat > "$BASE/data/prices.txt" <<'EOF'
129.99
89.50
34.95
49.00
EOF

# 8. Section 5 -- comm (both lists already sorted; single-word names so the
#    sort order is the same in every locale)
cat > "$BASE/data/members_sep.txt" <<'EOF'
Abbott
Baker
Castillo
Dawson
Ellis
Fischer
Grant
Hughes
Ibrahim
Jensen
EOF

cat > "$BASE/data/members_oct.txt" <<'EOF'
Baker
Castillo
Ellis
Fischer
Hughes
Ibrahim
Kowalski
Lam
Morales
EOF

# 9. Section 6 -- tr
cat > "$BASE/data/skus.txt" <<'EOF'
kyk-118
tnt-204
bik-339
hmk-412
EOF

# Hidden note, stored ROT13-encoded (tr shifts every letter 13 places)
echo "Staff discount code for November is $DISCOUNT_CODE. Do not share with customers." \
  | tr 'a-zA-Z' 'n-za-mN-ZA-M' > "$BASE/data/.manager_note"

chmod 644 "$BASE"/data/*.txt "$BASE/data/sales.csv" "$BASE/data/.manager_note"

# 10. Confirmation banner
echo ""
echo "=============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/ex10_27"
echo "=============================================================="
