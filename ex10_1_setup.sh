#!/bin/bash
# BIT 2554 -- Exercise 10-1 Setup: User & Group Accounts
# Run with:  curl -s https://raw.githubusercontent.com/wabplana/2554---Fall-2026/main/ex10_1_setup.sh | sudo bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ─────────────────────────
FINANCE_GID=2210
AUDITORS_GID=2211
JTAYLOR_UID=1501          # jtaylor's primary group (jtaylor) also uses this GID
DKIM_UID=1502             # dkim's primary group is 'auditors'
SVC_ID=850                # atlassync service account UID and GID

JTAYLOR_COMMENT="Jordan Taylor - Finance Analyst"
DKIM_COMMENT="Dana Kim - Internal Auditor"
SVC_COMMENT="Atlas Sync Daemon"

# dkim password-aging values written to /etc/shadow (days since Jan 1, 1970)
DKIM_LASTCHG=20454        # 2026-01-01
DKIM_MIN=1
DKIM_MAX=90
DKIM_WARN=14
DKIM_INACTIVE=30
DKIM_EXPIRE=20819         # 2027-01-01
# ───────────────────────────────────────────────────────────────────────────

# Creating accounts requires root -- this script must be piped into sudo.
if [ "$EUID" -ne 0 ]; then
  echo "❌ This setup script must be run with sudo:"
  echo "   curl -s https://raw.githubusercontent.com/wabplana/2554---Fall-2026/main/ex10_1_setup.sh | sudo bash"
  exit 1
fi

# Under sudo, $HOME is /root -- build the exercise folder in the invoking student's home instead.
STUDENT_USER="${SUDO_USER:-student}"
STUDENT_HOME="$(getent passwd "$STUDENT_USER" | cut -d: -f6)"
if [ -z "$STUDENT_HOME" ]; then
  echo "❌ Could not find a home directory for user '$STUDENT_USER'."
  exit 1
fi
BASE="$STUDENT_HOME/BIT2554/ex10_1"

echo "Building Exercise 10-1 environment..."

# ── 1. Idempotent cleanup: remove any accounts/groups from a previous run ──
for u in projectx jtaylor dkim atlassync; do
  if getent passwd "$u" >/dev/null; then
    userdel -r "$u" >/dev/null 2>&1 || true
    getent passwd "$u" >/dev/null && userdel -f "$u" >/dev/null 2>&1 || true
  fi
done
for g in projectx jtaylor dkim atlassync finance auditors; do
  if getent group "$g" >/dev/null; then
    groupdel "$g" >/dev/null 2>&1 || true
  fi
done
rm -rf "$BASE"

# Make sure no unrelated account already holds one of our fixed IDs.
for id in "$JTAYLOR_UID" "$DKIM_UID" "$SVC_ID"; do
  if getent passwd "$id" >/dev/null; then
    echo "❌ UID $id is already in use by another account -- contact your instructor."
    exit 1
  fi
done
for id in "$FINANCE_GID" "$AUDITORS_GID" "$JTAYLOR_UID" "$SVC_ID"; do
  if getent group "$id" >/dev/null; then
    echo "❌ GID $id is already in use by another group -- contact your instructor."
    exit 1
  fi
done

# ── 2. Groups ──────────────────────────────────────────────────────────────
groupadd -g "$FINANCE_GID"  finance
groupadd -g "$AUDITORS_GID" auditors
groupadd -g "$JTAYLOR_UID"  jtaylor
groupadd -g "$SVC_ID"       atlassync

# ── 3. Regular (human) accounts ────────────────────────────────────────────
# jtaylor: private primary group, no password yet (students set one in the exercise)
useradd -u "$JTAYLOR_UID" -g jtaylor -m -s /bin/bash -c "$JTAYLOR_COMMENT" jtaylor
# dkim: primary group 'auditors', secondary group 'adm' (log access)
useradd -u "$DKIM_UID" -g auditors -G adm -m -s /bin/bash -c "$DKIM_COMMENT" dkim

# finance group: fixed member order, jtaylor as group administrator (/etc/gshadow)
gpasswd -M jtaylor,dkim finance >/dev/null
gpasswd -A jtaylor finance >/dev/null

# ── 4. Service (daemon) account: UID < 1000, no home, no login shell ───────
useradd -r -u "$SVC_ID" -g atlassync -M -d /var/lib/atlassync \
        -s /usr/sbin/nologin -c "$SVC_COMMENT" atlassync

# ── 5. Fixed password-aging values for dkim (/etc/shadow) ──────────────────
chage -d "$DKIM_LASTCHG" -m "$DKIM_MIN" -M "$DKIM_MAX" -W "$DKIM_WARN" \
      -I "$DKIM_INACTIVE" -E "$DKIM_EXPIRE" dkim

# ── 6. Exercise working directory ──────────────────────────────────────────
mkdir -p "$BASE"
cat > "$BASE/account_request.txt" <<'EOF'
ATLAS LOGISTICS -- IT ACCOUNT REQUEST #AR-6104
------------------------------------------------
Requested by : Finance Department
Accounts     : jtaylor (Finance Analyst), dkim (Internal Auditor)
Service acct : atlassync (nightly file sync daemon -- no interactive login)
New project  : create account 'projectx' for the vendor integration project
Action item  : set an initial password for jtaylor and verify she can log in
EOF
# Only chown THIS exercise's folder -- never the whole ~/BIT2554 tree, which may
# contain files from earlier exercises (e.g. immutable/chattr +i files) that root
# cannot chown, which would abort the script under 'set -e'.
STUDENT_GROUP="$(id -gn "$STUDENT_USER")"
chown "$STUDENT_USER":"$STUDENT_GROUP" "$STUDENT_HOME/BIT2554" 2>/dev/null || true
chown -R "$STUDENT_USER":"$STUDENT_GROUP" "$BASE"

# ── 7. Confirmation banner ─────────────────────────────────────────────────
echo ""
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "   Working directory: ~/BIT2554/ex10_1"
