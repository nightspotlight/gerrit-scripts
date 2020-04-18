#!/usr/bin/env bash

# requires: openssh
# requires: jq

# function definitions
. functions.sh

query='status:open project:my-project branch:master "cool new feature"'

for n in $(gerrit_cmd query --format json -- "${query}" | jq -cr 'select(.number) | .number')
do gerrit_cmd review --abandon ${n},1
done
