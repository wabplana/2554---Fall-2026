#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
PROJECT_CODE="ATL-2291"
EMPLOYEE_COUNT="47"
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/HW2"

# 1. Remove and rebuild if folder exists (idempotent)
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# 2. Company profile info file (Section 1 — orientation)
cat > company_profile.txt << EOF
Department: Business Analytics
ProjectCode: ${PROJECT_CODE}
EmployeeCount: ${EMPLOYEE_COUNT}
EstablishedYear: 2011
EOF

# 3. Hidden files (Section 1 — ls -a)
cat > .sync_status << 'EOF'
STATUS: SYNCED
Last checked: 09/01/2026
EOF

cat > .README_INTERNAL << 'EOF'
Internal use only. Do not distribute outside the Business Analytics team.
EOF

# 4. Disguised file for the `file` command (Section 2)
cat > invoice_receipt.pdf << 'EOF'
#!/bin/bash
echo "This is not actually a PDF."
EOF
chmod 755 invoice_receipt.pdf

# 5. Read-only file for permissions (Section 2)
cat > readonly_policy.txt << 'EOF'
Company Data Retention Policy
Records must be retained for a minimum of 7 years.
This file is intentionally read-only.
EOF
chmod 444 readonly_policy.txt

# 6. Pre-existing directory to trigger the mkdir "already exists" error (Section 3)
mkdir -p project_alpha

# 7. docs/ — source files for the cp & mv organizing task (Section 4)
mkdir -p docs
cat > docs/report1_backup.txt << 'EOF'
Backup copy of Q3 client report.
Do not edit directly.
EOF
cat > docs/report2.txt << 'EOF'
Draft client report - Q4 revision.
Pending manager review.
EOF
cat > docs/meeting_agenda.txt << 'EOF'
1. Budget review
2. Staffing update
3. Client escalations
EOF

# 8. staging/ — pre-existing empty directory to trigger the mv "moves into" gotcha (Section 5)
mkdir -p staging

# 9. old_drafts/ — non-empty directory to trigger rmdir's "not empty" error (Section 6)
mkdir -p old_drafts
cat > old_drafts/leftover_notes.txt << 'EOF'
Scratch notes from last sprint.
EOF

# 10. logs/ — source files for the multi-step reorganization task (Section 8)
mkdir -p logs
cat > logs/app.log << 'EOF'
2026-09-08 09:00:01 INFO app started
EOF
cat > logs/error.log << 'EOF'
2026-09-08 09:15:22 ERROR connection timeout
EOF
cat > logs/debug.log << 'EOF'
2026-09-08 09:00:05 DEBUG init complete
EOF
cat > logs/temp.log << 'EOF'
2026-09-08 09:00:00 TRACE scratch data
EOF

# 11. draft_notes.txt / final_notes.txt — for the cp -i overwrite prompt (Section 9)
cat > draft_notes.txt << 'EOF'
DRAFT - internal use only.
EOF
cat > final_notes.txt << 'EOF'
FINAL - approved for distribution.
EOF

# 12. temp_a/temp_b/temp_c — fully nested, empty directories for rmdir -p (Section 9)
mkdir -p temp_a/temp_b/temp_c

# 13. status_report.txt — for the mv -v verbose test (Section 9)
cat > status_report.txt << 'EOF'
Status: On track.
EOF

# 14. old_config.txt / new_config.txt — fixed (non-runtime-dependent) timestamps for the
#     cp -u test. Explicit dates make the outcome identical for every student regardless
#     of when they run the script.
cat > old_config.txt << 'EOF'
OUTDATED CONFIG
EOF
cat > new_config.txt << 'EOF'
UPDATED CONFIG v2
EOF
touch -d "2020-01-01" old_config.txt
touch -d "2030-01-01" new_config.txt

# 15. Print confirmation banner
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
