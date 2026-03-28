#!/bin/ash
# Suricata Runner Uninstall Script for Route10

set -eu

# Detect base directory (support flat or scripts/ subdir)
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

SYSTEM_SCRIPT="/usr/sbin/ips-rule-policy.sh"
POST_CFG="/cfg/post-cfg.sh"
VECTORSCAN_RUNTIME_ROOT="/a/suricata-vectorscan"
RULES_DST="/var/lib/suricata/rules"
CRON_FILE="/etc/crontabs/root"
PROJECT_TAG="route10-suricata-runner"
POST_CFG_BLOCK_BEGIN="# BEGIN ${PROJECT_TAG}"
POST_CFG_BLOCK_END="# END ${PROJECT_TAG}"

log() {
    echo "[uninstall] $*"
}

# 0. Confirmation Prompt
FORCE=0
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
    FORCE=1
fi

if [ "$FORCE" -eq 0 ]; then
    printf "WARNING: This will stop Suricata and revert all system integration changes.\n"
    printf "Are you sure you want to proceed? (y/N): "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            ;;
        *)
            echo "Uninstall cancelled."
            exit 0
            ;;
    esac
fi

# 1. Stop services
log "Stopping Suricata and related daemons..."
killall -9 suricatad.sh suricata .suricata Suricata-Main ips 2>/dev/null || true
rm -f /var/run/suricata.pid

# 2. Restore system rule policy script
if [ -L "$SYSTEM_SCRIPT" ]; then
    log "Removing rule policy symlink..."
    rm -f "$SYSTEM_SCRIPT"
    if [ -f "${SYSTEM_SCRIPT}.bak" ]; then
        log "Restoring original system rule policy script..."
        mv "${SYSTEM_SCRIPT}.bak" "$SYSTEM_SCRIPT"
    fi
fi

# 3. Revert patches to system scripts
if [ -f "/usr/bin/suricatad.sh" ]; then
    log "Reverting patches in /usr/bin/suricatad.sh..."
    sed -i 's/# suricata-update --fail --no-test/suricata-update --fail --no-test/g' /usr/bin/suricatad.sh
fi

if [ -f "/usr/bin/suricata-update.sh" ]; then
    log "Reverting patches in /usr/bin/suricata-update.sh..."
    sed -i 's/# suricata-update --fail --no-test/suricata-update --fail --no-test/g' /usr/bin/suricata-update.sh
fi

# 4. Remove persistence hook from post-cfg.sh
if [ -f "$POST_CFG" ]; then
    log "Removing startup hook from $POST_CFG..."
    # Remove the block between BEGIN and END
    sed -i "/${POST_CFG_BLOCK_BEGIN}/,/${POST_CFG_BLOCK_END}/d" "$POST_CFG"
    # Clean up any leftover blank lines at the end
    sed -i '${/^[[:space:]]*$/d;}' "$POST_CFG"
fi

# 5. Clean up cron jobs
if [ -f "$CRON_FILE" ]; then
    log "Cleaning up project cron entries..."
    # Restore original suricata-update cron (without our pruning script)
    sed -i '/suricata-update --fail --no-test/c\30 3 * * * /usr/bin/suricata-update.sh' "$CRON_FILE"
    # Remove our prune and runner update entries
    sed -i '/post-update-prune.sh/d' "$CRON_FILE"
    sed -i '/runner.sh update/d' "$CRON_FILE"
    /etc/init.d/cron restart >/dev/null 2>&1 || true
fi

# 6. Remove UCI configuration
if command -v uci >/dev/null 2>&1; then
    log "Removing UCI configuration..."
    uci delete suricata-runner 2>/dev/null || true
    uci commit suricata-runner 2>/dev/null || true
fi

# 7. Remove Vectorscan runtime and symlinks
if [ -d "$VECTORSCAN_RUNTIME_ROOT" ]; then
    log "Removing Vectorscan runtime at $VECTORSCAN_RUNTIME_ROOT..."
    rm -rf "$VECTORSCAN_RUNTIME_ROOT"
fi

if [ -L /var/lib/suricata ]; then
    log "Removing /var/lib/suricata symlink..."
    rm -f /var/lib/suricata
fi

# 8. Clean up firewall rules
log "Cleaning up firewall rules..."
iptables -t mangle -D FORWARD -j IPS_NFQ 2>/dev/null || true
iptables -t mangle -F IPS_NFQ 2>/dev/null || true
iptables -t mangle -X IPS_NFQ 2>/dev/null || true
iptables -D forwarding_rule -j ips 2>/dev/null || true
iptables -F ips 2>/dev/null || true
iptables -X ips 2>/dev/null || true

if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -t mangle -D FORWARD -j IPS_NFQ 2>/dev/null || true
    ip6tables -t mangle -F IPS_NFQ 2>/dev/null || true
    ip6tables -t mangle -X IPS_NFQ 2>/dev/null || true
fi

# 9. Clean up managed rules and marker file
rm -f "${RULES_DST}/route10-websocket.rules" "${RULES_DST}/route10-ndpi-bypass.rules" 2>/dev/null || true
rm -f "${REMOTE_DIR}/.setup_done"

log "Uninstall complete. System integration has been reverted."
log "NOTE: The project directory at $REMOTE_DIR has NOT been removed."
