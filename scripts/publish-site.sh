#!/bin/zsh
# Publishes site/ to https://iamginsley.github.io/smoll-notch/ by pushing it to the gh-pages branch.
# GitHub Pages builds from that branch, so no Actions minutes or budget are involved.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Run this on main, after the site changes are merged." >&2
  exit 1
fi
git pull --ff-only -q
git subtree split --prefix site -b gh-pages-publish >/dev/null
git push -f origin gh-pages-publish:gh-pages
git branch -D gh-pages-publish >/dev/null
echo "✓ Published. GitHub Pages updates in about a minute: https://iamginsley.github.io/smoll-notch/"
