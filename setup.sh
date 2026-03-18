#!/bin/ash
# Integrated Suricata Optimization Setup for Route10
# Replaces system rule policy script with optimized in-place pruner.

REMOTE_DIR="/cfg/suricata-custom"
SYSTEM_SCRIPT="/usr/sbin/ips-rule-policy.sh"
CUSTOM_SCRIPT="${REMOTE_DIR}/ips-rule-policy.sh"
POST_CFG="/cfg/post-cfg.sh"

log() {
    echo "[setup] $1"
}

log "Setting permissions on scripts..."
chmod +x "${REMOTE_DIR}/ips-rule-policy.sh"
chmod +x "${REMOTE_DIR}/boot-prune.sh"

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
if ! grep -q "ln -sf $CUSTOM_SCRIPT $SYSTEM_SCRIPT" "$POST_CFG" 2>/dev/null; then
    log "Adding persistence hook to $POST_CFG..."
    # Ensure shebang exists
    [ ! -f "$POST_CFG" ] && echo "#!/bin/ash" > "$POST_CFG"
    
    # Add hooks to restore optimized rule policy and its configuration
    echo "" >> "$POST_CFG"
    echo "# Restore optimized Suricata rule policy and configuration" >> "$POST_CFG"
    echo "ln -sf $CUSTOM_SCRIPT $SYSTEM_SCRIPT" >> "$POST_CFG"
    echo "cp ${REMOTE_DIR}/ips-policy.conf /etc/suricata/ips-policy.conf" >> "$POST_CFG"
    # Re-apply the suricatad.sh patch after reboot if it's been lost
    echo "sed -i 's/suricata-update --fail --no-test/# suricata-update --fail --no-test/g' /usr/bin/suricatad.sh 2>/dev/null" >> "$POST_CFG"
    echo "chmod +x ${REMOTE_DIR}/boot-prune.sh" >> "$POST_CFG"
    echo "${REMOTE_DIR}/boot-prune.sh 120 >/var/log/suricata-boot-prune.log 2>&1 &" >> "$POST_CFG"
    chmod 755 "$POST_CFG"
fi

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
