#!/bin/bash
# =====================================================================
# BIT 2554 -- In-Class Exercise 10-13: Package Management
# Builds custom .deb packages and a local APT repository so every answer
# in the exercise only exists inside this environment.
#
# Creates:
#   ~/BIT2554/ex10_13/debs/            local .deb files (installed with dpkg)
#   /opt/bit2554/repo/                 local APT repository (flat repo)
#   /etc/apt/sources.list.d/bit2554-local.sources
#
# Needs sudo (writes /opt and /etc/apt). Students may be asked for their
# password once. Safe to re-run: removes the exercise packages and rebuilds.
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ──────────────────
LEDGER_VER="4.2.7-3"          # local .deb (dpkg section)
LEDGER_CODE="LDG-58213"
LEDGER_COMPANY="Drillfield Supply Co."
CALC_VER="1.5.0-2"            # dependency, available only from the repo
CALC_MIN="1.5"
SALES_TAX="5.3"
MAP_VER="3.1.4-1"             # installed from the repo with apt
MAPDATA_VER="2.0.9-1"
MAPDATA_MIN="2.0"
MAP_CODE="MAP-7741"
MAP_DEFAULT="Pamplin Hall"
MAINTAINER="BIT 2554 Packaging Team <bit2554-pkg@example.edu>"
# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/ex10_13"
REPO="/opt/bit2554/repo"
SOURCES="/etc/apt/sources.list.d/bit2554-local.sources"
PKGS="vtledger vt-campusmap vtcalc-lib vt-mapdata"

command -v dpkg-deb >/dev/null || { echo "ERROR: dpkg-deb not found -- run this on the Kali VM."; exit 1; }

echo "This setup needs administrator rights (sudo). Enter your password if asked."
sudo -v

# 1. Remove any previous run (idempotent) ---------------------------------
installed=""
for p in $PKGS; do
  if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -qv "not-installed"; then
    installed="$installed $p"
  fi
done
if [ -n "$installed" ]; then
  echo "Removing packages from a previous run:$installed"
  sudo dpkg --purge --force-depends $installed >/dev/null 2>&1 || true
fi
rm -rf "$BASE"
sudo rm -rf /opt/bit2554
sudo rm -f "$SOURCES"

mkdir -p "$BASE/debs"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Helper: build a .deb from a staging dir ----------------------------------
build_deb() {   # $1 = staging dir, $2 = output file
  find "$1" -type d -exec chmod 755 {} +
  dpkg-deb --root-owner-group --build "$1" "$2" >/dev/null
}

# 2. vtledger (local .deb, amd64 + i386 decoy) ------------------------------
make_ledger() {   # $1 = architecture
  local d="$BUILD/vtledger_$1"
  mkdir -p "$d/DEBIAN" "$d/usr/bin" "$d/etc/vtledger"
  cat > "$d/DEBIAN/control" <<EOF
Package: vtledger
Version: $LEDGER_VER
Architecture: $1
Maintainer: $MAINTAINER
Depends: vtcalc-lib (>= $CALC_MIN)
Section: utils
Priority: optional
Description: small-business ledger summary tool
 Prints a summary of the ledger configured in /etc/vtledger.
EOF
  echo "/etc/vtledger/vtledger.conf" > "$d/DEBIAN/conffiles"
  cat > "$d/etc/vtledger/vtledger.conf" <<EOF
# vtledger configuration
company=$LEDGER_COMPANY
fiscal_year_start=07-01
ledger_code=$LEDGER_CODE
EOF
  cat > "$d/usr/bin/vtledger" <<'EOF'
#!/bin/bash
CONF=/etc/vtledger/vtledger.conf
RATES=/usr/share/vtcalc/rates.table
code=$(grep '^ledger_code=' "$CONF" | cut -d= -f2)
company=$(grep '^company=' "$CONF" | cut -d= -f2)
tax=$(grep '^sales_tax=' "$RATES" | cut -d= -f2)
echo "VTLedger -- $company"
echo "Ledger code: $code"
echo "Sales tax rate (from vtcalc-lib): ${tax}%"
EOF
  chmod 755 "$d/usr/bin/vtledger"
  chmod 644 "$d/etc/vtledger/vtledger.conf"
  build_deb "$d" "$BASE/debs/vtledger_${LEDGER_VER}_$1.deb"
}
make_ledger amd64
make_ledger i386

# 3. Repository packages --------------------------------------------------
mkdir -p "$BUILD/repo"

# vtcalc-lib (dependency of vtledger)
d="$BUILD/vtcalc-lib"
mkdir -p "$d/DEBIAN" "$d/usr/share/vtcalc"
cat > "$d/DEBIAN/control" <<EOF
Package: vtcalc-lib
Version: $CALC_VER
Architecture: all
Maintainer: $MAINTAINER
Section: libs
Priority: optional
Description: shared rate tables for VT business tools
 Tax and rate data used by vtledger.
EOF
printf "# vtcalc rate table\nsales_tax=%s\nlate_fee=1.5\n" "$SALES_TAX" > "$d/usr/share/vtcalc/rates.table"
chmod 644 "$d/usr/share/vtcalc/rates.table"
build_deb "$d" "$BUILD/repo/vtcalc-lib_${CALC_VER}_all.deb"

# vt-mapdata (dependency of vt-campusmap)
d="$BUILD/vt-mapdata"
mkdir -p "$d/DEBIAN" "$d/usr/share/vt-mapdata"
cat > "$d/DEBIAN/control" <<EOF
Package: vt-mapdata
Version: $MAPDATA_VER
Architecture: all
Maintainer: $MAINTAINER
Section: misc
Priority: optional
Description: building data files for vt-campusmap
 Data files only; not useful on their own.
EOF
cat > "$d/usr/share/vt-mapdata/buildings.txt" <<'EOF'
Pamplin Hall
Burruss Hall
Torgersen Hall
McBryde Hall
Newman Library
Squires Student Center
Goodwin Hall
Durham Hall
Randolph Hall
Whittemore Hall
Derring Hall
Davidson Hall
Owens Hall
Hahn Hall
EOF
chmod 644 "$d/usr/share/vt-mapdata/buildings.txt"
build_deb "$d" "$BUILD/repo/vt-mapdata_${MAPDATA_VER}_all.deb"

# vt-campusmap (installed with apt; pulls in vt-mapdata)
d="$BUILD/vt-campusmap"
mkdir -p "$d/DEBIAN" "$d/usr/bin" "$d/etc/vt-campusmap"
cat > "$d/DEBIAN/control" <<EOF
Package: vt-campusmap
Version: $MAP_VER
Architecture: all
Maintainer: $MAINTAINER
Depends: vt-mapdata (>= $MAPDATA_MIN)
Section: utils
Priority: optional
Description: text directory of Blacksburg campus buildings
 Lists campus buildings from the vt-mapdata package.
EOF
echo "/etc/vt-campusmap/campusmap.conf" > "$d/DEBIAN/conffiles"
printf "# vt-campusmap configuration\ndefault_building=%s\nmap_code=%s\n" "$MAP_DEFAULT" "$MAP_CODE" > "$d/etc/vt-campusmap/campusmap.conf"
cat > "$d/usr/bin/vt-campusmap" <<'EOF'
#!/bin/bash
DATA=/usr/share/vt-mapdata/buildings.txt
CONF=/etc/vt-campusmap/campusmap.conf
code=$(grep '^map_code=' "$CONF" | cut -d= -f2)
def=$(grep '^default_building=' "$CONF" | cut -d= -f2)
echo "VT Campus Map ($code)"
echo "Buildings on file: $(wc -l < "$DATA")"
echo "Default building: $def"
EOF
chmod 755 "$d/usr/bin/vt-campusmap"
chmod 644 "$d/etc/vt-campusmap/campusmap.conf"
build_deb "$d" "$BUILD/repo/vt-campusmap_${MAP_VER}_all.deb"

# 4. Repository index (Packages + Release) -----------------------------------
: > "$BUILD/repo/Packages"
for deb in "$BUILD"/repo/*.deb; do
  f=$(basename "$deb")
  {
    dpkg-deb -f "$deb"
    echo "Filename: ./$f"
    echo "Size: $(stat -c %s "$deb")"
    echo "MD5sum: $(md5sum "$deb" | cut -d' ' -f1)"
    echo "SHA256: $(sha256sum "$deb" | cut -d' ' -f1)"
    echo
  } >> "$BUILD/repo/Packages"
done
gzip -9nk "$BUILD/repo/Packages"
{
  echo "Origin: BIT2554"
  echo "Label: BIT2554 Local Repository"
  echo "Suite: bit2554"
  echo "Codename: bit2554"
  echo "Date: $(date -u -R)"
  echo "Architectures: all amd64"
  echo "Description: Local package repository for BIT 2554 Exercise 10-13"
  echo "MD5Sum:"
  for f in Packages Packages.gz; do
    echo " $(md5sum "$BUILD/repo/$f" | cut -d' ' -f1) $(stat -c %s "$BUILD/repo/$f") $f"
  done
  echo "SHA256:"
  for f in Packages Packages.gz; do
    echo " $(sha256sum "$BUILD/repo/$f" | cut -d' ' -f1) $(stat -c %s "$BUILD/repo/$f") $f"
  done
} > "$BUILD/repo/Release"

sudo mkdir -p "$REPO"
sudo cp "$BUILD"/repo/* "$REPO/"
sudo chmod 755 /opt/bit2554 "$REPO"
sudo chmod 644 "$REPO"/*

# 5. APT source for the local repository -------------------------------------
sudo tee "$SOURCES" >/dev/null <<EOF
# BIT 2554 local repository (Exercise 10-13)
Types: deb
URIs: file:$REPO
Suites: ./
Trusted: yes
EOF
sudo chmod 644 "$SOURCES"

chmod 644 "$BASE"/debs/*.deb

# 6. Confirmation banner -------------------------------------------------------
echo ""
echo "=============================================================="
echo "  BIT 2554 -- Exercise 10-13: Package Management"
echo "  Local packages:  $BASE/debs"
echo "  Local repo:      $REPO"
echo "=============================================================="
echo "✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
