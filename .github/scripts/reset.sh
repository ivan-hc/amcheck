#!/usr/bin/env bash

echo "### stats RESET" >> $GITHUB_STEP_SUMMARY
cp results/log log.old 2>/dev/null && git add log.old || echo "Log deleted without backup"
cp results/excluded excluded.old 2>/dev/null && git add excluded.old || echo "Excluded deleted without backup"
rm -rf results
git config --global user.name "${{ github.repository_owner }}"
git config --global user.email "noreply@github.com"
git rm -r results
git commit -m "reset stats"
git push --force
git clean -f
