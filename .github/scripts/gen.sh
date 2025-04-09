#!/usr/bin/env bash

if [ -f results/tested ]; then
  echo "tested exist"
  if diff -q appslist results/tested; then
    echo "Everything checked"
    echo "skip=true" >> $GITHUB_OUTPUT
    exit 0
  else
    echo "Getting temp list"
    comm -23 appslist results/tested > totest_tmp.list
  fi
else
  echo "First run!"
  cp appslist totest_tmp.list
fi
if [ -f results/excluded ]; then
  echo "Excluded exists"
  comm -23 totest_tmp.list results/excluded > totest.list
  if [ ! -s totest.list ]; then
    echo "List is empty"
    echo " 🏁 Nothing to test 🏁" >> $GITHUB_STEP_SUMMARY
    echo "skip=true" >> $GITHUB_OUTPUT
    exit 0
  fi
else
  echo "Creating new list"
  mv totest_tmp.list totest.list
fi
if [ ! -z "${{ github.event.inputs.what_test }}" ]; then
  echo "Testing only: ${{ github.event.inputs.what_test }}"
  FILES="${{ github.event.inputs.what_test }}"
elif [ "${{ github.event.inputs.retest_excluded }}" == 'true' ]; then
  echo "Testing excluded"
  if [ -f results/excluded ]; then
    if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
      echo "Used workflow dispatch"
      how_many="${{ github.event.inputs.how_many }}"
      if [ -z "$how_many" ]; then
        echo "Don't have numbers"
        how_many="${{ env.TOTEST }}"
      fi
    else
      echo "Shedule or push?"
      echo "how_many=${{ env.TOTEST }}"
      how_many=${{ env.TOTEST }}
      if [ -z "$how_many" ]; then
        echo "Still don't exist"
        how_many="$TOTEST"
      fi
    fi
    cat results/excluded > totest.list
  else
    echo "Nothing excluded!"
    echo "Nothing excluded!" >> $GITHUB_STEP_SUMMARY
    echo "skip=true" >> $GITHUB_OUTPUT
    exit 0
  fi
else
  if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
    echo "Used workflow dispatch"
    how_many="${{ github.event.inputs.how_many }}"
    if [ -z "$how_many" ]; then
      echo "Don't have numbers"
      how_many="${{ env.TOTEST }}"
    fi
  else
    echo "Shedule or push?"
    echo "how_many=${{ env.TOTEST }}"
    how_many=${{ env.TOTEST }}
    if [ -z "$how_many" ]; then
      echo "Still don't exist"
      how_many="$TOTEST"
    fi
  fi
  FILES=$(head -n "$how_many" totest.list || cat totest.list)
fi
if [ -z ${FILES} ]; then
  echo "Skipping FILES is empty" >> $GITHUB_STEP_SUMMARY
  echo "skip=true" >> $GITHUB_OUTPUT
  exit 0
fi
echo '-------------------------------------------------------------'
echo 'Testing files:'
echo '-------------------------------------------------------------'
echo "${FILES}"
echo '-------------------------------------------------------------'
MATRIX="{\"include\": ["
for file in $FILES; do
  MATRIX+="{\"file\": \"$file\"},"
done
MATRIX="${MATRIX%,}]}"
echo "matrix=$MATRIX" >> $GITHUB_OUTPUT
