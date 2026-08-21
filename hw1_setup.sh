#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
CONF_PORT=8447
CONF_TIMEOUT=30
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/hw1"

# 1. Remove and rebuild if folder exists (idempotent)
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# 2. Department data tree (FHS-style config/data practice, hidden files/dirs)
mkdir -p department_data/finance/.archive
mkdir -p department_data/hr
mkdir -p department_data/it

echo "Q1 revenue: \$482,910" > department_data/finance/q1_report.txt
echo "Prior year archive - do not distribute" > department_data/finance/.archive/old_report.txt

echo "employee_id,name,department" > department_data/hr/employee_roster.csv
echo "1042,J. Rivera,Finance" >> department_data/hr/employee_roster.csv
echo "HR eyes only: pending review" > department_data/hr/.hr_notes.txt

cat > department_data/it/server_config.conf << EOF
service=inventory-api
port=${CONF_PORT}
timeout=${CONF_TIMEOUT}
log_level=warn
EOF
echo "Maintenance completed nightly at 02:00" > department_data/it/maintenance.log

# 3. System logs with staggered modification times (sorting practice)
mkdir -p system_logs
echo "app started" > system_logs/app.log
echo "backup completed successfully" > system_logs/backup.log
echo "authentication successful for student" > system_logs/auth.log
touch -d "3 days ago" system_logs/app.log
touch -d "2 days ago" system_logs/backup.log
touch -d "1 hour ago" system_logs/auth.log

# 4. Scripts directory (executable file, restricted directory)
mkdir -p scripts/secure
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
echo "Deploying build..."
EOF
chmod 755 scripts/deploy.sh
chmod 700 scripts/secure

# 5. A file with no extension but a real shebang, to test the `file` command
mkdir -p shell_check
cat > shell_check/mystery_file << 'EOF'
#!/bin/bash
echo "If you can read this, you found it with the right command."
EOF

# 6. Link lab (hard vs. symbolic links)
mkdir -p link_lab
echo "This is the original file used for the linking exercise." > link_lab/original.txt

# 7. Confirmation banner -- must match the Setup box subtitle text exactly
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
