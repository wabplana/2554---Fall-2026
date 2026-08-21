#!/bin/bash
set -e
set -o pipefail

# ── FIXED VALUES (update this block each semester) ──
SITE_CODE="NAV-7734"
MANIFEST_ID="8825-B"
ASSET_CODE="AX-552"
PING_LINE="PING NODE-12: reply in 4ms"
CRITICAL_NODE="node-12"
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex9_3"

# 1. Remove and rebuild if folder exists (idempotent)
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# 2. Hidden file
cat > .field_notes << EOF
Site-Code: ${SITE_CODE}
EOF

# 3. reports/ with nested archive/
mkdir -p reports/archive

# shift_log.dat -- exactly 8192 bytes
head -c 8192 /dev/zero | tr '\0' 'x' > reports/shift_log.dat

# q3_summary.txt -- small fixed text file
cat > reports/q3_summary.txt << EOF
Quarterly Summary
------------------
Region: East
Status: Reviewed
EOF

cat > reports/archive/old_manifest.log << EOF
Manifest-ID: ${MANIFEST_ID}
Archived: TRUE
EOF

# 4. toolkit/ with a mislabeled script
mkdir -p toolkit
cat > toolkit/diagnostics.txt << 'EOF'
#!/bin/bash
echo "Running diagnostics..."
echo "All systems nominal."
EOF

# 5. less demo file -- 40 lines, one CRITICAL line buried in the middle
: > server_status.log
for i in $(seq 1 20); do
  echo "INFO: node-$(printf '%02d' "$i") heartbeat OK" >> server_status.log
done
echo "CRITICAL: disk usage 91% on ${CRITICAL_NODE}" >> server_status.log
for i in $(seq 21 40); do
  echo "INFO: node-$(printf '%02d' "$i") heartbeat OK" >> server_status.log
done

# 6. history demo file
cat > ping_result.txt << EOF
${PING_LINE}
EOF

# 7. hard link / symlink / broken symlink demo
cat > primary_record.txt << EOF
ASSET-CODE: ${ASSET_CODE}
EOF
ln primary_record.txt primary_record_hardlink.txt
ln -s primary_record.txt primary_record_link
ln -s missing_file.txt ghost_link

# 8. Confirmation banner
echo "=================================================="
echo " Exercise 9-3 environment ready at: $BASE"
echo "=================================================="
