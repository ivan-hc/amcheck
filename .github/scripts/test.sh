#!/usr/bin/env bash

set -uo pipefail
mkdir -p results
EXIT_CODE='0'
TEST='0'

# Define the content of the script || Alow testing non existent (for workflow tests)
script_content=$(cat ${{ matrix.file }}) || echo "Testing non exist file! (for workflow test only)"
# Define the pure name of the app
pure_arg=$(echo "${{ matrix.file }}" | sed 's/\-appimage$//g' | sed 's:.*/::')

# Allow installing applications even if the command already exists
sed -i '/command -v "$pure_arg"/d; /command already exists/d' /opt/am/modules/install.am

# Special patches
if [[ "$pure_arg" =~ (node|npm) ]]; then
  sed -i 's/_check_if_script_installs_a_metapackage || return 1//g' /opt/am/modules/install.am
fi

# Install the application

if [[ "$pure_arg" =~ (kvrt|suyu|vikunja) ]]; then
  echo "This application cannot be installed in github actions" | tee -a "results/log-${{ matrix.file }}"
  echo "This application is excluded. Cannot be installed in github actions" >> $GITHUB_STEP_SUMMARY
  echo "${{ matrix.file }}" >> results/ok-${{ matrix.file }}
else

  if [[ "$pure_arg" =~ (appimageupdatetool|gimp|libreoffice|mpv|wine) ]]; then

    echo 1 | timeout "$TIMEOUT"m am -i "${{ matrix.file }}" --debug 2>&1 | tee -a "results/log-${{ matrix.file }}"

  elif [[ "$pure_arg" =~ (bat-extras) ]]; then

    echo y | timeout "$TIMEOUT"m am -i bat --debug 2>/dev/null | tee /dev/null
    echo y | timeout "$TIMEOUT"m am -i "${{ matrix.file }}" --debug 2>&1 | tee -a "results/log-${{ matrix.file }}"

  else

    echo y | timeout "$TIMEOUT"m am -i "${{ matrix.file }}" --debug 2>&1 | tee -a "results/log-${{ matrix.file }}"

  fi

  LASTDIR=$(ls -td /opt/* | head -1 | sed 's:.*/::')

  # If an application is blacklisted, ignore it
  if [ "$LASTDIR" = am ]; then

    if [ "$TEST" == 0 ]; then

      echo "### 💀 ${{ matrix.file }}" >> $GITHUB_STEP_SUMMARY
      echo "${{ matrix.file }}" >> results/ko-${{ matrix.file }}
      exit 0

    elif  [ "$TEST" == 1 ]; then

      echo "Testing non exist file! (for test 2nd test)"
      echo "${{ matrix.file }}" >> results/ko-${{ matrix.file }}
      exit 0

    fi

  # If the last modified directory contains a file named "remove", check the installed files
  elif test -f /opt/"$LASTDIR"/remove; then

    printf "\n-------------------------------------------------------------\n\n"

    # Check structure of directories in /opt
    echo " Structure of the directory in /opt"
    echo ""
    ls /opt/"$LASTDIR" | tee -a "results/log-${{ matrix.file }}"

    printf "\n-------------------------------------------------------------\n\n"

    # Check the command in /usr/local/bin
    echo " Command in \$PATH"
    echo ""
    command -v "$pure_arg" | tee -a "results/log-${{ matrix.file }}" || command -v "$LASTDIR" | tee -a "results/log-${{ matrix.file }}" || ls /usr/local/bin | tee -a "results/log-${{ matrix.file }}"

    printf "\n-------------------------------------------------------------\n\n"

    # Check launchers in /usr/local/share/applications
    echo " Launchers in /usr/local/share/applications" | tee -a "results/log-${{ matrix.file }}"
    echo ""

    if test -f /usr/local/share/applications/*AM.desktop 2>/dev/null; then

       ls /usr/local/share/applications | grep "AM.desktop$" | tee -a "results/log-${{ matrix.file }}"

    elif echo "$script_content" | grep -q -- '^./"$APP" --appimage-extract.*./"$APP".desktop$'; then

       ls /usr/local/share/applications | grep "AM.desktop$" | tee -a "results/log-${{ matrix.file }}"

    else

       echo "No .desktop file available" | tee -a "results/log-${{ matrix.file }}"

    fi

    printf "\n-------------------------------------------------------------\n\n"

      #size=$(cat "results/log-${{ matrix.file }}" | tee /dev/null | grep 'OF DISK SPACE' | cut -d'(' -f2 | cut -d' ' -f1,2)
      #Preversion=$(cat "results/log-${{ matrix.file }}" | tee /dev/null | grep '◆' | tail -1 | head -1)
      #echo "pre version is $Preversion"
      #version=$(echo "$Preversion" | awk '{print $3}')
      #echo "version is $version"

    if [[ "$pure_arg" =~ (appimageupdatetool|gimp|libreoffice|mpv|wine) ]]; then

      size=$(cat "results/log-${{ matrix.file }}" | tee /dev/null | grep 'OF DISK SPACE' | cut -d'(' -f2 | cut -d' ' -f1,2 | tail -1)
      Preversion=$(cat "results/log-${{ matrix.file }}" | tee /dev/null | grep '◆' | tail -2 | head -1)
      echo "pre version is $Preversion"
      version=$(echo "$Preversion" | awk '{print $3}' | cut -d'.' -f1-3)
      echo "version is $version"

    else

      size=$(cat "results/log-${{ matrix.file }}" | tee /dev/null | grep 'OF DISK SPACE' | cut -d'(' -f2 | cut -d' ' -f1,2)
      Preversion=$(cat "results/log-${{ matrix.file }}" | tee /dev/null | grep '◆' | tail -1)
      echo "pre version is $Preversion"
      version=$(cat "results/log-${{ matrix.file }}" | tee /dev/null | grep '◆' | tail -1 | awk '{print $3}')
      echo "version is $version"

    fi

    rawlink=$(grep -E 'https?://' < "results/log-${{ matrix.file }}" | head -1 | cut -d' ' -f4)
    echo "link=${rawlink}" | tee -a "results/out-${{ matrix.file }}"

    echo "size=${size}" | tee -a "results/out-${{ matrix.file }}"
    echo "version=${version}" | tee -a "results/out-${{ matrix.file }}"

    # Remove the application
    am -R "$LASTDIR"
    echo "${{ matrix.file }}" >> results/tested

  # Timeout
  elif [[ $? -eq 124 ]]; then
     echo "### 💥 ${{ matrix.file }} timeout!" >> $GITHUB_STEP_SUMMARY
     #echo "Installation timeout in $TIMEOUT minutes" >> results/log-"${{ matrix.file }}"
     echo "${{ matrix.file }}" >> results/ko-${{ matrix.file }}
     echo "::error title=⛔ Timeout $TIMEOUT minutes reached ERROR 124:: I will try again"
     exit 0 # Don't fail now, we will try again

  # Any other result is a failure
  else
    echo "${{ matrix.file }}" >> results/ko-"${{ matrix.file }}"
    echo "::error title=⛔ ERROR 9:: I will try again"
    #echo "${{ matrix.file }} failed" >> $GITHUB_STEP_SUMMARY
    exit 0 # Don't fail now, we will try again
  fi
fi
