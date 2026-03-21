#!/bin/ash
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

LOGTAG="suricata-post-update"
OFFLOAD_STATE="${REMOTE_DIR}/firewall-offload.state"

log() {
    logger -t "$LOGTAG" "$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

normalize_flag() {
    printf '%s' "${1:-0}" | tr -d '\r[:space:]'
}

is_running() {
    ps -w | grep -E 'Suricata-Main|/usr/bin/.suricata' | grep -v grep >/dev/null 2>&1
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

ensure_runtime_prereqs() {
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

    mkdir -p /var/lib/suricata/rules
    ln -sf /a/suricata/data/rules/suricata.rules /var/lib/suricata/rules/suricata.rules
    mkdir -p /var/log/suricata
    chown -R suricata:suricata /var/log/suricata 2>/dev/null || true

    # Avoid libmagic crash by disabling files logger in both runtime configs.
    for YAML in /usr/share/suricata/suricata-ids.yaml /usr/share/suricata/suricata-ips-nfq.yaml; do
        [ -f "$YAML" ] || continue
        if grep -q '^[[:space:]]*-[[:space:]]*files:' "$YAML"; then
            sed -i 's/^[[:space:]]*-[[:space:]]*files:/#        - files:/' "$YAML"
        fi
        if grep -q '^[[:space:]]*force-magic:' "$YAML"; then
            sed -i 's/^[[:space:]]*force-magic:/#            force-magic:/' "$YAML"
        fi
        rewrite_section_enabled "$YAML" "file-store"
        rewrite_section_enabled "$YAML" "tcp-data"
        rewrite_section_enabled "$YAML" "http-body-data"
        rewrite_section_enabled "$YAML" "pcap-log"
    done
}

POLICY_CONF=/etc/suricata/ips-policy.conf
IPS_INLINE=0
[ -f "$POLICY_CONF" ] && . "$POLICY_CONF"
IPS_INLINE="$(normalize_flag "$IPS_INLINE")"
log "Loaded policy from $POLICY_CONF (IPS_INLINE=$IPS_INLINE)"

log "post-update prune starting"
ensure_runtime_prereqs

was_running=0
if is_running; then
    was_running=1
    if [ -x /var/run/suricata.sh ]; then
        log "stopping via /var/run/suricata.sh"
        /var/run/suricata.sh stop || true
    else
        log "stopping via killall"
        killall suricatad.sh Suricata-Main suricata 2>/dev/null || true
    fi
    sleep 2
fi

log "running ips-rule-policy.sh"
/usr/sbin/ips-rule-policy.sh || { log "policy run failed"; exit 1; }

if [ "$was_running" -eq 1 ]; then
    if [ -x /var/run/suricata.sh ]; then
        log "starting via /var/run/suricata.sh"
        /var/run/suricata.sh start || true
    else
        if [ "$IPS_INLINE" = "1" ]; then
            log "starting via /usr/bin/suricata in NFQUEUE inline mode"
            ensure_inline_offload_state
            cleanup_nfq_rules
            apply_nfq_rules
            /usr/bin/suricata --user suricata --group suricata -c /usr/share/suricata/suricata-ips-nfq.yaml -q 0 -D
        else
            log "starting via /usr/bin/suricata in IDS mode"
            restore_offload_state
            cleanup_nfq_rules
            /usr/bin/suricata --user suricata --group suricata -c /usr/share/suricata/suricata-ids.yaml --af-packet=br-lan -D
        fi
    fi
fi

log "post-update prune complete"
