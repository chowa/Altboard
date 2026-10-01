#!/usr/bin/env bash
#
#  check-cla.sh
#
#  Copyright (c) 2026 Altboard
#
#  This file is part of Altboard and is licensed under the Altboard License
#  (the "License"); you may not use this file except in compliance with the
#  License. The full text of the License is in the LICENSE file at the root of
#  the Altboard repository, https://github.com/Altboard/Altboard.
#
#  As far as the law allows, Altboard comes as is, without any warranty or
#  condition, and the licensor will not be liable to you for any damages
#  arising out of the License or the use or nature of Altboard, under any kind
#  of legal claim.
#
#  In short, the License lets you change and build Altboard, and make new works
#  based on it, only for your own personal purposes, without any anticipated
#  commercial application. It also lets you propose changes for inclusion in
#  Altboard, in a fork of the Altboard repository or by sending them to the
#  licensor. Apart from those proposals, you may not distribute Altboard's
#  code, and you may not distribute any build of Altboard, changed or not. The
#  License does not limit any fair use rights you have under the law.
#
#  YOU MAY NOT USE ALTBOARD'S CODE, IN WHOLE OR IN PART, TO CREATE ANY APP OR
#  OTHER PRODUCT THAT YOU PUBLISH, DISTRIBUTE, OR SELL, INCLUDING THROUGH ANY
#  APP STORE, OR THAT YOU USE, OR PLAN TO USE, FOR ANY COMMERCIAL PURPOSE.
#
# shellcheck disable=SC2016 # the single-quoted $ names are jq variables, not shell ones
set -euo pipefail

signatures_path=.github/cla-signatures.json
cla_version=1
maintainer_ids='[223757985]'
today=$(date -u +%F)
data=$(mktemp -d)
problems=()

# Workflow commands are read from output lines, so the message is escaped: text from the
# pull request cannot start a command of its own, and its line breaks reach the annotation.
fail() {
  local message=$1 percent=%
  message=${message//$percent/%25}
  message=${message//$'\r'/%0D}
  echo "::error::${message//$'\n'/%0A}"
  exit 1
}

rules='
  def is_date: . as $text | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") and
    ((try (strptime("%Y-%m-%d") | mktime | strftime("%Y-%m-%d")) catch "") == $text);
  def signers: [.[] | select(type == "object" and (.id | type == "number" and . == floor and . > 0)
    and .cla_version == $version and (.date | is_date)) | .id];
  def exempt: .type == "Bot" or (.id as $id | $maintainers | index($id) != null);
'
jq_with_rules() { jq --argjson version "$cla_version" --argjson maintainers "$maintainer_ids" "$@"; }

entry_for() {
  jq -n --arg login "$1" --argjson id "$2" --argjson cla_version "$cla_version" --arg date "$today" \
    '{$login, $id, $cla_version, $date}' | sed 's/^/    /'
}

read_signatures() {
  local body
  if ! body=$(gh api -H 'Accept: application/vnd.github.raw+json' \
    "repos/$GH_REPO/contents/$signatures_path?ref=$1" 2> "$data/error"); then
    if grep -q '(HTTP 404)' "$data/error"; then
      echo '[]' > "$2"
      return
    fi
    fail "Reading $signatures_path at $1 failed: $(cat "$data/error")"
  fi
  if ! jq empty 2> "$data/error" <<< "$body"; then
    fail "$signatures_path at $1 is not valid JSON: $(cat "$data/error")"
  fi
  jq -c '.signatures? | arrays' <<< "$body" > "$2"
  [[ -s $2 ]] || fail "$signatures_path at $1 has no \"signatures\" array"
}

gh api --paginate "repos/$GH_REPO/pulls/$PR_NUMBER/commits?per_page=100" \
  --jq '.[] | {sha, author, name: .commit.author.name, email: .commit.author.email}' | jq -s . > "$data/commits.json"
listed=$(jq length "$data/commits.json")
if (( listed < PR_COMMITS )); then
  fail "This pull request has $PR_COMMITS commits, more than the $listed the GitHub API lists, so the CLA check cannot see who wrote them all. Split it into smaller pull requests."
fi

jq -n --arg login "$AUTHOR_LOGIN" --argjson id "$AUTHOR_ID" --arg type "$AUTHOR_TYPE" '{$login, $id, $type}' > "$data/author.json"
author_exempt=$(jq_with_rules "$rules exempt" "$data/author.json")
read_signatures "$DEFAULT_BRANCH" "$data/default.json"
read_signatures "$HEAD_SHA" "$data/head.json"
jq_with_rules -c --slurpfile head "$data/head.json" --slurpfile author "$data/author.json" "$rules"'
  signers + [$head[0] | signers | .[] | select(. == $author[0].id or ($author[0] | exempt))]
' "$data/default.json" > "$data/signed.json"

if [[ $author_exempt == false ]]; then
  merge_base=$(gh api "repos/$GH_REPO/compare/$BASE_SHA...$HEAD_SHA" --jq .merge_base_commit.sha)
  read_signatures "$merge_base" "$data/branch-point.json"
  changed=$(jq -c --slurpfile head "$data/head.json" '
    . as $base | [range(length) | select($base[.] != $head[0][.])] | first // empty | $base[.]
  ' "$data/branch-point.json")
  added_for_others=$(jq_with_rules -r --slurpfile base "$data/branch-point.json" --argjson author_id "$AUTHOR_ID" "$rules"'
    .[($base[0] | length):] | signers | map(select(. != $author_id) | tostring) | join(", ")
  ' "$data/head.json")

  if [[ -n $changed ]]; then
    problems+=("Existing entries must stay unchanged and in place; this one is changed, moved or removed: $changed. Put it back as it was in $signatures_path; new entries go after the existing ones.")
  elif [[ -n $added_for_others ]]; then
    problems+=("A pull request can sign the CLA only for its author. Remove the entries with user IDs $added_for_others from $signatures_path, or fix a typo in your own ID.")
  fi
  if ! jq -e --argjson id "$AUTHOR_ID" 'index($id) != null' "$data/signed.json" > /dev/null; then
    problems+=("@$AUTHOR_LOGIN has not signed version $cla_version of CLA.md. Read CLA.md, then add this entry to the end of \"signatures\" in $signatures_path in this pull request:"$'\n'"$(entry_for "$AUTHOR_LOGIN" "$AUTHOR_ID")")
  fi
fi

unsigned_co_authors=$(jq_with_rules -r --slurpfile signed "$data/signed.json" --argjson author_id "$AUTHOR_ID" "$rules"'
  [.[].author | select(. != null and .id != $author_id and (exempt | not))] | unique_by(.id)
  | .[] | select(.id as $id | $signed[0] | index($id) == null) | [.login, .id] | @tsv
' "$data/commits.json")
if [[ -n $unsigned_co_authors ]]; then
  while IFS=$'\t' read -r login id; do
    problems+=("@$login authored commits in this pull request but has not signed version $cla_version of CLA.md. They sign in a pull request of their own that adds the entry below to the end of \"signatures\" in $signatures_path. After that, a maintainer re-runs this check, or the author of this pull request closes and reopens it:"$'\n'"$(entry_for "$login" "$id")")
  done <<< "$unsigned_co_authors"
fi

unlinked_commits=$(jq -r '
  [.[] | select(.author == null)] | group_by(.email) | .[]
  | (if length == 1 then ["Commit", "is", "it", "commit"] else ["Commits", "are", "them", "commits"] end) as $w
  | "\($w[0]) \(map(.sha[:7]) | join(", ")) \($w[1]) authored by \(.[0].name) <\(.[0].email)>, an address not linked to a GitHub account, so the CLA check cannot tell who wrote \($w[2]). Add the address to their GitHub account, or rewrite the \($w[3]) with their GitHub no-reply address."
' "$data/commits.json")
if [[ -n $unlinked_commits ]]; then
  while IFS= read -r message; do
    problems+=("$message")
  done <<< "$unlinked_commits"
fi

if (( ${#problems[@]} > 0 )); then
  fail "$(printf '%s\n\n' "${problems[@]}")"
fi
echo 'Every author of this pull request has signed the CLA or does not need to'
