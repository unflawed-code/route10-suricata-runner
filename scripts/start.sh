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

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 0. Initial Setup Check
if [ ! -f "$SETUP_SENTINEL" ]; then
    echo "ERROR: Setup has not been run for this project."
    echo "Please run: /bin/ash setup.sh"
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
