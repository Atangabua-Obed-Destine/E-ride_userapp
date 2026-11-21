#!/usr/bin/env bash
# Publishes the current commit to GitHub as the branch "ios-build", which Codemagic builds from.
#
# The GitHub repo is public and the Google Maps key in the code must not reach it, so this pushes
# a copy of the commit with the key replaced by MAPS_API_KEY_HERE, as one commit on top of the last
# published one. The working branch and its history stay on this computer.
#
# Run from Git Bash:  bash tool/publish_ios_build.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

FILES="android/app/src/main/AndroidManifest.xml ios/Runner/AppDelegate.swift"
KEY=$(git show HEAD:android/app/src/main/AndroidManifest.xml | grep -o 'AIza[0-9A-Za-z_-]*' | head -1)
[ -n "$KEY" ] || { echo "No Maps key found in the manifest; nothing published."; exit 1; }

export GIT_INDEX_FILE="$(mktemp -u)"
git read-tree HEAD
for f in $FILES; do
  blob=$(git show "HEAD:$f" | sed "s/$KEY/MAPS_API_KEY_HERE/g" | git hash-object -w --stdin)
  git update-index --cacheinfo "100644,$blob,$f"
done
tree=$(git write-tree)
rm -f "$GIT_INDEX_FILE"
unset GIT_INDEX_FILE

if git grep -q "$KEY" "$tree"; then
  echo "The key is still somewhere in the copy; nothing published:"
  git grep -l "$KEY" "$tree"
  exit 1
fi

git fetch -q origin
parent=$(git rev-parse -q --verify origin/ios-build || git rev-parse origin/main)
commit=$(git commit-tree "$tree" -p "$parent" -m "E-Ride customer app at $(git rev-parse --short HEAD): $(git log -1 --format=%s)")
git push -q origin "$commit:refs/heads/ios-build"
echo "Published $(git rev-parse --short HEAD) to ios-build as $(git rev-parse --short "$commit")."
