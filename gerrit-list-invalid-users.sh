#!/usr/bin/env bash

#set -euxo pipefail

# requires: openldap-clients
# requires: jq
# requires: openssh

# include environment variables with sensitive data
# LDAP_USER
# LDAP_PASSWORD
. .env

# function definitions
. functions.sh

ldapsearch_cmd() {
  local _user _found _status
  _user="$1"
  _found=$(ldapsearch -o nettimeout=10 -H "ldaps://ad.example.org:636" \
    -b "OU=IT Dept,DC=corp,DC=example,DC=org" \
    -D "CN=${LDAP_USER},OU=Security,OU=IT Dept,DC=corp,DC=example,DC=org" \
    -w "${LDAP_PASSWORD}" \
    -s sub cn="${_user}" 2>/dev/null | grep -q 'cn:'; echo $?)
  _status=$?
  result=${_found}
  status=${_status}
}

# prepare SQL query to fetch list of active users
IFS='' read -r -d '' sql << 'EOT' || true
select distinct ea.external_id as external_ids
from accounts as a
left join account_external_ids as ea
  using (account_id)
where
  lower(ea.external_id) like 'gerrit:%'
  and inactive = 'N';
EOT

# fetch list of active users
count=0
for user in $(gerrit_cmd gsql --format JSON_SINGLE -c "\"${sql}\"" \
  | jq -cr '.[] | select(.type=="row") | .columns.external_ids // empty | split(":")[1]')
do
  ldapsearch_cmd "${user}"
  # fail immediately on ldapsearch failure
  if [ ${status} -ne 0 ]; then { echo 'ldapsearch error'; exit 1; }; fi
  # if user is not found in LDAP, record their tkid
  if [ ${result} -ne 0 ]; then invalid_users+=("${user}"); fi
  # check 5 users at a time
  if [ ${count} -lt 5 ]; then count=$((${count}+1)); else sleep 5 && count=0; fi
done

printf '%s\n' "${invalid_users[@]:-"no invalid users"}" | sort
