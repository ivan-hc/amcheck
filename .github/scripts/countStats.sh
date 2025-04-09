#!/usr/bin/env bash

if [ -f results/tested ]; then
  tested=$(wc -l < results/tested)
else
  tested='0'
fi
if [ -f results/excluded ]; then
  excluded=$(wc -l < results/excluded)
else
  excluded='0'
fi
echo "tested=$tested" >> $GITHUB_OUTPUT
echo "excluded=$excluded" >> $GITHUB_OUTPUT
