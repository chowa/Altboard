#!/usr/bin/env bash
#
#  check-cla-test.sh
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
# shellcheck disable=SC2016 # the single-quoted $ names are jq variables and literal JSON keys
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
check=${1:-"$repo/Scripts/check-cla.sh"}
work=$(mktemp -d)
fixtures=$work/fixtures
bin=$work/bin
scratch=$work/tmp
mkdir -p "$fixtures" "$bin" "$scratch"
cleanup() {
  rm -f "$fixtures"/* "$bin"/* "$scratch"/*/*
  rmdir "$scratch"/* "$scratch" "$fixtures" "$bin" "$work" 2> /dev/null || true
}
trap cleanup EXIT

cat > "$bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == api ]] || { echo "unexpected gh command: $*" >&2; exit 2; }
shift
accept='' filter='' endpoint=''
while (( $# )); do
  case $1 in
    --paginate) shift ;;
    -H) accept=$2; shift 2 ;;
    --jq) filter=$2; shift 2 ;;
    *) endpoint=$1; shift ;;
  esac
done
case $endpoint in
  'repos/owner/repo/pulls/5/commits?per_page=100')
    jq -c "$filter" "$FIXTURES/commits.json" ;;
  'repos/owner/repo/compare/base999...abc123')
    jq -r "$filter" <<< '{"merge_base_commit": {"sha": "mb456"}}' ;;
  'repos/owner/repo/contents/.github/cla-signatures.json?ref='*)
    [[ $accept == 'Accept: application/vnd.github.raw+json' ]] || { echo "expected a raw read, got '$accept'" >&2; exit 2; }
    if [[ -f $FIXTURES/server-error ]]; then echo 'gh: Server Error (HTTP 500)' >&2; exit 1; fi
    ref=${endpoint##*ref=}
    if [[ -f $FIXTURES/$ref.json ]]; then
      cat "$FIXTURES/$ref.json"
    else
      echo '{"message":"Not Found"}'
      echo 'gh: Not Found (HTTP 404)' >&2
      exit 1
    fi ;;
  *) echo "unexpected endpoint: $endpoint" >&2; exit 2 ;;
esac
EOF
cat > "$bin/date" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-u +%F' ]]; then echo 2027-01-05; else exec /bin/date "$@"; fi
EOF
chmod +x "$bin/gh" "$bin/date"

# Fixture builders

sig() {
  jq -nc --arg login "$1" --argjson id "$2" "{login: \$login, id: \$id, cla_version: 1, date: \"2027-01-02\"} | ${3:-.}"
}
file() {
  local IFS=,
  jq -n "{signatures: [$*]}"
}
on() {
  local ref=$1
  case $ref in
    main | abc123) ;;
    base) ref=mb456 ;;
    *) echo "on: unknown ref '$ref'" >&2; exit 2 ;;
  esac
  printf '%s' "$2" > "$fixtures/$ref.json"
}
commits() {
  local i=0 items=() spec sha login id type name email
  for spec in "$@"; do
    i=$((i + 1))
    sha="$(printf "$i%.0s" 1 2 3 4 5 6 7)abcdef"
    case $spec in
      unlinked:*)
        IFS=: read -r _ name email <<< "$spec"
        items+=("$(jq -nc --arg sha "$sha" --arg name "$name" --arg email "$email" \
          '{sha: $sha, author: null, commit: {author: {name: $name, email: $email}}}')") ;;
      *)
        read -r login id type <<< "$spec"
        items+=("$(jq -nc --arg sha "$sha" --arg login "$login" --argjson id "$id" --arg type "${type:-User}" \
          '{sha: $sha, author: {login: $login, id: $id, type: $type}, commit: {author: {name: $login, email: "\($id)+\($login)@users.noreply.github.com"}}}')") ;;
    esac
  done
  local IFS=,
  echo "[${items[*]}]" > "$fixtures/commits.json"
}

# Runner

author_login='' author_id='' author_type='' pr_commits=''
passes=0
failures=0
author() { author_login=$1 author_id=$2 author_type=${3:-User}; }
check() {
  local name=$1 expected=$2 wanted=${3:-} unwanted=${4:-} output outcome
  [[ -f $fixtures/mb456.json || ! -f $fixtures/main.json ]] || cp "$fixtures/main.json" "$fixtures/mb456.json"
  [[ -f $fixtures/commits.json ]] || commits "$author_login $author_id $author_type"
  if output=$(env PATH="$bin:$PATH" TMPDIR="$scratch" FIXTURES="$fixtures" GH_TOKEN=test GH_REPO=owner/repo \
    PR_NUMBER=5 PR_COMMITS="${pr_commits:-$(jq length "$fixtures/commits.json")}" BASE_SHA=base999 HEAD_SHA=abc123 \
    DEFAULT_BRANCH=main AUTHOR_LOGIN="$author_login" AUTHOR_ID="$author_id" AUTHOR_TYPE="$author_type" \
    bash "$check" 2>&1); then outcome=passed; else outcome=failed; fi
  output=${output//%0A/$'\n'}
  output=${output//%0D/$'\r'}
  output=${output//%25/%}
  if [[ $outcome == "$expected" && $output == *"$wanted"* && ( -z $unwanted || $output != *"$unwanted"* ) ]]; then
    passes=$((passes + 1))
    echo "PASS $name"
  else
    failures=$((failures + 1))
    printf 'FAIL %s: expected %s, got %s\n%s\n' "$name" "$expected" "$outcome" "$output"
  fi
  rm -f "$fixtures"/*
  pr_commits=''
}

octocat=$(sig octocat 583231)
entry='    {
      "login": "octocat",
      "id": 583231,
      "cla_version": 1,
      "date": "2027-01-05"
    }'
bob_entry='    {
      "login": "bob",
      "id": 8,
      "cla_version": 1,
      "date": "2027-01-05"
    }'
not_signed='has not signed version 1 of CLA.md'
locked='Existing entries must stay unchanged and in place'

# CLA version

title_version=$(sed -n '1s/^# .*, Version \([0-9][0-9]*\)$/\1/p' "$repo/CLA.md")
check_version=$(sed -n 's/^cla_version=\([0-9][0-9]*\).*/\1/p' "$check")
if [[ -n $title_version && $title_version == "$check_version" ]]; then
  passes=$((passes + 1))
  echo 'PASS the check counts the Version in the title of CLA.md'
else
  failures=$((failures + 1))
  echo "FAIL the check counts Version ${check_version:-?}, but the title of CLA.md says ${title_version:-?}"
fi

# Exemptions

author stanlsv 223757985
check 'maintainer by ID is exempt' passed
author new-name 223757985
check 'renamed maintainer still exempt' passed
author stanlsv 999
check 'someone who took the old maintainer login is not exempt' failed
author 'dependabot[bot]' 49699333 Bot
check 'bot is exempt' passed

# Signing

author octocat 583231
on main "$(file "$octocat")"; on base "$(file)"; on abc123 "$(file)"
check 'signed earlier on the default branch, branch older than the signature' passed
on main "$(file)"; on abc123 "$(file "$octocat")"
check 'signs in this pull request' passed
author octo-renamed 583231
on main "$(file "$octocat")"; on abc123 "$(file "$octocat")"
check 'renamed signer still signed' passed
author octocat 1
on main "$(file "$octocat")"; on abc123 "$(file "$octocat")"
check 'someone who took a signer login is not signed' failed
author octocat 583231
on main "$(file)"; on abc123 "$(file)"
check 'not signed: message shows the exact entry with today in UTC' failed "in this pull request:
$entry"
check 'signatures file missing' failed "$not_signed"
on main "$(file)"; on abc123 "$(file "$octocat" "$(sig victim 42)")"
check 'adding another person is rejected' failed 'user IDs 42'
on main "$(file "$(sig alice 7)")"; on abc123 "$(file "$(sig alice 7)" "$octocat")"
check 'keeping existing signers is fine' passed
author stanlsv 223757985
on main "$(file)"; on abc123 "$(file "$(sig bob 8)")"
check 'maintainer may add others' passed
author octocat 583231
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 'del(.id)')")"
check 'username without ID does not count' failed "$entry"
on main "$(file)"; on abc123 $'{\r\n  "signatures" :  [\r\n\t{"id":583231,   "login":"octocat" , "cla_version":1,"date":"2027-01-02"}\r\n  ]\r\n}\r\n'
check 'CRLF and extra whitespace tolerated' passed
on main '{"$comment": "octocat 583231", "signatures": []}'; on abc123 '{"$comment": "{ \"login\": \"octocat\", \"id\": 583231 }", "signatures": []}'
check 'an ID inside $comment does not count' failed
touch "$fixtures/server-error"
check 'API error surfaces' failed 'HTTP 500'
on main "$(file)"; on abc123 "$(file "$octocat" "$(sig victim 42)")"
check 'rejecting an entry for someone else does not ask a signed author to sign again' failed 'user IDs 42' 'has not signed'
on main "$(file)"; on abc123 "$(file "$(sig octocat 583321)")"
check 'typo in own ID is reported with the right entry' failed "in this pull request:
$entry"
on main "$(file)"; on abc123 "$(file "$octocat")$(printf '%1100000s' '')"
check 'a file over 1 MB is read in full' passed
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 '.id = "583231"')" "$(sig octocat 583231 '.id = 583231.5')" "$(sig x 0)" "$(sig y -5)")"
check 'non-integer and non-positive IDs are ignored' failed "$not_signed"
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 '.note = "first contribution"')")"
check 'extra fields in an entry are tolerated' passed
on main "$(file)"; on abc123 '{ "signatures": [ { "login": "alice", "id": 7 } { "login": "octocat", "id": 583231 } ] }'
check 'invalid JSON in the pull request fails with the file named' failed '.github/cla-signatures.json at abc123 is not valid JSON'
on main "$(file)"; on abc123 '{ "signers": [] }'
check 'file without a signatures array fails with the file named' failed 'has no "signatures" array'
on main "$(file)"; on abc123 '{ "signatures": [583231, null, "octocat 583231"] }'
check 'non-object entries are ignored' failed "$not_signed"

# Version and date

on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 'del(.cla_version)')")"
check 'entry without cla_version does not count' failed "$entry"
on main "$(file "$(sig octocat 583231 '.cla_version = 2')")"; on abc123 "$(file "$(sig octocat 583231 '.cla_version = 2')")"
check 'entry for another CLA version does not count' failed "$not_signed"
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 '.cla_version = "1"')")"
check 'cla_version as a string does not count' failed "$entry"
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 'del(.date)')")"
check 'entry without date does not count' failed "$entry"
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 '.date = "2027-02-30"')")"
check 'impossible calendar date does not count' failed "$entry"
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 '.date = "2027-01-02T10:00:00.000Z"')")"
check 'date with a time does not count' failed "$entry"
on main "$(file)"; on abc123 "$(file "$(sig octocat 583231 '.date = "02.01.2027"')" "$(sig octocat 583231 '.date = "2027-1-2"')")"
check 'date in another format does not count' failed "$entry"
on main "$(file)"; on abc123 "$(file "$octocat" "$(sig victim 42 '.date = "yesterday"')")"
check 'bad entry for someone else is not counted as a signature' passed

# Existing entries

on main "$(file "$(sig alice 7)")"; on abc123 "$(file "$(sig alice 7 '.date = "2026-12-31"')" "$octocat")"
check "changing someone else's entry is rejected" failed "$locked; this one is changed, moved or removed: {\"login\":\"alice\",\"id\":7,\"cla_version\":1,\"date\":\"2027-01-02\"}"
on main "$(file "$(sig alice 7)" "$(sig bob 8)")"; on abc123 "$(file "$(sig alice 7)" "$octocat")"
check "removing someone else's entry is rejected" failed '"login":"bob"'
on main "$(file "$octocat")"; on abc123 "$(file "$(sig octocat 583231 '.date = "2027-01-05"')")"
check 'editing your own existing entry is rejected' failed "$locked"
on main "$(file "$(sig alice 7)")"; on abc123 "$(file "$octocat" "$(sig alice 7)")"
check 'adding before existing entries is rejected' failed "$locked"
on main "$(file "$octocat")"
check 'deleting the signatures file is rejected' failed "$locked"
on main "$(file "$(sig alice 7)")"; on abc123 "$(file "$(sig alice 8)")"
check 'an unsigned author who changed an entry still gets their entry' failed "in this pull request:
$entry"
on main "$(file "$(sig alice 7)" "$(sig bob 8)")"; on base "$(file "$(sig alice 7)")"; on abc123 "$(file "$(sig alice 7)" "$octocat")"
check 'stale branch: signatures merged into main after the branch point are fine' passed
on main "$(file "$(sig alice 7)")"; on abc123 "$(jq -c . <<< "$(file "$(sig alice 7)" "$octocat")")"
check 'reformatting whitespace of existing entries is fine' passed
on main "$(file "$(sig alice 7)")"; on abc123 "$(file "$(sig alice 7 '{date, cla_version, id, login}')" "$octocat")"
check 'reordering the keys of an existing entry is fine' passed
on main "$(file)"; on abc123 "{
  \"signatures\": [
$entry
  ]
}"
check 'the printed entry pasted into the file is a valid signature' passed
on main "$(file "$(sig alice 7)" "$octocat")"; on abc123 "$(file "$(sig alice 7 '.date = "2026-12-31"')" "$octocat")"
check 'a signed author who changed an entry is not asked to sign again' failed "$locked" 'has not signed'
on main "$(file "$(sig alice 7)")"; on base "$(file "$(sig alice 7)" "$(sig bob 8)")"; on abc123 "$(file "$(sig alice 7)" "$(sig bob 8)" "$octocat")"
check 'an entry removed on main after the branch point does not trap the pull request' passed
on main "$(file "$(sig alice 7)" "$(sig bob 8)")"; on base "$(file "$(sig alice 7)" "$(sig bob 88)")"; on abc123 "$(file "$(sig alice 7)" "$(sig bob 88)" "$octocat")"
check 'an entry corrected on main after the branch point does not trap the pull request' passed
on main "$(file "$(sig alice 7)" "$(sig bob 8)")"; on base "$(file "$(sig alice 7)")"; on abc123 "$(file "$(sig alice 7)" "$(sig bob 8)" "$octocat")"
check 'an entry copied from main onto a stale branch counts as added for someone else' failed 'user IDs 8'

# Commit authors

commits 'octocat 583231' 'bob 8'
on main "$(file "$(sig bob 8)")"; on abc123 "$(file "$(sig bob 8)" "$octocat")"
check 'co-author who signed earlier passes' passed
commits 'octocat 583231' 'bob 8'
on main "$(file)"; on abc123 "$(file "$octocat")"
check 'unsigned co-author fails with their own entry' failed "@bob authored commits in this pull request but has not signed version 1 of CLA.md. They sign in a pull request of their own that adds the entry below to the end of \"signatures\" in .github/cla-signatures.json. After that, a maintainer re-runs this check, or the author of this pull request closes and reopens it:
$bob_entry"
commits 'octocat 583231' 'bob 8'
on main "$(file)"; on abc123 "$(file "$octocat" "$(sig bob 8)")"
check 'co-author entry added by the pull request author is rejected' failed 'user IDs 8'
commits 'octocat 583231' 'unlinked:Jane Roe:jane@example.com'
on main "$(file)"; on abc123 "$(file "$octocat")"
check 'commit from an address not linked to GitHub fails' failed 'Commit 2222222 is authored by Jane Roe <jane@example.com>, an address not linked to a GitHub account'
commits 'octocat 583231' 'unlinked:Jane Roe:jane@example.com' 'unlinked:Jane Roe:jane@example.com'
on main "$(file)"; on abc123 "$(file "$octocat")"
check 'unlinked commits from one address are reported once' failed 'Commits 2222222, 3333333 are authored by Jane Roe <jane@example.com>'
commits 'octocat 583231' 'dependabot[bot] 49699333 Bot'
on main "$(file)"; on abc123 "$(file "$octocat")"
check 'bot commits need no signature' passed
commits 'octocat 583231' 'stanlsv 223757985'
on main "$(file)"; on abc123 "$(file "$octocat")"
check 'maintainer commits in a contributor pull request need no signature' passed
author stanlsv 223757985
commits 'stanlsv 223757985' 'bob 8'
on main "$(file)"; on abc123 "$(file)"
check 'maintainer pull request with an unsigned contributor commit fails' failed '@bob authored commits in this pull request'
commits 'stanlsv 223757985' 'bob 8'
on main "$(file)"; on abc123 "$(file "$(sig bob 8)")"
check 'maintainer pull request may record a co-author signature' passed
author octocat 583231
pr_commits=300
on main "$(file)"; on abc123 "$(file "$octocat")"
check 'more commits than the API lists fails' failed 'Split it into smaller pull requests'
echo '[{"sha": "1111111abcdef", "author": {"login": "octocat", "id": 583231, "type": "User"}, "commit": {"author": {"name": "octocat", "email": "583231+octocat@users.noreply.github.com"}}}, {"sha": "2222222abcdef", "author": "not an account", "commit": {"author": {"name": "x", "email": "x@example.com"}}}]' > "$fixtures/commits.json"
on main "$(file "$octocat")"; on abc123 "$(file "$octocat")"
check 'a failing jq step fails the check instead of skipping authors' failed
commits 'octocat 583231' 'bob 8'
on main "$(file)"; on abc123 "$(file)"
check 'unsigned author and unsigned co-author are both reported' failed "in this pull request:
$entry

@bob authored commits"

echo "$passes passed, $failures failed"
(( failures == 0 ))
