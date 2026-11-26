#!/usr/bin/env bash
# Deploys the website through the GitHub Pages workflow. Deployment always
# runs in GitHub Actions; this script only triggers it.
source "$(dirname "$0")/lib/common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: ./scripts/deploy_docs.sh [--ref BRANCH]"
  echo "Triggers .github/workflows/deploy-pages.yml with the GitHub CLI after confirmation."
  echo "Build locally first with ./scripts/build_docs.sh --with-demo to preview."
  exit 0
fi

ref="main"
if [[ "${1:-}" == "--ref" ]]; then
  ref="${2:?--ref needs a branch name}"
fi

require gh
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated; run 'gh auth login'"

step "Deploying GitHub Pages from '$ref'"
confirm "Trigger the deploy-pages workflow on '$ref'?" || fail "Cancelled"
run gh workflow run deploy-pages.yml --ref "$ref"
ok "Workflow triggered; follow it with: gh run watch"
