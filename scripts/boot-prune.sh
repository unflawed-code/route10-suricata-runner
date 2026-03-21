#!/bin/ash
# Suricata Boot Pruning & Startup Automation for Route10
# Dynamically detects project directory to support arbitrary install paths.

set -eu

# Detect base directory (support flat or scripts/ subdir)
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

OFFLOAD_STATE="${REMOTE_DIR}/firewall-offload.state"

LOGTAG="suricata-boot-prune"
DELAY="${1:-60}"

log() {
    logger -t "$LOGTAG" "$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

normalize_flag() {
    printf '%s' "${1:-0}" | tr -d '\r[:space:]'
}

is_running() {
    # UI mode is driven by the system wrapper, not by a raw Suricata process.
    pgrep -f "/usr/bin/suricatad.sh" >/dev/null 2>&1
}

kill_suricata() {
    log "Stopping any existing Suricata processes..."
    killall -9 suricatad.sh suricata .suricata Suricata-Main 2>/dev/null || true
    rm -f /var/run/suricata.pid
}

get_firewall_default() {
    uci -q get "firewall.@defaults[0].$1" 2>/dev/null || echo "0"
}

set_firewall_default() {
    uci set "firewall.@defaults[0].$1=$2"
}

save_offload_state() {
    {
        echo "FLOW_OFFLOADING=$(get_firewall_default flow_offloading)"
        echo "FLOW_OFFLOADING_HW=$(get_firewall_default flow_offloading_hw)"
    } > "$OFFLOAD_STATE"
}

load_offload_state() {
    FLOW_OFFLOADING=""
    FLOW_OFFLOADING_HW=""
    [ -f "$OFFLOAD_STATE" ] && . "$OFFLOAD_STATE"
}

reload_firewall_if_needed() {
    if [ "$1" = "1" ]; then
        log "Reloading firewall to apply flow offloading change..."
        /etc/init.d/firewall reload
        sleep 2
    fi
}

ensure_inline_offload_state() {
    local current_sw current_hw changed
    current_sw="$(get_firewall_default flow_offloading)"
    current_hw="$(get_firewall_default flow_offloading_hw)"
    changed=0

    if [ "$current_sw" = "1" ] || [ "$current_hw" = "1" ]; then
        if [ ! -f "$OFFLOAD_STATE" ]; then
            save_offload_state
            log "Saved existing firewall offload settings to $OFFLOAD_STATE"
        fi
        [ "$current_sw" = "1" ] && set_firewall_default flow_offloading 0 && changed=1
        [ "$current_hw" = "1" ] && set_firewall_default flow_offloading_hw 0 && changed=1
        if [ "$changed" = "1" ]; then
            log "Disabling firewall flow offloading for inline IPS mode"
            uci commit firewall
        fi
    fi

    reload_firewall_if_needed "$changed"
}

restore_offload_state() {
    local current_sw current_hw target_sw target_hw changed
    [ -f "$OFFLOAD_STATE" ] || return 0

    load_offload_state
    target_sw="${FLOW_OFFLOADING:-0}"
    target_hw="${FLOW_OFFLOADING_HW:-0}"
    current_sw="$(get_firewall_default flow_offloading)"
    current_hw="$(get_firewall_default flow_offloading_hw)"
    changed=0

    if [ "$current_sw" != "$target_sw" ]; then
        set_firewall_default flow_offloading "$target_sw"
        changed=1
    fi
    if [ "$current_hw" != "$target_hw" ]; then
        set_firewall_default flow_offloading_hw "$target_hw"
        changed=1
    fi

    if [ "$changed" = "1" ]; then
        log "Restoring firewall flow offloading settings from $OFFLOAD_STATE"
        uci commit firewall
    fi

    reload_firewall_if_needed "$changed"
    rm -f "$OFFLOAD_STATE"
}

disable_file_magic_outputs() {
    rewrite_section_enabled() {
        local yaml="$1"
        local section="$2"
        local tmp="${yaml}.tmp"
        awk -v section="$section" '
            BEGIN { in_section = 0; changed = 0 }
            $0 ~ "^[[:space:]]*-[[:space:]]*" section ":" {
                in_section = 1
                changed = 0
                print
                next
            }
            in_section && $0 ~ "^[[:space:]]*-[[:space:]]*" {
                in_section = 0
            }
            in_section && !changed && $0 ~ "^[[:space:]]*enabled:[[:space:]]*yes" {
                sub(/enabled:[[:space:]]*yes/, "enabled: no")
                changed = 1
            }
            { print }
        ' "$yaml" > "$tmp" && mv "$tmp" "$yaml"
    }

    local yaml
    for yaml in /usr/share/suricata/suricata-ids.yaml /usr/share/suricata/suricata-ips-nfq.yaml; do
        [ -f "$yaml" ] || continue

        if grep -q '^[[:space:]]*-[[:space:]]*files:' "$yaml"; then
            sed -i 's/^[[:space:]]*-[[:space:]]*files:/#        - files:/' "$yaml"
        fi
        if grep -q '^[[:space:]]*force-magic:' "$yaml"; then
            sed -i 's/^[[:space:]]*force-magic:/#            force-magic:/' "$yaml"
        fi
        rewrite_section_enabled "$yaml" "file-store"
        rewrite_section_enabled "$yaml" "tcp-data"
        rewrite_section_enabled "$yaml" "http-body-data"
        rewrite_section_enabled "$yaml" "pcap-log"
    done
}

cleanup_nfq_rules() {
    local chain="IPS_NFQ"
    while iptables -t mangle -D FORWARD -j "$chain" 2>/dev/null; do :; done
    iptables -t mangle -F "$chain" 2>/dev/null || true
    iptables -t mangle -X "$chain" 2>/dev/null || true

    if command -v ip6tables >/dev/null 2>&1; then
        while ip6tables -t mangle -D FORWARD -j "$chain" 2>/dev/null; do :; done
        ip6tables -t mangle -F "$chain" 2>/dev/null || true
        ip6tables -t mangle -X "$chain" 2>/dev/null || true
    fi
}

apply_nfq_rules() {
    local chain="IPS_NFQ"
    local queue_num="0"
    local bypass_mark="0x8000/0x8000"

    iptables -t mangle -N "$chain" 2>/dev/null || true
    iptables -t mangle -F "$chain"
    iptables -t mangle -C FORWARD -j "$chain" 2>/dev/null || iptables -t mangle -I FORWARD 1 -j "$chain"
    iptables -t mangle -A "$chain" -m mark --mark "$bypass_mark" -j ACCEPT
    iptables -t mangle -A "$chain" -j NFQUEUE --queue-num "$queue_num" --queue-bypass

    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -t mangle -N "$chain" 2>/dev/null || true
        ip6tables -t mangle -F "$chain"
        ip6tables -t mangle -C FORWARD -j "$chain" 2>/dev/null || ip6tables -t mangle -I FORWARD 1 -j "$chain"
        ip6tables -t mangle -A "$chain" -m mark --mark "$bypass_mark" -j ACCEPT
        ip6tables -t mangle -A "$chain" -j NFQUEUE --queue-num "$queue_num" --queue-bypass
    fi
}

case "$DELAY" in
  ''|*[!0-9]*)
    log "invalid delay '$DELAY' (must be integer seconds); defaulting to 60"
    DELAY=60
    ;;
esac

log "boot-prune starting; sleeping ${DELAY}s before action"
sleep "$DELAY"
log "boot-prune awake from $REMOTE_DIR"

if [ ! -x /usr/sbin/ips-rule-policy.sh ]; then
    log "ips-rule-policy.sh not found or not executable; skipping."
    exit 0
fi

# MARK START OF DANGER ZONE
touch "${REMOTE_DIR}/BOOT_PENDING"

# Load IPS policy for inline mode decision.
POLICY_CONF="${REMOTE_DIR}/ips-policy.conf"
if [ ! -f "$POLICY_CONF" ]; then
    POLICY_CONF=/etc/suricata/ips-policy.conf
fi
IPS_INLINE=0
[ -f "$POLICY_CONF" ] && . "$POLICY_CONF"
IPS_INLINE="$(normalize_flag "$IPS_INLINE")"
log "Loaded policy from $POLICY_CONF (IPS_INLINE=$IPS_INLINE)"

# Sync config to /etc/suricata so system tools see it
cp "$POLICY_CONF" /etc/suricata/ips-policy.conf 2>/dev/null

# Ensure Suricata runtime prerequisites exist.
if [ ! -L /var/lib/suricata ] && [ ! -d /var/lib/suricata ]; then
    log "Creating /var/lib/suricata symlink..."
    ln -s /a/suricata/data /var/lib/suricata
fi

mkdir -p /a/suricata/data/rules
mkdir -p /var/log/suricata
mkdir -p /var/run/suricata
chown -R suricata:suricata /var/log/suricata /var/run/suricata 2>/dev/null || true
disable_file_magic_outputs

# Interfaces list
LAN_IFACES="br-lan br-lan_2 br-lan_5 br-lan_10 br-lan_15"

# Phase 1: Prune rules
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
    fi
    log "prune complete; restarted via system paths"
else
    log "Suricata is NOT running (UI disabled). Starting in Pure CLI mode."
    kill_suricata
    sleep 1

    if [ "$IPS_INLINE" = "1" ]; then
        log "Mode: Inline IPS (NFQUEUE)"
        ensure_inline_offload_state
        # Stop reactive daemon if it was running
        killall -9 ips 2>/dev/null || true
        # Clean up reactive iptables rule
        iptables -D forwarding_rule -j ips 2>/dev/null || true

        cleanup_nfq_rules
        apply_nfq_rules

        log "Starting Suricata engine directly in Inline mode (NFQUEUE)..."
        /usr/bin/suricata --user suricata --group suricata -c /usr/share/suricata/suricata-ips-nfq.yaml -q 0 -D
    else
        log "Mode: Reactive Blocking (IDS + ips daemon)"
        restore_offload_state
        # Clean up NFQUEUE if it was running
        cleanup_nfq_rules
        
        if ! pgrep -f "/usr/sbin/ips -n 1 -b 1" >/dev/null; then
            log "Starting ips daemon..."
            /usr/sbin/ips -n 1 -b 1 -i 0 &
            sleep 1
        fi

        iptables -N ips 2>/dev/null || true
        if ! iptables -S forwarding_rule | grep -q " -j ips"; then
            log "Connecting ips firewall chain..."
            iptables -A forwarding_rule -j ips
        fi

        # Build IDS args
        IDS_ARGS=""
        for iface in $LAN_IFACES; do
            if [ -d "/sys/class/net/$iface" ]; then
                IDS_ARGS="$IDS_ARGS -i $iface"
            fi
        done

        log "Starting Suricata engine directly in IDS mode ($IDS_ARGS)..."
        /usr/bin/suricata --user suricata --group suricata -c /usr/share/suricata/suricata-ids.yaml $IDS_ARGS -D
    fi
    
    log "prune complete; started in Pure CLI mode"
fi

# 3. Successful finish: clear the BOOT_PENDING sentinel file
rm -f "${REMOTE_DIR}/BOOT_PENDING"
