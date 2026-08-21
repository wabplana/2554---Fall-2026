#!/bin/bash
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──
SUMMARY_TEXT="Q3 revenue totaled \$128,400 across all regions."
NOTES_TEXT="Draft notes - not yet finalized."
DRAFT_TEXT="This is a rough draft awaiting final review."
# ───────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex9_8"

# 1. Remove and rebuild if folder exists (idempotent)
rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

# 2. reports/ -- pre-existing files students will cp during Section 2
mkdir -p reports
echo "$SUMMARY_TEXT" > reports/quarterly_summary.txt
echo "$NOTES_TEXT" > reports/notes.txt

# 3. draft.txt -- pre-existing file at BASE for the mv/rename question in Section 3
echo "$DRAFT_TEXT" > draft.txt

# 4. scratch/ -- a genuinely empty directory for the rmdir success case in Section 4
#    (archive/, project/, backup_reports/, empty_folder/, and meeting_notes.txt are
#    all created by the STUDENT during the exercise itself -- not staged here.)
mkdir -p scratch

# 5. Confirmation banner -- must match the Setup box subtitle text exactly
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
