#!/bin/bash
# ============================================================================
# OC-Notch — Git History Cleanup Script
# ============================================================================
# This script rewrites the entire git history to remove personal/confidential
# data that was committed. It is DESTRUCTIVE and IRREVERSIBLE.
#
# What it does:
#   1. Installs git-filter-repo (if not already installed)
#   2. Replaces personal email in all commits
#   3. Replaces author name in all commits
#   4. Replaces Apple Team ID (literal:REDACTED_TEAM_ID) in all file contents
#   5. Replaces full name (literal:REDACTED_NAME) in all file contents
#   6. Replaces signing identity string in all file contents
#   7. Cleans up reflog and garbage-collects
#
# After running:
#   - You MUST force-push: git push --force --all && git push --force --tags
#   - All collaborators must re-clone the repo
#   - GitHub caches may retain old data for a while — contact GitHub support
#     to purge cached views if needed
#
# Usage:
#   1. COMMIT your current anonymization changes FIRST
#   2. Review this script carefully
#   3. Run: bash scripts/purge-history.sh
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  DESTRUCTIVE OPERATION — GIT HISTORY REWRITE        ║${NC}"
echo -e "${RED}║                                                          ║${NC}"
echo -e "${RED}║  This will rewrite ALL commits in the repository.        ║${NC}"
echo -e "${RED}║  Old commit hashes will be invalidated.                  ║${NC}"
echo -e "${RED}║  All collaborators must re-clone after force-push.       ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Configuration: what to replace ──────────────────────────────
# Change these to your desired replacements
OLD_EMAIL="literal:maintainer@oc-notch.dev"
NEW_EMAIL="maintainer@oc-notch.dev"

OLD_NAME="Jay-Qiu"
NEW_NAME="OC-Notch Maintainer"

# Strings to scrub from file contents (across all history)
TEAM_ID="literal:REDACTED_TEAM_ID"
FULL_NAME="literal:REDACTED_NAME"
MACOS_USER="developer"

# ─── Preflight checks ───────────────────────────────────────────
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not in a git repository root.${NC}"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}Error: Working tree is dirty. Commit or stash changes first.${NC}"
    exit 1
fi

# ─── Confirm ─────────────────────────────────────────────────────
echo "This script will:"
echo "  • Replace commit author email: ${OLD_EMAIL} → ${NEW_EMAIL}"
echo "  • Replace commit author name:  ${OLD_NAME} → ${NEW_NAME}"
echo "  • Scrub from ALL file contents: ${TEAM_ID}, ${FULL_NAME}"
echo "  • Scrub macOS username from file paths: ${MACOS_USER}"
echo ""
read -rp "Type 'PURGE' to proceed: " CONFIRM
if [ "$CONFIRM" != "PURGE" ]; then
    echo "Aborted."
    exit 1
fi

# ─── Install git-filter-repo if needed ───────────────────────────
if ! command -v git-filter-repo &>/dev/null; then
    echo -e "${YELLOW}→ Installing git-filter-repo via brew...${NC}"
    brew install git-filter-repo
fi

# ─── Create mailmap for author/email replacement ─────────────────
MAILMAP_FILE=$(mktemp)
echo "${NEW_NAME} <${NEW_EMAIL}> ${OLD_NAME} <${OLD_EMAIL}>" > "$MAILMAP_FILE"
echo -e "${GREEN}→ Created mailmap: ${OLD_NAME} <${OLD_EMAIL}> → ${NEW_NAME} <${NEW_EMAIL}>${NC}"

# ─── Create blob replacement expressions ─────────────────────────
REPLACEMENTS_FILE=$(mktemp)
cat > "$REPLACEMENTS_FILE" <<EOF
literal:${TEAM_ID}==>literal:REDACTED_TEAM_ID
literal:${FULL_NAME}==>literal:REDACTED_NAME
literal:Developer ID Application: ${FULL_NAME}==>literal:Developer ID Application: REDACTED_NAME
regex:xcuserdata/${MACOS_USER}\.xcuserdatad==>xcuserdata/developer.xcuserdatad
EOF
echo -e "${GREEN}→ Created content replacement rules${NC}"

# ─── Backup current remote ──────────────────────────────────────
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
echo -e "${YELLOW}→ Remote URL backed up: ${REMOTE_URL}${NC}"

# ─── Run git-filter-repo ────────────────────────────────────────
echo ""
echo -e "${YELLOW}→ Rewriting history (this may take a moment)...${NC}"

git filter-repo \
    --mailmap "$MAILMAP_FILE" \
    --replace-text "$REPLACEMENTS_FILE" \
    --force

echo -e "${GREEN}→ History rewritten successfully!${NC}"

# ─── Re-add remote (git-filter-repo removes it) ─────────────────
if [ -n "$REMOTE_URL" ]; then
    git remote add origin "$REMOTE_URL"
    echo -e "${GREEN}→ Remote re-added: ${REMOTE_URL}${NC}"
fi

# ─── Cleanup temp files ─────────────────────────────────────────
rm -f "$MAILMAP_FILE" "$REPLACEMENTS_FILE"

# ─── Garbage collect ─────────────────────────────────────────────
echo -e "${YELLOW}→ Running garbage collection...${NC}"
git reflog expire --expire=now --all
git gc --prune=now --aggressive
echo -e "${GREEN}→ Garbage collection complete${NC}"

# ─── Done ────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ History rewritten successfully!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify the rewrite:"
echo "     git log --all --format='%an <%ae> %s' | head -20"
echo "     git log --all -p | grep -i '${TEAM_ID}' | head -5  # should be empty"
echo ""
echo "  2. Force-push to remote:"
echo "     git push --force --all"
echo "     git push --force --tags"
echo ""
echo "  3. Contact GitHub support to purge cached data:"
echo "     https://support.github.com/contact"
echo "     Request purge of old commit data for your repository."
echo ""
echo "  4. Notify all collaborators to re-clone the repository."
echo ""
echo -e "${YELLOW}⚠️  Old GitHub Release assets may still reference old commits.${NC}"
echo -e "${YELLOW}   Consider re-creating releases after the force-push.${NC}"
