#!/usr/bin/env bash
# Test one AM installation script.
# Usage: test-one.sh <script-name>
# Run from programs/x86_64 (contains the script and a writable results/ dir).
# Env: APP_TIMEOUT, SLOW_APPS
set -uo pipefail

APP="$1"
RESULT_DIR="$PWD/results"
LOG="$RESULT_DIR/log-$APP"
OUT="$RESULT_DIR/out-$APP"

fail() { echo "$APP" >> "$RESULT_DIR/ko-$APP"; exit 1; }
pass() { echo "$APP" >> "$RESULT_DIR/ok-$APP"; exit 0; }

pure_arg=$(echo "$APP" | sed 's/-appimage$//g; s:.*/::')

# ---------- metadata ----------
echo "APP=\"$APP\"" > "$OUT"
if grep -qe "appimage-extract\|mage\$\|tmp/\*mage" "$APP" 2>/dev/null; then
  echo "APPIMAGE='yes'" >> "$OUT"
else
  echo "APPIMAGE='no'" >> "$OUT"
fi
if grep -q "api.github.com" "$APP" 2>/dev/null; then
  echo "GITHUB='yes'" >> "$OUT"
else
  echo "GITHUB='no'" >> "$OUT"
fi
# raw value, no eval
if grep -im1 '^SITE=' "$APP" >/dev/null 2>&1; then
  SITE=$(grep -im1 '^SITE=' "$APP" | sed 's/^SITE=//g; s/^"//; s/"$//')
  echo "SITE=\"$SITE\"" >> "$OUT"
fi

# ---------- AM patches (idempotent) ----------
sed -i '/command -v "$pure_arg"/d; /command already exists/d' /opt/am/modules/install.am
if [[ "$pure_arg" =~ (node|npm) ]]; then
  sed -i 's/_check_if_script_installs_a_metapackage || return 1//g' /opt/am/modules/install.am
fi

# ---------- per-app timeout ----------
TO="$APP_TIMEOUT"
for a in $SLOW_APPS; do [ "$a" = "$pure_arg" ] && TO=1800; done

# ---------- blacklist: cannot be tested here, counted as OK ----------
if [[ "$pure_arg" =~ (animashooter-junior|animashooter-pioneer|kiwix|ryujinx|ryujinx-canary) ]]; then
  echo "Cannot be installed on GitHub Actions: slow download URL or weak domain" | tee -a "$LOG"
  pass
elif [[ "$pure_arg" =~ (mudlet|openxcom|openxcom-extended|vhc-viewer-wayland|vhc-viewer-x11) ]]; then
  echo "Cannot be installed on GitHub Actions" | tee -a "$LOG"
  pass
elif [[ "$pure_arg" =~ (koreader-nightly) ]]; then
  echo "Pending issue report" | tee -a "$LOG"
  pass
fi

[ -f "$APP" ] || { echo "Script not found" | tee -a "$LOG"; fail; }

# ---------- install attempts ----------
ANSWER=y
EXTRA_ARG=""
if grep -qe "^read \|SITE1=" "$APP" || [[ "$pure_arg" =~ (wine) ]]; then
  ANSWER=1
elif [[ "$pure_arg" =~ (bat-extras) ]]; then
  EXTRA_ARG="bat"
fi

for attempt in 1 2 3; do
  echo "### attempt $attempt (timeout ${TO}s)" | tee -a "$LOG"
  echo "$ANSWER" | timeout "$TO" am -i $EXTRA_ARG "$APP" --debug 2>&1 | tee -a "$LOG"
  ARGSNUMB=$(find /opt -maxdepth 2 -name 'remove' -print 2>/dev/null | wc -l)
  [ "$ARGSNUMB" -gt 1 ] && break
  [ "$attempt" -lt 3 ] && sleep 30
done

LASTDIR=$(ls -td /opt/* | head -1 | sed 's:.*/::')

if [ "$LASTDIR" = "am" ]; then
  echo "### 💀 nothing installed: $APP" | tee -a "$LOG"
  fail
elif [ -f "/opt/$LASTDIR/remove" ]; then
  {
    echo
    echo "--- structure of /opt/$LASTDIR ---"
    ls "/opt/$LASTDIR"
  } | tee -a "$LOG"

  if compgen -G "/opt/$LASTDIR/icons/*" >/dev/null; then
    mkdir -p "$RESULT_DIR/icons/$pure_arg"
    cp -r "/opt/$LASTDIR/icons/"* "$RESULT_DIR/icons/$pure_arg/" 2>/dev/null || true
  fi

  echo "--- command in \$PATH ---" | tee -a "$LOG"
  command -v "$pure_arg" | tee -a "$LOG" \
    || command -v "$LASTDIR" | tee -a "$LOG" \
    || ls /usr/local/bin | tee -a "$LOG"

  echo "--- launchers ---" | tee -a "$LOG"
  if [ -n "$(find /usr/local/share/applications/ -type f -name '*AM.desktop' 2>/dev/null)" ]; then
    find /usr/local/share/applications/ -type f -name '*AM.desktop' | tee -a "$LOG"
  else
    echo "No .desktop file available" | tee -a "$LOG"
  fi

  if am -R "$LASTDIR"; then
    pass
  else
    echo "removal failed" | tee -a "$LOG"
    fail
  fi
else
  echo "### 💀 install incomplete: $APP (no remove file in /opt/$LASTDIR)" | tee -a "$LOG"
  fail
fi
