#!/bin/ash

# Wrap the entire script in a block to ensure it is fully loaded into memory.
# This makes self-overwriting safe.
{
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

VERSION_SCRIPT="${REMOTE_DIR}/scripts/version.sh"
[ ! -f "$VERSION_SCRIPT" ] && VERSION_SCRIPT="${REMOTE_DIR}/version.sh"
POLICY_CONF="/etc/suricata/ips-policy.conf"
[ ! -f "$POLICY_CONF" ] && POLICY_CONF="${REMOTE_DIR}/ips-policy.conf"
LOG_FILE="/var/log/suricata-runner-update.log"
GITHUB_REPO="unflawed-code/route10-suricata-runner"
LATEST_RELEASE_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
ALL_RELEASES_URL="https://api.github.com/repos/${GITHUB_REPO}/releases"
WEB_LATEST_URL="https://github.com/${GITHUB_REPO}/releases/latest"

# Emergency tracking state for trap
UPDATE_SUCCESS=0
UPDATE_TMP_DIR=""
UPDATE_BACKUP_DIR=""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] updater: $*" | tee -a "$LOG_FILE"
}

# Source local version
if [ -f "$VERSION_SCRIPT" ]; then
    . "$VERSION_SCRIPT"
else
    log "ERROR: Missing version script at $VERSION_SCRIPT"
    exit 1
fi

get_policy_value() {
    local key="$1"
    [ -f "$POLICY_CONF" ] || return 0
    sed -n "s/^${key}=//p" "$POLICY_CONF" | tail -n 1 | tr -d '\r[:space:]'
}

get_latest_version_tag() {
    local tag=""
    local enable_beta
    enable_beta=$(get_policy_value "ENABLE_BETA_UPDATES")
    
    # Method 1: GitHub API (Primary)
    if [ "$enable_beta" = "1" ]; then
        # Fetch first item from all releases (includes pre-releases)
        if command -v wget >/dev/null 2>&1; then
            tag=$(wget --no-check-certificate -qO- "$ALL_RELEASES_URL" | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p' | head -n 1)
        elif command -v curl >/dev/null 2>&1; then
            tag=$(curl -s "$ALL_RELEASES_URL" | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p' | head -n 1)
        fi
    else
        # Stable only
        if command -v wget >/dev/null 2>&1; then
            tag=$(wget --no-check-certificate -qO- "$LATEST_RELEASE_URL" | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p' | head -n 1)
        elif command -v curl >/dev/null 2>&1; then
            tag=$(curl -s "$LATEST_RELEASE_URL" | sed -n 's/.*"tag_name": "\(.*\)".*/\1/p' | head -n 1)
        fi
    fi

    # Method 2: Fallback to Redirect (No API rate limits, Stable ONLY)
    if [ -z "$tag" ] && [ "$enable_beta" != "1" ]; then
        if command -v curl >/dev/null 2>&1; then
            tag=$(curl -sIL "$WEB_LATEST_URL" | grep -i "^location:" | sed -n 's/.*\/tag\(s\)\?\/\([^[:space:]\r]*\).*/\2/p' | tail -n 1)
        elif command -v wget >/dev/null 2>&1; then
            tag=$(wget --no-check-certificate -S --spider "$WEB_LATEST_URL" 2>&1 | grep -i "Location:" | sed -n 's/.*\/tag\(s\)\?\/\([^[:space:]\r]*\).*/\2/p' | tail -n 1)
        fi
    fi

    if [ -z "$tag" ]; then
        log "ERROR: Could not fetch latest version tag from GitHub."
        return 1
    fi
    echo "$tag" | tr -d '\r'
}

version_gt() {
    # Strip everything after '-' to handle rc versions correctly in integer comparisons
    local v1=$(echo "$1" | sed 's/^v//' | cut -d- -f1 | tr -d '\r')
    local v2=$(echo "$2" | sed 's/^v//' | cut -d- -f1 | tr -d '\r')
    
    # If numeric parts match exactly, check if one is an RC and the other is stable
    if [ "$v1" = "$v2" ]; then
        # If GitHub ($1) is "2.0.0" and Local ($2) is "2.0.0-rc1", GitHub is greater
        if echo "$1" | grep -qv "-" && echo "$2" | grep -q "-"; then
            return 0
        fi
        # If GitHub is "2.0.0-rc2" and Local is "2.0.0-rc1", GitHub is greater
        if echo "$1" | grep -q "-" && echo "$2" | grep -q "-"; then
            local rc1=$(echo "$1" | sed 's/.*-rc//' | tr -dc '0-9')
            local rc2=$(echo "$2" | sed 's/.*-rc//' | tr -dc '0-9')
            if [ "${rc1:-0}" -gt "${rc2:-0}" ]; then return 0; fi
        fi
        return 1
    fi

    local i=1
    while [ $i -le 3 ]; do
        local p1=$(echo "$v1" | cut -d. -f$i); [ -z "$p1" ] && p1=0
        local p2=$(echo "$v2" | cut -d. -f$i); [ -z "$p2" ] && p2=0
        if [ "$p1" -gt "$p2" ]; then return 0; fi
        if [ "$p1" -lt "$p2" ]; then return 1; fi
        i=$((i+1))
    done
    return 1
}

perform_rollback() {
    local backup_dir="$1"
    log "CRITICAL: Update failed. Initiating rollback..."
    [ -d "$backup_dir" ] || { log "ERROR: Rollback failed - Backup directory missing."; return 1; }
    
    rm -rf "${REMOTE_DIR:?}/"*
    cp -rf "${backup_dir}/"* "$REMOTE_DIR/"
    log "Restoring original system state..."
    /bin/ash "${REMOTE_DIR}/setup.sh" || log "ERROR: Rollback setup also failed."
    log "Rollback completed. Staying on version v$SURICATA_RUNNER_VERSION."
}

cleanup_trap() {
    if [ "$UPDATE_SUCCESS" -eq 0 ] && [ -n "$UPDATE_BACKUP_DIR" ]; then
        perform_rollback "$UPDATE_BACKUP_DIR"
    fi
    if [ -n "$UPDATE_TMP_DIR" ]; then
        rm -rf "$UPDATE_TMP_DIR" "$UPDATE_BACKUP_DIR"
    fi
}

perform_update() {
    local tag="$1"
    local download_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/${tag}.tar.gz"
    UPDATE_TMP_DIR="/tmp/suricata-runner-update"
    UPDATE_BACKUP_DIR="/tmp/suricata-runner-backup"
    local archive="${UPDATE_TMP_DIR}/update.tar.gz"
    
    log "Initiating update to version $tag..."
    rm -rf "$UPDATE_TMP_DIR" "$UPDATE_BACKUP_DIR"
    mkdir -p "$UPDATE_TMP_DIR" "$UPDATE_BACKUP_DIR"
    
    log "Creating safety backup of current version..."
    cp -rf "${REMOTE_DIR}/"* "$UPDATE_BACKUP_DIR/"
    
    # Set trap for emergency rollback on sudden crash
    trap cleanup_trap EXIT

    log "Downloading $download_url..."
    if command -v curl >/dev/null 2>&1; then
        curl -sL "$download_url" -o "$archive" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate -q "$download_url" -O "$archive" || return 1
    fi
    
    log "Extracting archive..."
    tar -xzf "$archive" -C "$UPDATE_TMP_DIR" || return 1
    
    local extracted_root=$(ls -d "${UPDATE_TMP_DIR}/${GITHUB_REPO##*/}"* | head -n 1)
    [ -d "$extracted_root" ] || return 1
    
    log "Applying update files..."
    cp "$POLICY_CONF" "${UPDATE_TMP_DIR}/ips-policy.conf.bak" 2>/dev/null || true
    cp -rf "${extracted_root}/"* "$REMOTE_DIR/"
    if [ -f "${UPDATE_TMP_DIR}/ips-policy.conf.bak" ]; then
        cp -f "${UPDATE_TMP_DIR}/ips-policy.conf.bak" "$POLICY_CONF"
        [ -f "${REMOTE_DIR}/ips-policy.conf" ] && cp -f "$POLICY_CONF" "${REMOTE_DIR}/ips-policy.conf"
    fi
    
    log "Running setup and validating update..."
    if /bin/ash "${REMOTE_DIR}/setup.sh"; then
        log "Update to $tag verified and completed successfully."
        UPDATE_SUCCESS=1
        return 0
    else
        return 1
    fi
}

check_and_update() {
    local force="${1:-0}"
    local latest_tag
    latest_tag=$(get_latest_version_tag) || return 1
    
    if version_gt "$latest_tag" "$SURICATA_RUNNER_VERSION" || [ "$force" = "1" ]; then
        [ "$force" = "1" ] && log "Force update requested." || log "New version available: $latest_tag"
        perform_update "$latest_tag"
    else
        log "No updates found."
    fi
}

cmd="${1:-check}"
case "$cmd" in
    check) check_and_update 0 ;;
    force) check_and_update 1 ;;
    *) echo "Usage: $0 {check|force}"; exit 1 ;;
esac

} # End of buffered block
