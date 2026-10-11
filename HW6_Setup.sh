#!/bin/bash
# =====================================================================
# BIT 2554 -- Homework Assignment 6 setup script
# Package Management + The Environment and Shell Variables
#
# Scenario: Drillfield Logistics (DLX), a shipping company. The script:
#   * builds a set of DLX .deb packages,
#   * publishes most of them in a local APT repository (/opt/bit2554/hw6repo)
#     defined by /etc/apt/sources.list.d/bit2554-hw6.sources,
#   * pre-installs dlx-labelprint and the legacy dlx-routeplan 1.8.0, and leaves
#     dlx-oldscan removed-with-config (rc),
#   * stages the local .deb files in ~/BIT2554/HW6/debs,
#   * installs the hw6-catchup command (/usr/local/bin/hw6-catchup): if a student
#     cannot complete a step that a later question depends on, the later question
#     tells them which "hw6-catchup <checkpoint>" to run so they can keep going.
#     It only sets package state -- it never prints answers.
#
# It does NOT run "apt update" -- the student does that as part of the homework.
# Idempotent: re-running purges every dlx-* package and rebuilds everything.
# Does not touch the Exercise 10-13 repository (/opt/bit2554/repo).
# =====================================================================
set -e          # exit immediately on any error
set -o pipefail # catch errors in pipes

# ── FIXED VALUES (update this block each semester) ───────────────────
MAINT="DLX Platform Team <platform-team@drillfield-logistics.example>"
REPO_TICKET="REL-5530"

LABEL_VER="1.2.0-1"
OLDSCAN_VER="0.9.4-2";   SCANNER_ID="SCN-30618"

SHIPCALC_VER="3.4.2-1";  SHIP_ORIGIN="Blacksburg, VA"
RATES_VER="2.1.5-1";     BASE_CENTS=650; PER_LB_CENTS=85; RATE_TABLE="RT-2026-Q4"
CURRENCY_VER="1.0.7-1";  CURRENCY="USD"

CUSTOMS_PRO_VER="6.1.0-1"; CUSTOMS_LITE_VER="6.0.4-1"
TARIFFS_VER="3.2.8-1";   TARIFF_SCHEDULE="TS-2026-B"; DECL_SEQ="71946"
CUSTOMS_HOMEPAGE="https://drillfield-logistics.example/customs-pro"

ROUTE_OLD_VER="1.8.0-1"; LEGACY_ROUTE_CODE="RTE-4471"
ROUTE_NEW_VER="2.0.3-1"
GEODATA_VER="4.0.2-1";   GEO_CODE="GEO-6619"

# ─────────────────────────────────────────────────────────────────────

BASE="$HOME/BIT2554/HW6"
REPO="/opt/bit2554/hw6repo"
LOCALDEBS="/opt/bit2554/hw6local"      # private copies used by hw6-catchup
CATCHUP="/usr/local/bin/hw6-catchup"
SRC_FILE="/etc/apt/sources.list.d/bit2554-hw6.sources"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

echo "Setting up Homework 6 (this uses sudo -- enter your password if asked)..."
sudo -v

# ---------------------------------------------------------------------
# 1. Reset: purge any dlx-* packages from a previous run, remove the HW6
#    repository, its sources file, its cached package lists, and ~/BIT2554/HW6
# ---------------------------------------------------------------------
OLD_PKGS=$(dpkg-query -W -f='${Package} ${db:Status-Abbrev}\n' 'dlx-*' 2>/dev/null \
           | awk '$2 != "un" {print $1}' || true)
if [ -n "$OLD_PKGS" ]; then
  # shellcheck disable=SC2086
  sudo dpkg --purge --force-depends $OLD_PKGS >/dev/null 2>&1 || true
fi
sudo rm -rf "$REPO" "$SRC_FILE" "$LOCALDEBS" "$CATCHUP"
sudo rm -f /var/lib/apt/lists/*bit2554_hw6repo* \
           /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin
rm -rf "$BASE"

# ---------------------------------------------------------------------
# 2. Package builder
#    mkpkg <name> <version> <arch> <depends|-> <installed-kb> <short desc> <long desc> [homepage]
#    Files are staged beforehand under $BUILD/<name>_<version>_<arch>/root/...
#    Anything under /etc is registered as a conffile.
# ---------------------------------------------------------------------
pkgroot() { echo "$BUILD/$1_$2_$3/root"; }

mkpkg() {
  local name=$1 ver=$2 arch=$3 deps=$4 size=$5 short=$6 long=$7 home=$8
  local dir; dir="$(pkgroot "$name" "$ver" "$arch")"
  mkdir -p "$dir/DEBIAN"
  {
    echo "Package: $name"
    echo "Version: $ver"
    echo "Section: misc"
    echo "Priority: optional"
    echo "Architecture: $arch"
    [ "$deps" != "-" ] && echo "Depends: $deps"
    echo "Installed-Size: $size"
    echo "Maintainer: $MAINT"
    [ -n "$home" ] && echo "Homepage: $home"
    echo "Description: $short"
    echo " $long"
  } > "$dir/DEBIAN/control"
  if [ -d "$dir/etc" ]; then
    (cd "$dir" && find etc -type f | sed 's|^|/|' | sort) > "$dir/DEBIAN/conffiles"
  fi
  find "$dir" -type d -exec chmod 755 {} +
  find "$dir" -type f ! -path '*/usr/bin/*' -exec chmod 644 {} +
  [ -d "$dir/usr/bin" ] && chmod 755 "$dir"/usr/bin/*
  dpkg-deb --root-owner-group --build "$dir" "$BUILD/out/${name}_${ver}_${arch}.deb" >/dev/null
}
mkdir -p "$BUILD/out"

# ---- dlx-labelprint (pre-installed) ---------------------------------
R=$(pkgroot dlx-labelprint "$LABEL_VER" amd64); mkdir -p "$R/usr/bin" "$R/usr/share/dlx"
cat > "$R/usr/share/dlx/carriers.list" <<'EOF'
UPS Ground
FedEx Express
USPS Priority
DHL International
Old Dominion Freight
Estes Express
EOF
cat > "$R/usr/bin/dlx-labelprint" <<'EOF'
#!/bin/bash
echo "Drillfield Logistics -- Label Printer v1.2.0"
echo "Carriers on file: $(grep -c . /usr/share/dlx/carriers.list)"
EOF
mkpkg dlx-labelprint "$LABEL_VER" amd64 - 24 \
  "DLX shipping label printer" "Prints carrier shipping labels for DLX warehouse staff."

# ---- dlx-oldscan (installed, then removed -> rc) ---------------------
R=$(pkgroot dlx-oldscan "$OLDSCAN_VER" amd64); mkdir -p "$R/usr/bin" "$R/etc/dlx-oldscan"
cat > "$R/etc/dlx-oldscan/scanner.conf" <<EOF
# DLX legacy barcode scanner settings
scanner_id=$SCANNER_ID
port=/dev/ttyUSB0
EOF
cat > "$R/usr/bin/dlx-oldscan" <<'EOF'
#!/bin/bash
echo "Drillfield Logistics -- Legacy Barcode Scanner v0.9.4"
EOF
mkpkg dlx-oldscan "$OLDSCAN_VER" amd64 - 16 \
  "DLX legacy barcode scanner driver" "Retired scanner driver for older DLX warehouse hardware."

# ---- dlx-currency (repo) ---------------------------------------------
R=$(pkgroot dlx-currency "$CURRENCY_VER" all); mkdir -p "$R/usr/share/dlx-currency"
printf 'currency=%s\nsymbol=$\n' "$CURRENCY" > "$R/usr/share/dlx-currency/currency.tbl"
mkpkg dlx-currency "$CURRENCY_VER" all - 12 \
  "DLX currency tables" "Currency codes shared by DLX pricing tools."

# ---- dlx-rates (repo; depends on dlx-currency) -----------------------
R=$(pkgroot dlx-rates "$RATES_VER" all); mkdir -p "$R/usr/share/dlx-rates"
printf 'table=%s\nbase_cents=%s\nper_lb_cents=%s\n' "$RATE_TABLE" "$BASE_CENTS" "$PER_LB_CENTS" \
  > "$R/usr/share/dlx-rates/rates.tbl"
mkpkg dlx-rates "$RATES_VER" all "dlx-currency (>= 1.0)" 14 \
  "DLX shipping rate tables" "Base and per-pound shipping rates used by dlx-shipcalc."

# ---- dlx-shipcalc (local .deb; depends on dlx-rates) -----------------
build_shipcalc() {
  local arch=$1
  R=$(pkgroot dlx-shipcalc "$SHIPCALC_VER" "$arch"); mkdir -p "$R/usr/bin" "$R/etc/dlx-shipcalc"
  printf '# DLX shipping calculator settings\norigin=%s\n' "$SHIP_ORIGIN" > "$R/etc/dlx-shipcalc/shipcalc.conf"
  cat > "$R/usr/bin/dlx-shipcalc" <<'EOF'
#!/bin/bash
RATES=/usr/share/dlx-rates/rates.tbl
CUR=/usr/share/dlx-currency/currency.tbl
CONF=/etc/dlx-shipcalc/shipcalc.conf
echo "Drillfield Logistics -- Shipping Calculator v3.4.2"
if [ $# -ne 1 ] || ! [[ $1 =~ ^[0-9]+$ ]]; then
  echo "Usage: dlx-shipcalc <weight in whole pounds>"; exit 2
fi
if [ ! -r "$RATES" ]; then echo "dlx-shipcalc: ERROR -- cannot open rate table $RATES"; exit 1; fi
if [ ! -r "$CUR" ];   then echo "dlx-shipcalc: ERROR -- cannot open currency table $CUR"; exit 1; fi
base=$(sed -n 's/^base_cents=//p' "$RATES")
per=$(sed -n 's/^per_lb_cents=//p' "$RATES")
table=$(sed -n 's/^table=//p' "$RATES")
cur=$(sed -n 's/^currency=//p' "$CUR")
origin=$(sed -n 's/^origin=//p' "$CONF" 2>/dev/null)
total=$(( base + per * $1 ))
printf 'Origin     : %s\n' "${origin:-(unknown)}"
printf 'Weight     : %s lb\n' "$1"
printf 'Rate table : %s\n' "$table"
printf 'Total      : %d.%02d %s\n' $((total / 100)) $((total % 100)) "$cur"
printf 'Quote ID   : SHP-%d\n' $(( (total * 7 + 1031) % 90000 + 10000 ))
EOF
  mkpkg dlx-shipcalc "$SHIPCALC_VER" "$arch" "dlx-rates (>= 2.1)" 20 \
    "DLX shipping cost calculator" "Quotes shipping costs by weight using the DLX rate tables."
}
build_shipcalc amd64
build_shipcalc arm64

# ---- dlx-tariffs (repo) ----------------------------------------------
R=$(pkgroot dlx-tariffs "$TARIFFS_VER" all); mkdir -p "$R/usr/share/dlx-tariffs"
printf 'schedule=%s\ndecl_seq=%s\n' "$TARIFF_SCHEDULE" "$DECL_SEQ" > "$R/usr/share/dlx-tariffs/tariffs.tbl"
mkpkg dlx-tariffs "$TARIFFS_VER" all - 30 \
  "DLX tariff schedules" "Import and export tariff schedules for DLX international shipments."

# ---- dlx-customs-pro (repo; depends on currency + tariffs) -----------
R=$(pkgroot dlx-customs-pro "$CUSTOMS_PRO_VER" all); mkdir -p "$R/usr/bin" "$R/etc/dlx-customs-pro"
printf '# DLX customs declaration settings\nbroker=Hokie Customs Brokerage\n' > "$R/etc/dlx-customs-pro/customs.conf"
cat > "$R/usr/bin/dlx-customs-pro" <<'EOF'
#!/bin/bash
TAR=/usr/share/dlx-tariffs/tariffs.tbl
CUR=/usr/share/dlx-currency/currency.tbl
echo "Drillfield Logistics -- Customs Declarations Pro v6.1.0"
if [ ! -r "$TAR" ] || [ ! -r "$CUR" ]; then echo "dlx-customs-pro: ERROR -- required data tables are missing"; exit 1; fi
printf 'Broker           : %s\n' "$(sed -n 's/^broker=//p' /etc/dlx-customs-pro/customs.conf 2>/dev/null)"
printf 'Tariff schedule  : %s\n' "$(sed -n 's/^schedule=//p' "$TAR")"
printf 'Currency         : %s\n' "$(sed -n 's/^currency=//p' "$CUR")"
printf 'Declaration code : CUS-%s\n' "$(sed -n 's/^decl_seq=//p' "$TAR")"
EOF
mkpkg dlx-customs-pro "$CUSTOMS_PRO_VER" all "dlx-currency (>= 1.0), dlx-tariffs (>= 3.2)" 36 \
  "DLX customs declarations (full edition)" \
  "Prepares international customs declarations for DLX shipments." "$CUSTOMS_HOMEPAGE"

# ---- dlx-customs-lite (repo; second search hit) ----------------------
R=$(pkgroot dlx-customs-lite "$CUSTOMS_LITE_VER" all); mkdir -p "$R/usr/bin"
printf '#!/bin/bash\necho "Drillfield Logistics -- Customs Lite v6.0.4"\n' > "$R/usr/bin/dlx-customs-lite"
mkpkg dlx-customs-lite "$CUSTOMS_LITE_VER" all - 10 \
  "DLX customs form helper (lite edition)" "Fills in basic customs forms for small DLX shipments."

# ---- dlx-geodata (repo) ----------------------------------------------
R=$(pkgroot dlx-geodata "$GEODATA_VER" all); mkdir -p "$R/usr/share/dlx-geodata"
printf 'geo_code=%s\nregion_count=9\n' "$GEO_CODE" > "$R/usr/share/dlx-geodata/geodata.tbl"
mkpkg dlx-geodata "$GEODATA_VER" all - 210 \
  "DLX route map data" "Road and depot map data used by the DLX route planner."

# ---- dlx-routeplan 1.8.0 (local .deb, legacy) ------------------------
R=$(pkgroot dlx-routeplan "$ROUTE_OLD_VER" amd64); mkdir -p "$R/usr/bin"
cat > "$R/usr/bin/dlx-routeplan" <<EOF
#!/bin/bash
echo "Drillfield Logistics -- Route Planner v1.8.0 (legacy)"
echo "Map data   : built-in (no external map package)"
echo "Route code : $LEGACY_ROUTE_CODE"
EOF
mkpkg dlx-routeplan "$ROUTE_OLD_VER" amd64 - 18 \
  "DLX delivery route planner" "Plans delivery routes for DLX drivers."

# ---- dlx-routeplan 2.0.3 (repo; depends on dlx-geodata) ---------------
R=$(pkgroot dlx-routeplan "$ROUTE_NEW_VER" amd64); mkdir -p "$R/usr/bin"
cat > "$R/usr/bin/dlx-routeplan" <<'EOF'
#!/bin/bash
# Reads its settings from ENVIRONMENT variables only (it runs as a child process).
echo "Drillfield Logistics -- Route Planner v2.0.3"
TBL=/usr/share/dlx-geodata/geodata.tbl
if [ ! -r "$TBL" ]; then echo "dlx-routeplan: ERROR -- map data missing ($TBL)"; exit 1; fi
printf '%-11s: %s\n' "Map data" "$(sed -n 's/^geo_code=//p' "$TBL")"
missing=0
report() {
  local name=$1 label=$2
  if [ -z "${!name+x}" ]; then printf '%-11s: (not set)\n' "$label"; missing=$((missing + 1))
  elif [ -z "${!name}" ]; then printf '%-11s: (empty)\n' "$label"; missing=$((missing + 1))
  else printf '%-11s: %s\n' "$label" "${!name}"; fi
}
report DLX_DEPOT  Depot
report DLX_DRIVER Driver
report DLX_SHIFT  Shift
printf '%-11s: %s\n' "Region" "${DLX_REGION:-(optional -- not set)}"
if [ "$missing" -eq 0 ]; then
  n=$(printf '%s|%s|%s' "$DLX_DEPOT" "$DLX_DRIVER" "$DLX_SHIFT" | cksum | cut -d' ' -f1)
  echo "Status     : READY"
  echo "Route code : RTE-$(( n % 90000 + 10000 ))"
else
  echo "Status     : NOT READY -- $missing required setting(s) missing"
  echo "Route code : (none)"
fi
EOF
mkpkg dlx-routeplan "$ROUTE_NEW_VER" amd64 "dlx-geodata (>= 4.0)" 22 \
  "DLX delivery route planner" "Plans delivery routes for DLX drivers."

# ---------------------------------------------------------------------
# 3. Local APT repository (flat) + sources file
# ---------------------------------------------------------------------
sudo mkdir -p "$REPO"
for p in dlx-currency_${CURRENCY_VER}_all dlx-rates_${RATES_VER}_all \
         dlx-tariffs_${TARIFFS_VER}_all dlx-customs-pro_${CUSTOMS_PRO_VER}_all \
         dlx-customs-lite_${CUSTOMS_LITE_VER}_all dlx-geodata_${GEODATA_VER}_all \
         dlx-routeplan_${ROUTE_NEW_VER}_amd64; do
  sudo cp "$BUILD/out/$p.deb" "$REPO/"
done

PKGS="$BUILD/Packages"; : > "$PKGS"
for deb in "$REPO"/*.deb; do
  {
    dpkg-deb -f "$deb"
    echo "Filename: ./$(basename "$deb")"
    echo "Size: $(stat -c %s "$deb")"
    echo "MD5sum: $(md5sum "$deb" | cut -d' ' -f1)"
    echo "SHA256: $(sha256sum "$deb" | cut -d' ' -f1)"
    echo
  } >> "$PKGS"
done
REL="$BUILD/Release"
{
  echo "Origin: BIT2554"
  echo "Label: BIT2554 HW6 practice repository"
  echo "Date: $(LC_ALL=C date -Ru)"
  echo "MD5Sum:"
  echo " $(md5sum "$PKGS" | cut -d' ' -f1) $(stat -c %s "$PKGS") Packages"
  echo "SHA256:"
  echo " $(sha256sum "$PKGS" | cut -d' ' -f1) $(stat -c %s "$PKGS") Packages"
} > "$REL"
sudo cp "$PKGS" "$REL" "$REPO/"
sudo chmod 755 /opt/bit2554 "$REPO"
sudo chmod 644 "$REPO"/*

sudo tee "$SRC_FILE" >/dev/null <<EOF
# BIT 2554 -- HW6 practice repository (Drillfield Logistics internal mirror)
# Approved under change ticket: $REPO_TICKET
Types: deb
URIs: file:$REPO
Suites: ./
Trusted: yes
EOF
sudo chmod 644 "$SRC_FILE"

# ---------------------------------------------------------------------
# 4. Pre-install dlx-labelprint and legacy dlx-routeplan 1.8.0;
#    install then remove dlx-oldscan (-> rc)
# ---------------------------------------------------------------------
sudo dpkg -i "$BUILD/out/dlx-labelprint_${LABEL_VER}_amd64.deb" >/dev/null
sudo dpkg -i "$BUILD/out/dlx-routeplan_${ROUTE_OLD_VER}_amd64.deb" >/dev/null
sudo dpkg -i "$BUILD/out/dlx-oldscan_${OLDSCAN_VER}_amd64.deb" >/dev/null
sudo dpkg -r dlx-oldscan >/dev/null

# ---------------------------------------------------------------------
# 5. Catch-up command and its private copies of the local .deb files
#    hw6-catchup <checkpoint> resets ONLY the packages the next question needs.
# ---------------------------------------------------------------------
sudo mkdir -p "$LOCALDEBS"
sudo cp "$BUILD/out/dlx-shipcalc_${SHIPCALC_VER}_amd64.deb" \
        "$BUILD/out/dlx-routeplan_${ROUTE_OLD_VER}_amd64.deb" "$LOCALDEBS/"
sudo chmod 755 "$LOCALDEBS"; sudo chmod 644 "$LOCALDEBS"/*

sudo tee "$CATCHUP" >/dev/null <<EOF
#!/bin/bash
# BIT 2554 HW6 catch-up -- puts the DLX packages into the state a question expects,
# so a student who could not finish an earlier step can still continue.
LOCAL=$LOCALDEBS
SRC=$SRC_FILE
SHIPCALC_DEB=\$LOCAL/dlx-shipcalc_${SHIPCALC_VER}_amd64.deb
ROUTE_OLD_DEB=\$LOCAL/dlx-routeplan_${ROUTE_OLD_VER}_amd64.deb
ROUTE_NEW_VER=$ROUTE_NEW_VER
EOF
sudo tee -a "$CATCHUP" >/dev/null <<'EOF'
export DEBIAN_FRONTEND=noninteractive
CHECKPOINTS="fix quote customs upgrade remove routeplan"

usage() {
  echo "Usage: hw6-catchup <checkpoint>"
  echo "Only run this when a homework question tells you to. Checkpoints: $CHECKPOINTS"
  exit 2
}
[ $# -eq 1 ] || usage
case " $CHECKPOINTS " in *" $1 "*) ;; *) usage ;; esac

echo "HW6 catch-up ($1): preparing the DLX packages -- enter your password if asked..."
sudo -v || exit 1

present() { case "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" in ""|un*) return 1 ;; esac; }
purge() {
  local p list=""
  for p in "$@"; do present "$p" && list="$list $p"; done
  # shellcheck disable=SC2086
  [ -n "$list" ] && sudo dpkg --purge --force-depends $list >/dev/null 2>&1
  return 0
}
refresh() {   # refresh only the HW6 repository's catalog
  sudo apt-get update -qq -o Dir::Etc::sourcelist="$SRC" -o Dir::Etc::sourceparts="-" \
       -o APT::Get::List-Cleanup="0" >/dev/null 2>&1 || sudo apt-get update -qq >/dev/null 2>&1
}
shipcalc_unpacked() {   # dlx-shipcalc unpacked by dpkg, dependencies missing
  purge dlx-customs-pro dlx-customs-lite dlx-tariffs dlx-shipcalc dlx-rates dlx-currency
  sudo dpkg -i "$SHIPCALC_DEB" >/dev/null 2>&1
  return 0
}
shipcalc_working() {    # dlx-shipcalc repaired by APT (dlx-rates + dlx-currency auto-installed)
  shipcalc_unpacked
  sudo apt-get install -y -qq -f >/dev/null 2>&1
}
routeplan_new() {
  [ "$(dpkg-query -W -f='${Version} ${db:Status-Abbrev}' dlx-routeplan 2>/dev/null)" = "$ROUTE_NEW_VER ii " ] \
    || sudo apt-get install -y -qq dlx-routeplan >/dev/null 2>&1
}

refresh
case $1 in
  fix)       shipcalc_unpacked ;;
  quote)     shipcalc_working ;;
  customs)   shipcalc_working ;;
  upgrade)   purge dlx-routeplan dlx-geodata
             sudo dpkg -i "$ROUTE_OLD_DEB" >/dev/null 2>&1 ;;
  remove)    shipcalc_working
             sudo apt-get install -y -qq dlx-customs-pro >/dev/null 2>&1
             routeplan_new ;;
  routeplan) routeplan_new ;;
esac
echo "HW6 catch-up ($1) complete -- continue with the question that sent you here."
EOF
sudo chmod 755 "$CATCHUP"

# ---------------------------------------------------------------------
# 6. Student working directory
# ---------------------------------------------------------------------
mkdir -p "$BASE/debs"
cp "$BUILD/out/dlx-shipcalc_${SHIPCALC_VER}_amd64.deb" \
   "$BUILD/out/dlx-shipcalc_${SHIPCALC_VER}_arm64.deb" "$BASE/debs/"

# ---------------------------------------------------------------------
# 7. Confirmation banner
# ---------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "  ✅ SETUP SUCCESSFUL -- you're ready to begin the exercise!"
echo "  Working directory: ~/BIT2554/HW6"
echo "=============================================================="
