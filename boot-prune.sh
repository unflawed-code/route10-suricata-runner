#!/bin/ash
set -eu

LOGTAG="suricata-boot-prune"
DELAY="${1:-60}"

log() {
    logger -t "$LOGTAG" "$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

is_running() {
    # Check if the system wrapper is active (UI enabled)
    pgrep -f "/usr/bin/suricatad.sh" >/dev/null 2>&1
}

kill_suricata() {
    log "Stopping any existing Suricata processes..."
    killall -9 suricatad.sh suricata .suricata Suricata-Main 2>/dev/null || true
    rm -f /var/run/suricata.pid
}

case "$DELAY" in
  ''|*[!0-9]*)
    log "invalid delay '$DELAY' (must be integer seconds); defaulting to 60"
    DELAY=60
    ;;
esac

log "boot-prune starting; sleeping ${DELAY}s before action"
sleep "$DELAY"
log "boot-prune awake; checking prerequisites"

if [ ! -x /usr/sbin/ips-rule-policy.sh ]; then
    log "ips-rule-policy.sh not found or not executable; skipping."
    exit 0
fi

# Load IPS policy for inline mode decision.
POLICY_CONF=/cfg/suricata-custom/ips-policy.conf
if [ ! -f "$POLICY_CONF" ]; then
    POLICY_CONF=/etc/suricata/ips-policy.conf
fi
IPS_INLINE=0
[ -f "$POLICY_CONF" ] && . "$POLICY_CONF"

# Ensure Suricata runtime prerequisites exist.
if [ ! -L /var/lib/suricata ] && [ ! -d /var/lib/suricata ]; then
    log "Creating /var/lib/suricata symlink..."
    ln -s /a/suricata/data /var/lib/suricata
fi

mkdir -p /a/suricata/data/rules
mkdir -p /var/log/suricata
mkdir -p /var/run/suricata
chown -R suricata:suricata /var/log/suricata /var/run/suricata 2>/dev/null || true

# Avoid libmagic crash by disabling files logger (idempotent).
disable_libmagic() {
    local YAML="$1"
    if [ -f "$YAML" ]; then
        if grep -q '^[[:space:]]*-[[:space:]]*files:' "$YAML"; then
            sed -i 's/^[[:space:]]*-[[:space:]]*files:/#        - files:/' "$YAML"
        fi
        if grep -q '^[[:space:]]*force-magic:' "$YAML"; then
            sed -i 's/^[[:space:]]*force-magic:/#            force-magic:/' "$YAML"
        fi
    fi
}

disable_libmagic "/usr/share/suricata/suricata-ips-nfq.yaml"
disable_libmagic "/usr/share/suricata/suricata-ids.yaml"

# Interfaces list
IFACES="-i br-lan -i br-lan_2 -i br-lan_5 -i br-lan_10 -i br-lan_15"

# Phase 1: Prune rules while system is quiet
log "running ips-rule-policy.sh"
/usr/sbin/ips-rule-policy.sh || { log "policy run failed"; exit 1; }

# Phase 2: Handle service state
if is_running; then
    log "Suricata is running (UI enabled). Restarting to apply pruned rules."
    if [ -x /var/run/suricata.sh ]; then
        /var/run/suricata.sh stop || true
        sleep 2
        /var/run/suricata.sh start || true
    else
        kill_suricata
        sleep 2
        # suricatad.sh wrapper (if triggered by system) will restart it
    fi
    log "prune complete; restarted via system paths"
else
    log "Suricata is NOT running (UI disabled). Starting in Pure CLI mode."
    
    # 1. Stop any stray processes first
    kill_suricata
    sleep 1

    # 2. Start IPS daemon (Reactive Blocker) if not running
    if ! pgrep -f "/usr/sbin/ips -n 1 -b 1" >/dev/null; then
        log "Starting ips daemon..."
        /usr/sbin/ips -n 1 -b 1 -i 0 &
        sleep 1
    fi

    # 2. Connect Firewall Chain
    iptables -N ips 2>/dev/null || true
    if ! iptables -S forwarding_rule | grep -q " -j ips"; then
        log "Connecting ips firewall chain..."
        iptables -A forwarding_rule -j ips
    fi

    # 3. Start Suricata directly (Pure CLI Mode)
    log "Starting Suricata engine directly..."
    /usr/bin/suricata --user suricata --group suricata -c /usr/share/suricata/suricata-ids.yaml $IFACES -D
    
    log "prune complete; started in Pure CLI mode"
fi
