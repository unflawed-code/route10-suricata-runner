#!/bin/ash
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SELF_DIR")"

assert_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"

    if grep -Fq "$pattern" "$file"; then
        echo "PASS: $label"
    else
        echo "FAIL: $label"
        exit 1
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"

    if grep -Fq "$pattern" "$file"; then
        echo "FAIL: $label"
        exit 1
    else
        echo "PASS: $label"
    fi
}

assert_contains "${ROOT_DIR}/scripts/boot-prune.sh" '. "$STREAM_FIX_HELPER"' "boot-prune sources shared stream fix helper"
assert_contains "${ROOT_DIR}/scripts/post-update-prune.sh" '. "$STREAM_FIX_HELPER"' "post-update-prune sources shared stream fix helper"
assert_not_contains "${ROOT_DIR}/scripts/stream-fix.sh" 'oob-limit-policy: ignore' "stream-fix avoids invalid oob-limit-policy value"
assert_contains "${ROOT_DIR}/scripts/boot-prune.sh" 'prepare_inline_runtime "$ENABLE_STATS"' "boot-prune prepares inline runtime before start"
assert_contains "${ROOT_DIR}/scripts/post-update-prune.sh" 'prepare_inline_runtime "$ENABLE_STATS"' "post-update-prune prepares inline runtime before restart"
assert_contains "${ROOT_DIR}/scripts/post-update-prune.sh" 'ENABLE_NDPI_SECURITY' "post-update-prune loads ENABLE_NDPI_SECURITY"
assert_contains "${ROOT_DIR}/scripts/post-update-prune.sh" 'route10-ndpi-security.rules' "post-update-prune manages ndpi security rules"
assert_not_contains "${ROOT_DIR}/INLINE_IPS_STABILITY_FIX.md" 'single NFQUEUE thread' "inline stability doc no longer claims a single queue rollout"
assert_not_contains "${ROOT_DIR}/RELEASE_NOTES.md" 'single-queue (`-q 0`)' "release notes no longer claim a single queue rollout"
