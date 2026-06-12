#!/bin/bash
# ============================================================
#  BIT 2554 – Exercise 2-2 Environment Setup
#  Linux Navigation & Exploring the Filesystem
#
#  Instructor use only. Distribute to students before class.
#  Run with:  bash ex2_2_setup.sh
#
#  FIXED VALUES (update this block each semester if needed):
# ============================================================
PORT=5432
TIMEOUT=120
MAX_CONN=25
IP_ADDR="192.168.10.45"
DNS="8.8.8.8"
LOG_EVENT_LINES=20   # total wc -l will be 22 (header + events + footer)
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

STUDENT="${USER:-student}"
BASE="$HOME/BIT2554/ex2_2"

echo ""
echo -e "${BOLD}======================================================${RESET}"
echo -e "${BOLD}  BIT 2554 – Exercise 2-2 Environment Setup${RESET}"
echo -e "${BOLD}======================================================${RESET}"
echo ""

if [ -d "$BASE" ]; then
    warn "Existing exercise folder found – removing and rebuilding..."
    rm -rf "$BASE"
fi

# ── Directory structure ──────────────────────────────────────
info "Creating directory structure..."
mkdir -p "$BASE/configs"
mkdir -p "$BASE/logs/archive"
mkdir -p "$BASE/projects/alpha/src"
mkdir -p "$BASE/projects/beta"
mkdir -p "$BASE/data/.cache"
success "Directories created."

# ── Files ────────────────────────────────────────────────────
info "Populating files..."

cat > "$BASE/README.txt" << EOF
BIT 2554 – Exercise 2-2
Linux Navigation & Exploring the Filesystem
--------------------------------------------
This folder was created by your instructor's setup script.
Do NOT modify any files unless the exercise tells you to.
EOF

cat > "$BASE/configs/server.conf" << EOF
# Lab Server Configuration
hostname=lab-server-01
port=$PORT
timeout=$TIMEOUT
max_connections=$MAX_CONN
log_level=warn
EOF

cat > "$BASE/configs/network.conf" << EOF
# Network Settings
interface=eth0
ip_address=$IP_ADDR
subnet_mask=255.255.255.0
gateway=192.168.10.1
dns_primary=$DNS
EOF

cat > "$BASE/configs/.maintenance" << EOF
scheduled=Sunday 02:00
window_minutes=30
contact=admin@lab.local
EOF

{
    echo "--- System Log Archive ---"
    for i in $(seq 1 $LOG_EVENT_LINES); do
        DAY=$(( (i % 28) + 1 ))
        printf "2025-03-%02d 0%d:%02d:%02d [INFO]  Service check #%d passed.\n" \
            "$DAY" "$(( i % 9 + 8 ))" "$(( i * 3 % 60 ))" "$(( i * 7 % 60 ))" "$i"
    done
    echo "--- End of Archive ---"
} > "$BASE/logs/archive/system.log"

cat > "$BASE/logs/archive/error.log" << EOF
2025-03-01 03:14:22 [ERROR] Disk usage exceeded 85% threshold.
2025-03-04 07:55:01 [ERROR] Failed login attempt from 10.0.0.44.
2025-03-11 14:02:47 [ERROR] Service 'netd' restarted unexpectedly.
EOF

cat > "$BASE/logs/current.log" << EOF
$(date '+%Y-%m-%d %H:%M:%S') [INFO]  Exercise environment initialised for $STUDENT.
$(date '+%Y-%m-%d %H:%M:%S') [INFO]  Host: $(hostname -s 2>/dev/null || hostname)
EOF

cat > "$BASE/projects/alpha/src/main.sh" << 'EOF'
#!/bin/bash
# Alpha project launcher stub
echo "Project Alpha – placeholder script"
echo "Do not execute during the exercise."
EOF

cat > "$BASE/projects/beta/notes.txt" << EOF
Project Beta Internal Notes
Owner: $STUDENT
Status: restricted
EOF

{
    echo "ID,Name,Score"
    for i in $(seq 1 12); do
        echo "$i,Student_$i,$(( (i * 17 + 43) % 40 + 60 ))"
    done
} > "$BASE/data/records.txt"

echo "cache_token=a3f9c2e1b7d4" > "$BASE/data/.cache/temp.dat"
ln -sf "../../logs/current.log" "$BASE/configs/active_log"

success "Files populated."

# ── Permissions ──────────────────────────────────────────────
info "Applying permissions..."
chmod 640 "$BASE/configs/network.conf"       # -rw-r-----
chmod 444 "$BASE/logs/archive/error.log"     # -r--r--r--
chmod 755 "$BASE/projects/alpha/src/main.sh" # -rwxr-xr-x
chmod 700 "$BASE/projects/beta"              # drwx------
chmod 700 "$BASE/data/.cache"                # drwx------
success "Permissions applied."

echo ""
echo -e "${BOLD}------------------------------------------------------${RESET}"
echo -e "${BOLD}  Setup complete! Exercise environment is ready.${RESET}"
echo -e "${BOLD}------------------------------------------------------${RESET}"
echo -e "  Exercise folder : ${CYAN}$BASE${RESET}"
echo ""
