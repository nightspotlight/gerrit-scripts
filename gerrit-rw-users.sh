#!/usr/bin/env bash

#set -euxo pipefail

# requires: jq
# requires: curl

GERRIT_PROJECT="$1" # pass a Gerrit project name here to get a list of its users,
                    # who have read/write access to that project
GERRIT_URL="https://gerrit-server.example.org/a"
GERRIT_CREDENTIALS="${GERRIT_CREDENTIALS}:-'u_api:***'"
CURL_OPTS=(-s -L -u "${GERRIT_CREDENTIALS}" -H 'Accept: application/json')

traverse_parents() {
  # this function recursively gets parents of the provided Gerrit project
  local project="$1" # Gerrit project name
  local parent
  declare -a output
  parent="$(curl "${CURL_OPTS[@]}" "${GERRIT_URL}/access/?project=${project}" \
    | tail -n +2 \
    | jq -cr ".\"${project}\".inherits_from.id // empty")"
  output[0]="${parent}"

  while test "${parent}"; do
    parent="$(curl "${CURL_OPTS[@]}" "${GERRIT_URL}/access/?project=${parent}" \
      | tail -n +2 \
      | jq -cr ".\"${parent}\".inherits_from.id // empty")"
    project="${parent}"
    test "${parent}" && output+=("${parent}") || break
  done

  echo "${output[@]}"
}

for project in "${GERRIT_PROJECT}" $(traverse_parents "${GERRIT_PROJECT}"); do
  # get group IDs with allowed "read", "push", "submit" permissions
  jq_query_groups=".\"${project}\".local[].permissions \
    | .read, .push, .submit \
    | select(.rules[]?.action == \"ALLOW\") \
    | .rules \
    | keys \
    | join(\",\")"
  # get list of usernames in each group
  jq_query_group_members=".[].username"

  for group in $(curl "${CURL_OPTS[@]}" "${GERRIT_URL}/access/?project=${project}" \
    | tail -n +2 \
    | jq -cr "${jq_query_groups}" \
    | tr ',' '\n' \
    | sort -u \
    | grep -Eo '[0-9a-f]{40}') # exclude group IDs like "global:Registered Users"
  do project_groups_dirty+=("${group}")
  done

  # make a deduplicated array of group IDs
  project_groups_clean=($(printf '%s\n' "${project_groups_dirty[@]}" | sort -u))

  for group in "${project_groups_clean[@]}"; do
    for member in $(curl "${CURL_OPTS[@]}" "${GERRIT_URL}/groups/${group}/members/?recursive" \
      | tail -n +2 \
      | jq -cr "${jq_query_group_members}" \
      | sort -u)
    do group_members_dirty+=("${member}")
    done
  done

  # make a deduplicated array of usernames
  group_members_clean=($(printf '%s\n' "${group_members_dirty[@]}" | sort -u))
done

echo "${group_members_clean[@]}" | tr ' ' '\n'
