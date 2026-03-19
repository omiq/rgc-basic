#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/omiq/cbm-basic.git"
WORKDIR="cbm-basic-cleanup.git"

YOUR_NAME="Chris Garrett"
YOUR_EMAIL="chris@omiq.com"
CURSOR_EMAIL="cursoragent@cursor.com"

echo "Cloning mirror of ${REPO_SSH} ..."
rm -rf "$WORKDIR"
git clone --mirror "$REPO_URL" "$WORKDIR"
cd "$WORKDIR"

echo
echo "Commits currently mentioning Cursor email:"
git log --all --pretty=format:'%h | %an <%ae> | %cn <%ce> | %s' | grep "$CURSOR_EMAIL" || true

echo
echo "Any commit-message mentions of Cursor:"
git log --all --format='%H%n%B%n----' | grep -i cursor || true

echo
echo "Rewriting author and committer identity ..."
git filter-repo --force --commit-callback "
if commit.author_email == b\"${CURSOR_EMAIL}\":
    commit.author_name = b\"${YOUR_NAME}\"
    commit.author_email = b\"${YOUR_EMAIL}\"
if commit.committer_email == b\"${CURSOR_EMAIL}\":
    commit.committer_name = b\"${YOUR_NAME}\"
    commit.committer_email = b\"${YOUR_EMAIL}\"
"

echo
echo "Removing common Cursor co-author lines from commit messages ..."
git filter-repo --force --message-callback "
message = message.replace(b'Co-authored-by: Cursor Agent <cursoragent@cursor.com>\n', b'')
message = message.replace(b'Co-authored-by: cursoragent <cursoragent@cursor.com>\n', b'')
message = message.replace(b'Co-authored-by: Cursor <cursoragent@cursor.com>\n', b'')
message = message.replace(b'Co-authored-by: cursor <cursoragent@cursor.com>\n', b'')
return message
"

echo
echo "Checking for anything still mentioning Cursor ..."
git log --all --pretty=format:'%h | %an <%ae> | %cn <%ce> | %s' | grep "$CURSOR_EMAIL" || true
git log --all --format='%H%n%B%n----' | grep -i cursor || true

echo
echo "Force pushing rewritten history ..."
git push --force --all
git push --force --tags

echo
echo "Done. GitHub may take a little while to refresh the contributor list."

