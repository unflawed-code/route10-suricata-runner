#!/bin/ash
# Integrated Suricata Optimization Setup for Route10
# Replaces system rule policy script with optimized in-place pruner.

# Detect local directory
REMOTE_DIR="$(cd "$(dirname "$0")" && pwd)"
SYSTEM_SCRIPT="/usr/sbin/ips-rule-policy.sh"
POST_CFG="/cfg/post-cfg.sh"

# Detect script locations (support flat or scripts/ subdir)
CUSTOM_SCRIPT="${REMOTE_DIR}/scripts/ips-rule-policy.sh"
[ ! -f "$CUSTOM_SCRIPT" ] && CUSTOM_SCRIPT="${REMOTE_DIR}/ips-rule-policy.sh"

BOOT_PRUNE_SCRIPT="${REMOTE_DIR}/scripts/boot-prune.sh"
[ ! -f "$BOOT_PRUNE_SCRIPT" ] && BOOT_PRUNE_SCRIPT="${REMOTE_DIR}/boot-prune.sh"

START_WRAPPER="${REMOTE_DIR}/scripts/start.sh"
[ ! -f "$START_WRAPPER" ] && START_WRAPPER="${REMOTE_DIR}/start.sh"

log() {
    echo "[setup] $1"
}

log "Setting permissions on scripts..."
[ -f "$CUSTOM_SCRIPT" ] && chmod +x "$CUSTOM_SCRIPT"
[ -f "$BOOT_PRUNE_SCRIPT" ] && chmod +x "$BOOT_PRUNE_SCRIPT"
[ -f "$START_WRAPPER" ] && chmod +x "$START_WRAPPER"
# Also handle other scripts if present
[ -f "${REMOTE_DIR}/scripts/post-update-prune.sh" ] && chmod +x "${REMOTE_DIR}/scripts/post-update-prune.sh"
[ -f "${REMOTE_DIR}/post-update-prune.sh" ] && chmod +x "${REMOTE_DIR}/post-update-prune.sh"
[ -f "${REMOTE_DIR}/scripts/suricata-update.sh" ] && chmod +x "${REMOTE_DIR}/scripts/suricata-update.sh"
[ -f "${REMOTE_DIR}/suricata-update.sh" ] && chmod +x "${REMOTE_DIR}/suricata-update.sh"

# Integrate with system path
if [ ! -L "$SYSTEM_SCRIPT" ]; then
    log "Backing up original system script and creating symlink..."
    [ -f "$SYSTEM_SCRIPT" ] && mv "$SYSTEM_SCRIPT" "$SYSTEM_SCRIPT.bak"
    ln -s "$CUSTOM_SCRIPT" "$SYSTEM_SCRIPT"
else
    log "Symlink to $SYSTEM_SCRIPT already exists."
fi

# Patch suricatad.sh to prevent redundant suricata-update call which consumes ~800MB RAM.
if [ -f "/usr/bin/suricatad.sh" ]; then
    if ! grep -q "# suricata-update --fail --no-test" "/usr/bin/suricatad.sh"; then
        log "Patching /usr/bin/suricatad.sh to save memory..."
        sed -i 's/suricata-update --fail --no-test/# suricata-update --fail --no-test/g' /usr/bin/suricatad.sh
    fi
fi

# Patch suricata-update.sh (cron script) to prevent redundant second update call.
if [ -f "/usr/bin/suricata-update.sh" ]; then
    # We only want to comment out the second occurrence (line 12 or similar)
    # A safer way is to check if it's already patched and then use a specific sed pattern
    if ! grep -q "# suricata-update --fail --no-test" "/usr/bin/suricata-update.sh"; then
        log "Patching /usr/bin/suricata-update.sh to save memory during cron..."
        # This sed pattern targets the second occurrence specifically
        sed -i '0,/suricata-update --fail --no-test/! s/suricata-update --fail --no-test/# suricata-update --fail --no-test/' /usr/bin/suricata-update.sh
    fi
fi

# Ensure persistence in post-cfg.sh
# Remove any existing (incorrect) entries first to avoid duplicates or misplaced hooks
sed -i "/suricata-runner/d" "$POST_CFG" 2>/dev/null

log "Adding persistence hook to $POST_CFG..."
# Create file with shebang if missing
if [ ! -f "$POST_CFG" ]; then
    echo "#!/bin/ash" > "$POST_CFG"
    echo "" >> "$POST_CFG"
fi

# Insert the hook at the top (after line 1) to avoid being skipped by an 'exit 0'
# We use a temp file for maximum compatibility with different sed versions
{
    head -n 1 "$POST_CFG"
    echo ""
    echo "# Initialize optimized Suricata rule policy and configuration"
    echo "$START_WRAPPER &"
    tail -n +2 "$POST_CFG"
} > "${POST_CFG}.tmp" && mv "${POST_CFG}.tmp" "$POST_CFG"

chmod 755 "$POST_CFG"

log "Ensuring current session config is active..."
cp "${REMOTE_DIR}/ips-policy.conf" "/etc/suricata/ips-policy.conf"

log "Ensuring Suricata runtime prerequisites..."
mkdir -p /a/suricata/data/rules
mkdir -p /var/log/suricata
mkdir -p /var/run/suricata
chown -R suricata:suricata /var/log/suricata /var/run/suricata 2>/dev/null || true
# Ensure system path is correct
if [ ! -L /var/lib/suricata ] && [ ! -d /var/lib/suricata ]; then
    ln -s /a/suricata/data /var/lib/suricata
fi

log "Triggering initial rule optimization via system path..."
$SYSTEM_SCRIPT

log "Setup complete. Memory pressure will decrease significantly on Suricata restart."
log "Run: /etc/init.d/suricata restart"
