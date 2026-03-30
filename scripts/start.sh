#!/bin/ash
# Suricata Optimization Boot Wrapper for Route10 (Autonomous Safety)
# Detects failed boots and disables itself to prevent boot loops.

# Detect the base directory where this script (or its parent) lives
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# If we're inside the 'scripts' subdirectory, the remote dir is one level up
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

LOG_FILE="/var/log/suricata-start.log"
DISABLE_FILE="${REMOTE_DIR}/DISABLED"
PENDING_FILE="${REMOTE_DIR}/BOOT_PENDING"
SETUP_SENTINEL="${REMOTE_DIR}/.setup_done"
VECTORSCAN_HELPER="${REMOTE_DIR}/scripts/vectorscan-runtime.sh"
[ ! -f "$VECTORSCAN_HELPER" ] && VECTORSCAN_HELPER="${REMOTE_DIR}/vectorscan-runtime.sh"
VECTORSCAN_RUNTIME_ROOT="/a/suricata-vectorscan"
CRON_FILE="/etc/crontabs/root"
POST_UPDATE_PRUNE_SCRIPT="${REMOTE_DIR}/scripts/post-update-prune.sh"
[ ! -f "$POST_UPDATE_PRUNE_SCRIPT" ] && POST_UPDATE_PRUNE_SCRIPT="${REMOTE_DIR}/post-update-prune.sh"
RUNNER_SCRIPT="${REMOTE_DIR}/runner.sh"

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$line" >> "$LOG_FILE"
    echo "$line"
}

ensure_suricata_update_cron() {
    local target_update="30 3 * * * /usr/bin/suricata-update --fail --no-test"
    local target_prune="32 3 * * * ${POST_UPDATE_PRUNE_SCRIPT}"
    [ -f "$CRON_FILE" ] || return 0

    awk -v target_update="$target_update" -v target_prune="$target_prune" '
        BEGIN { wrote_update = 0; wrote_prune = 0 }
        $0 == target_update {
            if (!wrote_update) {
                print target_update
                wrote_update = 1
            }
            next
        }
        index($0, "suricata-update") {
            if (!wrote_update) {
                print target_update
                wrote_update = 1
            }
            next
        }
        $0 == target_prune {
            if (!wrote_prune) {
                print target_prune
                wrote_prune = 1
            }
            next
        }
        index($0, "post-update-prune.sh") {
            if (!wrote_prune) {
                print target_prune
                wrote_prune = 1
            }
            next
        }
        { print }
        END {
            if (!wrote_update) print target_update
            if (!wrote_prune) print target_prune
        }
    ' "$CRON_FILE" > "${CRON_FILE}.tmp"

    if ! cmp -s "$CRON_FILE" "${CRON_FILE}.tmp" 2>/dev/null; then
        mv "${CRON_FILE}.tmp" "$CRON_FILE"
        log "Canonicalized Suricata cron to run real suricata-update at 3:30 AM and post-update prune at 3:32 AM"
        /etc/init.d/cron restart >/dev/null 2>&1 || true
    else
        rm -f "${CRON_FILE}.tmp"
    fi
}

# 0. Initial Setup Check
if [ ! -f "$SETUP_SENTINEL" ]; then
    echo "ERROR: Setup has not been run for this project."
    if [ -f "$RUNNER_SCRIPT" ]; then
        echo "Please run: /bin/ash $RUNNER_SCRIPT setup"
    else
        echo "Please run: /bin/ash ${REMOTE_DIR}/setup.sh"
    fi
    exit 1
fi

# 1. Manual/Auto Disable Check
if [ -f "$DISABLE_FILE" ]; then
    log "Aborting: Project is DISABLED."
    exit 0
fi

# 2. Boot Loop Protection
# If PENDING exists at this stage, the previous boot failed to complete the pruning phase.
if [ -f "$PENDING_FILE" ]; then
    echo "Auto-disabled at $(date) due to detected boot failure in previous session." > "$DISABLE_FILE"
    echo "To re-enable, delete this file after investigating /var/log/suricata-boot-prune.log" >> "$DISABLE_FILE"
    rm -f "$PENDING_FILE"
    log "CRITICAL: Previous boot failed during pruning. Auto-disabling to prevent loop."
    exit 1
fi

# 3. Environment Check
if [ ! -d "$REMOTE_DIR" ] || [ ! -f "/usr/bin/suricata" ]; then
    log "Aborting: Environment missing at $REMOTE_DIR"
    exit 1
fi

. "$VECTORSCAN_HELPER" 2>/dev/null || {
    echo "ERROR: Missing Vectorscan helper at $VECTORSCAN_HELPER"
    log "Aborting: Missing Vectorscan helper at $VECTORSCAN_HELPER"
    exit 1
}

if ! ensure_vectorscan_runtime_from_archive "$REMOTE_DIR" "$VECTORSCAN_RUNTIME_ROOT"; then
    log "Aborting: Failed to ensure Vectorscan runtime from archive."
    exit 1
fi

ensure_suricata_update_cron

log "Initializing configuration from $REMOTE_DIR..."
cp "${REMOTE_DIR}/ips-policy.conf" /etc/suricata/ips-policy.conf 2>/dev/null

POLICY_SCRIPT="${REMOTE_DIR}/scripts/ips-rule-policy.sh"
[ ! -f "$POLICY_SCRIPT" ] && POLICY_SCRIPT="${REMOTE_DIR}/ips-rule-policy.sh"

BOOT_SCRIPT="${REMOTE_DIR}/scripts/boot-prune.sh"
[ ! -f "$BOOT_SCRIPT" ] && BOOT_SCRIPT="${REMOTE_DIR}/boot-prune.sh"

if [ -f "$POLICY_SCRIPT" ]; then
    ln -sf "$POLICY_SCRIPT" /usr/sbin/ips-rule-policy.sh
else
    log "Error: Rule policy script missing."
    exit 1
fi

# 4. Patching
if [ -f "/usr/bin/suricatad.sh" ]; then
    sed -i 's/suricata-update --fail --no-test/# suricata-update --fail --no-test/g' /usr/bin/suricatad.sh 2>/dev/null
fi

# 5. Trigger background automation
# boot-prune.sh is now responsible for marking the boot as PENDING
if [ -f "$BOOT_SCRIPT" ]; then
    chmod +x "$BOOT_SCRIPT"
    log "Triggering boot-prune.sh..."
    "$BOOT_SCRIPT" 120 >> /var/log/suricata-boot-prune.log 2>&1 &
else
    log "Error: Boot script missing."
    exit 1
fi

log "Start wrapper finished (background tasks continuing)."
