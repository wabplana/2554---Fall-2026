#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
# (no tunable numeric config needed for this exercise -- all file contents
#  below are the fixed values students will be tested against)
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex9_17"

# 1. Remove and rebuild if folder exists (idempotent)
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# 2. fruit_unsorted.txt -- unsorted list with non-adjacent duplicates, used to
#    demonstrate why uniq requires a prior sort (Section 5).
cat > fruit_unsorted.txt << 'EOF'
banana
apple
cherry
apple
date
banana
apple
fig
EOF

# 3. access_log.txt -- fixed login event log used for grep/-i and piping
#    demonstrations (Sections 6-7). 10 lines: 4 FAILED, 6 SUCCESS.
cat > access_log.txt << 'EOF'
2026-09-10 08:01:02 LOGIN SUCCESS user=jsmith
2026-09-10 08:02:15 LOGIN FAILED user=unknown
2026-09-10 08:05:44 LOGIN SUCCESS user=agarcia
2026-09-10 08:07:10 LOGIN FAILED user=admin
2026-09-10 08:09:33 LOGOUT SUCCESS user=jsmith
2026-09-10 08:12:01 LOGIN FAILED user=root
2026-09-10 08:15:47 LOGIN SUCCESS user=mjones
2026-09-10 08:20:09 LOGOUT SUCCESS user=agarcia
2026-09-10 08:22:56 LOGIN FAILED user=test
2026-09-10 08:25:00 LOGIN SUCCESS user=mjones
EOF

# 4. shipment_manifest.txt -- fixed 12-line list used for output redirection,
#    head, and tail demonstrations (Sections 1 and 6).
cat > shipment_manifest.txt << 'EOF'
ITEM001 - Wireless Mouse
ITEM002 - USB-C Cable
ITEM003 - Laptop Stand
ITEM004 - Mechanical Keyboard
ITEM005 - Webcam HD
ITEM006 - Monitor Arm
ITEM007 - Desk Lamp
ITEM008 - Cable Organizer
ITEM009 - Laptop Sleeve
ITEM010 - Wireless Charger
ITEM011 - Bluetooth Speaker
ITEM012 - Portable SSD
EOF

# 5. Apply permissions
chmod 644 fruit_unsorted.txt access_log.txt shipment_manifest.txt

# 6. Confirmation banner -- must match the Setup box subtitle in content.js exactly
echo ""
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
