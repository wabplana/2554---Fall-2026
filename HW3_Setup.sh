#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
# (No semester-specific numeric config needed for this exercise -- all file
# contents below are the fixed values students will read/manipulate.)
# ─────────────────────────────────────────────────────

BASE="$HOME/BIT2554/HW3"

# 1. Remove and rebuild if folder exists (idempotent)
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# 2. portcheck.sh -- custom executable script with a fixed --help/-h banner,
#    used to test "quick usage summary" lookups (Section 2) without a man page.
cat > portcheck.sh << 'PORTCHECK_EOF'
#!/bin/bash
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat << 'HELP_EOF'
Usage: portcheck.sh [OPTIONS]
Check status of monitored network ports.

  -v, --verbose    show detailed port status
  -h, --help       display this help and exit
HELP_EOF
  exit 0
fi
echo "Port check complete: all monitored ports responding."
PORTCHECK_EOF
chmod 755 portcheck.sh

# 3. server_status.txt -- fixed one-line file used by the Section 5 alias task.
cat > server_status.txt << 'EOF'
STATUS: All systems operational.
EOF

# 4. inventory_master.txt -- fixed 4-line file used by the Section 7
#    overwrite-vs-append redirection task.
cat > inventory_master.txt << 'EOF'
Warehouse Inventory Report - Q3 2026
SKU-1001: Widget A - 120 units
SKU-1002: Widget B - 75 units
SKU-1003: Widget C - 200 units
EOF

# 5. region_codes.txt -- fixed, deliberately unsorted list used by the
#    Section 8 input-redirection task.
cat > region_codes.txt << 'EOF'
West
East
North
South
Central
EOF

# NOTE: "missing_region" is intentionally NOT created -- Section 8 relies on
# it not existing, to generate a real, reproducible error message.

# 6. shipment_events.txt -- fixed 4-line file (one exact duplicate line) used
#    by the Section 9 word/byte-count task and the Section 10 sort|uniq|wc task.
cat > shipment_events.txt << 'EOF'
Shipment SHIP-204 departed the warehouse
Shipment SHIP-118 arrived at port
Shipment SHIP-204 departed the warehouse
Shipment SHIP-350 cleared customs
EOF

# 7. support_tickets.txt -- fixed 5-line file (2 "open", 3 "closed") used by
#    the Section 9 grep -v task and the Section 10 grep | tee task.
cat > support_tickets.txt << 'EOF'
TCK-401 open Printer not responding
TCK-402 closed VPN access restored
TCK-403 open Email sync delayed
TCK-404 closed Password reset completed
TCK-405 closed Firewall rule updated
EOF

# 8. Apply permissions
chmod 644 server_status.txt inventory_master.txt region_codes.txt shipment_events.txt support_tickets.txt

# 9. Confirmation banner -- exact text must match the Setup box subtitle in
#    the exercise document (BIT2554_Exercise_Template_Guide.md).
echo ""
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo ""
