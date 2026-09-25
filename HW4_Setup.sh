#!/bin/bash
# BIT 2554 -- Homework Assignment 4 Setup
# File & Directory Permissions / User & Group Accounts
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──────────────────────
VAULT_CODE="4418-KESTREL"
BACKUP_CODE="MRD-7734"
REPORT_ID="QR-5206"
HR_REVIEW_CYCLE="Q4-2026"
NEW_ACCOUNT="hw4intern"      # account the student creates during the HW
# ────────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/HW4"

# 1. Idempotent cleanup -- undo anything the homework itself changes that
#    would otherwise block a clean rebuild (immutable attribute, missing
#    execute bits on directories, the account the student creates).
if [ -d "$BASE" ]; then
  echo "Existing HW4 directory found -- rebuilding it from scratch..."
  POLICY="$BASE/policies/retention_policy.txt"
  if [ -f "$POLICY" ] && lsattr "$POLICY" 2>/dev/null | awk '{print $1}' | grep -q i; then
    echo "  retention_policy.txt is still immutable -- removing the attribute (sudo password may be requested)."
    sudo chattr -i "$POLICY"
  fi
  chmod -R u+rwx "$BASE" 2>/dev/null || true
  rm -rf "$BASE"
fi

if id "$NEW_ACCOUNT" &>/dev/null; then
  echo "Account '$NEW_ACCOUNT' already exists from a previous attempt -- removing it (sudo password may be requested)."
  sudo userdel "$NEW_ACCOUNT" 2>/dev/null || echo "  WARNING: could not remove '$NEW_ACCOUNT'. Close any shell still switched to it (type exit) and re-run this script."
fi

# 2. Directory structure
mkdir -p "$BASE"/{reports,scripts,tools,public,vault,shared_team,dropbox,policies,accounts}
cd "$BASE"

# 3. Populate files
cat > reports/q3_summary.txt <<EOF
MERIDIAN HEALTH ANALYTICS -- Q3 SUMMARY
Report ID: $REPORT_ID
Status: FINAL
EOF

cat > reports/payroll.csv <<'EOF'
employee_id,name,department,salary_band
E1041,Alicia Martin,IT,B4
E1057,Jorge Morales,Finance,B3
E1090,Thanh Nguyen,IT,B1
EOF

cat > reports/budget_draft.txt <<'EOF'
FY27 Budget Draft -- DO NOT DISTRIBUTE
Department: Operations
EOF

cat > .hr_notes <<EOF
HR internal notes -- review cycle $HR_REVIEW_CYCLE
EOF

cat > scripts/backup.sh <<EOF
#!/bin/bash
echo "Running nightly backup check..."
echo "Backup verification code: $BACKUP_CODE"
EOF

cat > scripts/cleanup.sh <<'EOF'
#!/bin/bash
echo "Cleaning temporary files..."
EOF

cat > tools/report_gen <<'EOF'
#!/bin/bash
echo "Generating department report..."
EOF

cat > public/announcement.txt <<'EOF'
All-hands meeting moved to Friday at 10:00 AM.
EOF

cat > vault/access_code.txt <<EOF
VAULT ACCESS CODE: $VAULT_CODE
EOF

cat > policies/retention_policy.txt <<'EOF'
Records Retention Policy v3 -- records are retained for 7 years.
EOF

cat > policies/handoff_notes.txt <<'EOF'
Handoff notes for the incoming IT intern.
EOF

# Sample account files from a fictional company server (atlas-fs01) --
# same colon-separated formats as the real /etc files covered in lecture.
cat > accounts/passwd.sample <<'EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
syslog:x:104:110::/home/syslog:/usr/sbin/nologin
bind:x:115:121::/var/cache/bind:/usr/sbin/nologin
svc_backup:x:998:998:Nightly Backup Service:/var/lib/backup:/usr/sbin/nologin
amartin:x:1001:1001:Alicia Martin - IT Admin:/home/amartin:/bin/bash
jmorales:x:1002:1002:Jorge Morales - Finance:/home/jmorales:/bin/bash
sysmaint:x:0:0:System Maintenance:/root:/bin/bash
tnguyen:x:1003:1003:Thanh Nguyen - IT Intern:/home/tnguyen:/bin/bash
EOF

cat > accounts/shadow.sample <<'EOF'
root:$6$Vb7kQp2L$Ndg0x1Ha9wPq4ZrE7m3JcKf5sTuY8oiA2lB6vWnX0dRyGhe:20301:0:99999:7:::
daemon:*:20301:0:99999:7:::
syslog:*:20301:0:99999:7:::
bind:*:20301:0:99999:7:::
svc_backup:!:20355:0:99999:7:::
amartin:$6$Rt4mZ8wQ$Kp3vB7nYx2Lc9QeHs5fJ1gTdW6oUa0iMrE4yNzXbPlCq:20388:1:90:14:30::
jmorales:$6$Hy2nC5vX$Wq8eRt1Yu4Io7Pa3Sd6Fg9Hj0Kl2Zx5Cv8Bn1Mq4We7R:20410:1:60:10:15:20819:
sysmaint:$6$Lp9oK3jH$Gf6Ds2Aq8Wz5Xe1Cr4Vt7By0Nu3Mi6Lo9Kj2Hg5Fd8Sa:20399:0:99999:7:::
tnguyen:$6$Mn6bV1cX$Za4Sx7Dc0Fv3Gb6Hn9Jm2Ku5Li8Oy1Pt4Rw7Eq0Tz3Yu:20405:1:90:14:30:20454:
EOF

cat > accounts/gshadow.sample <<'EOF'
root:*::
adm:*::syslog,amartin
sudo:*::amartin,sysmaint,tnguyen
finance:*:jmorales:jmorales
backup:!::svc_backup
EOF

# 4. Apply permissions (directories with restricted bits are set LAST so the
#    script can still write inside them above).
chmod 600 reports/payroll.csv
chmod 640 reports/q3_summary.txt
chmod 664 reports/budget_draft.txt
chmod 640 .hr_notes
chmod 644 scripts/backup.sh
chmod 757 scripts/cleanup.sh
chmod 644 tools/report_gen
chmod 666 public/announcement.txt
chmod 644 policies/retention_policy.txt policies/handoff_notes.txt
chmod 644 accounts/*.sample
chmod 755 shared_team
chmod 777 dropbox
chmod 644 vault/access_code.txt
chmod 600 vault

# 5. Confirmation banner
echo ""
echo "=================================================================="
echo "  BIT 2554 -- Homework Assignment 4 environment built at:"
echo "  $BASE"
echo "=================================================================="
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
