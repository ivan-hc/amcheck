#!/usr/bin/env bash

echo "Excluding: kdegames kdeutils node platform-tools ffwa-" >> $GITHUB_STEP_SUMMARY
sort programs/x86_64-apps | grep -v "\"kdegames\"\|\"kdeutils\"\|\"node\"\|\"platform-tools\"\| ffwa-" | awk '{print $2}' > appslist
x64Count=$(wc -l < appslist)
echo "all=$x64Count" >> $GITHUB_OUTPUT
