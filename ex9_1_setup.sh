#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
# GUI_CODE is a fixed, non-guessable value students can only obtain by
# actually navigating to the Desktop with the file manager (Section 1) --
# not something answerable from general Linux knowledge.
GUI_CODE="K7XQ-2M9P"
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex9_1"

echo "=== BIT 2554 -- Exercise 9-1 Setup ==="
echo "Building exercise environment at: $BASE"

# 1. Remove and rebuild if folder exists (idempotent)
if [ -d "$BASE" ]; then
    echo "Existing exercise folder found -- removing and rebuilding for a clean start..."
    rm -rf "$BASE"
fi

# 2. Create directory structure
mkdir -p "$BASE"
cd "$BASE"

# 3. Populate files with specific fixed content

# A short orientation README -- this exercise is entirely conceptual/system-level
# (no navigation commands yet), so keep students anchored to one directory.
cat > README.txt << 'EOF'
Welcome to Exercise 9-1 -- Linux System Operation & Shell Basics.

This exercise does not require you to move around the filesystem -- you will
stay in this directory (~/BIT2554/ex9_1) the entire time. Every command you
need is given to you exactly as it should be typed, directly in each
question.
EOF

# A fixed mock boot-sequence log for Section 3 (boot process & systemd).
# Every student gets an identical log, so the PID/stage answers are exact-match
# gradable, while still tracing the same five-stage sequence covered in lecture.
cat > boot_sequence.log << 'EOF'
BOOT SEQUENCE LOG -- BIT 2554 Reference Capture
================================================
timestamp     stage           pid    detail
00:00.482     firmware        --     UEFI POST complete, boot device located. Linux is not yet running.
00:01.117     bootloader      --     GRUB loaded kernel image vmlinuz-6.6.15-amd64 into memory.
00:01.930     kernel_init     0      Kernel took control of CPU and memory; hardware drivers initializing.
00:02.004     systemd_start   1      systemd started as PID 1 -- the first user-space process.
00:04.558     login_ready     742    Login prompt issued on tty1; system ready for authentication.
================================================
End of capture.
EOF

# A file placed on the Desktop -- found only by navigating there with the
# GUI file manager (not the terminal), for Section 1's GUI verification question.
mkdir -p "$HOME/Desktop"
cat > "$HOME/Desktop/gui_verification.txt" << EOF
BIT 2554 -- GUI Navigation Verification
========================================
If you are reading this, you successfully opened the file manager from
the top bar and navigated to the Desktop -- nice work.

Verification code: $GUI_CODE
EOF

# 4. Apply permissions (keep everything readable; nothing exotic this week)
chmod 644 README.txt boot_sequence.log "$HOME/Desktop/gui_verification.txt"

# 5. Print confirmation banner
echo ""
echo "=================================================="
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "=================================================="
echo ""
echo "Exercise directory: $BASE"
echo "Files created:"
ls -la "$BASE"
echo ""
echo "A file manager verification file was also placed on your Desktop."
echo ""
echo "Next step: cd into $BASE, then begin Section 1 of the exercise document."
