#!/usr/bin/env bash
# Combine the Skillable pages in this folder into one file to paste into Skillable
# Studio (Edit Instructions). Run it whenever you add, remove, or edit a page:
#
#   ./instructions/skillable/generate-skillable-copy.sh            # full text (default)
#   MODE=include ./instructions/skillable/generate-skillable-copy.sh
#
# Pages are core-N-*.md then more-N-*.md, in number order, joined by the === page break.
# MODE=full     copies every page's text into skillable-copy.md.
# MODE=include  writes one [!include] per page so Skillable pulls each page live from
#               GitHub. Set REPO and BRANCH to choose the source (the repo must be public).
set -euo pipefail

cd "$(dirname "$0")"

MODE="${MODE:-full}"
REPO="${REPO:-microsoft/ignite26-LAB661}"
BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/instructions/skillable"
OUT="skillable-copy.md"

# Local media path -> path of the same image already uploaded to the Skillable profile.
declare -A SKILLABLE_MEDIA=(
    ["media/vscode-continue-with-github.png"]="instructions359309/e4hal04w.png"
)

with_skillable_media() {
    local text
    text="$(cat "$1")"
    for local_path in "${!SKILLABLE_MEDIA[@]}"; do
        text="${text//"(${local_path})"/"(${SKILLABLE_MEDIA[${local_path}]})"}"
    done
    printf '%s\n' "${text}"
}

mapfile -t PAGES < <(ls -1 core-[0-9]*-*.md 2>/dev/null | sort -V; ls -1 more-[0-9]*-*.md 2>/dev/null | sort -V)
if [[ ${#PAGES[@]} -eq 0 ]]; then
    echo "No page files (core-N-*.md or more-N-*.md) found; aborting." >&2
    exit 1
fi

case "${MODE}" in
    full)    SOURCE="the page files in instructions/skillable/" ;;
    include) SOURCE="${RAW_BASE}" ;;
    *)       echo "MODE must be full or include, not '${MODE}'." >&2; exit 1 ;;
esac

{
    cat <<EOF
<!--
  LAB661 Skillable instructions. GENERATED, do not edit by hand.
  Regenerate with: ./instructions/skillable/generate-skillable-copy.sh
  Mode: ${MODE}. Source: ${SOURCE}
  Paste everything in this file into the Skillable lab profile (Edit Instructions).
-->
EOF
    first=1
    for page in "${PAGES[@]}"; do
        if [[ ${first} -eq 1 ]]; then first=0; else printf '\n===\n'; fi
        printf '\n'
        if [[ "${MODE}" == "include" ]]; then
            printf '[!include[%s](%s/%s)]\n' "${page%.md}" "${RAW_BASE}" "${page}"
        else
            with_skillable_media "${page}"
        fi
    done
} > "${OUT}"

echo "Wrote ${OUT} with ${#PAGES[@]} page files (mode: ${MODE})."
