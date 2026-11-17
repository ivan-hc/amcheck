#!/bin/bash
# Aggregate one run's chunk outputs into the tracked results lists.
# Single source of truth, called by the "Process log results" step and by
# the Push-step retry path (which rebuilds the same aggregation on a fresh
# base after losing a push race). CWD must be the workspace root.
# Byte order matters (comm --check-order downstream): pin C locale so this
# behaves identically on any runner or local machine.
export LC_ALL=C
mkdir -p results
rm -f failing
for LogFile in results/out-* results/job-*/out-*; do
  echo '-----------------------------------------------------------------'
  echo "$LogFile out"
  echo '-----------------------------------------------------------------'
  [ -f "$LogFile" ] && cat "$LogFile"
  echo '-----------------------------------------------------------------'
  [ -f "$LogFile" ] || continue
  jobdir=$(dirname "$LogFile")
  appname=$(basename "$LogFile" | cut -d'-' -f2-)
  echo '-----------------------------------------------------------------'
  echo "$appname"
  echo '-----------------------------------------------------------------'
  KoFile="$jobdir/ko-$appname"
  OkFile="$jobdir/ok-$appname"
  SkipFile="$jobdir/skip-$appname"
  if [[ -f "$KoFile" ]]; then
    echo "$appname" | tee -a failing results/excluded
    rm -f "$KoFile"
    # A retested app that fails again must not linger in tested.
    if [ -f results/tested ]; then grep -vxF "$appname" results/tested > results/tested.tmp || true; mv results/tested.tmp results/tested; fi
    cat "$LogFile" | grep -E '(^.*=.*$|^.*----.*$)' >> results/log
    sort -u results/excluded -o results/excluded
    sort -u failing -o failing
    git add results/excluded
  elif [[ -f "$SkipFile" ]]; then
    # Policy skip (blocklist/static): not a failure, but the app stays out
    # of the tested set. Recorded in excluded (the don't-retest list) without
    # touching the failing record, so the verdict job stays green on skips.
    echo "$appname" >> results/excluded
    rm -f "$SkipFile"
    if [ -f results/tested ]; then grep -vxF "$appname" results/tested > results/tested.tmp || true; mv results/tested.tmp results/tested; fi
    cat "$LogFile" | grep -E '(^.*=.*$|^.*----.*$)' >> results/log
    sort -u results/excluded -o results/excluded
    git add results/excluded
  else
    if [[ -f "$OkFile" ]]; then
      cat "$LogFile" | grep -E '(^.*=.*$|^.*----.*$)' >> results/log
      echo "$appname" >> results/tested
      # A retested app that passes now must leave the excluded list.
      if [ -f results/excluded ]; then grep -vxF "$appname" results/excluded > results/excluded.tmp || true; mv results/excluded.tmp results/excluded; fi
    else
      # No marker: the install died before verdict (runner lost, step
      # timeout, set -e abort). Partial output is not evidence: leave the
      # app unlisted so the next sweep retries it instead of recording a
      # false tested. Trace stays in this job's log (out file echoed above).
      echo "NO-MARKER: $appname has output but neither ok nor ko marker; leaving unlisted for retry"
    fi
  fi
  echo '-----------------------------------------------------------------' >> results/log
  rm -f "$LogFile" "$jobdir/log-$appname" "$jobdir/ok-$appname" "$jobdir/skip-$appname"
done
sort -u results/tested -o results/tested
mkdir -p /tmp/keep
for f in tested tested.prev excluded log; do
  [ -f "results/$f" ] && cp "results/$f" "/tmp/keep-$f"
done
rm -rf results
mkdir -p results
for f in tested tested.prev excluded log; do
  [ -f "/tmp/keep-$f" ] && cp "/tmp/keep-$f" "results/$f"
done
git add -A results
if git status --porcelain -- results | grep -v -e 'results/tested$' -e 'results/tested.prev$' -e 'results/excluded$' -e 'results/log$' | grep -q '^A '; then
  echo "unexpected new tracked file under results/"
  exit 1
fi
