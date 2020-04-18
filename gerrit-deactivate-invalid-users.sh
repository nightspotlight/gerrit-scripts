#!/usr/bin/env bash

#set -euxo pipefail

# requires: openssh

# function definitions
. functions.sh

file="${1}" # pass file with list of user ids each on separate line
regex='(u|g|s)_\w{1,7}'

while IFS= read -r user; do
  echo -n "account ${user}: "
  [[ "${user}" =~ ${regex} ]] || { echo "skipping invalid tkid"; continue; }
  gerrit_cmd set-account --inactive "${user}"
  if [ $? -ne 0 ]
  then echo "gerrit_cmd error while modifying user"
  else echo "set to inactive"
  fi
done < "${file}"
