#!/bin/ash
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

LOGTAG="suricata-post-update"
ENABLE_STATS="${1:-0}"
OFFLOAD_STATE="${REMOTE_DIR}/firewall-offload.state"
DEFAULT_SURICATA_BIN="/usr/bin/suricata"
DEFAULT_SURICATA_LIB_PATH=""
VECTORSCAN_DIR="${REMOTE_DIR}/vectorscan"
VECTORSCAN_WRAPPER="${VECTORSCAN_DIR}/bin/route10-suricata"
VECTORSCAN_RUNTIME_ROOT="/a/suricata-vectorscan"
NDPI_PLUGIN_PATH="${VECTORSCAN_RUNTIME_ROOT}/lib/suricata/ndpi.so"
RULES_DIR="/var/lib/suricata/rules"
WEBSOCKET_RULE_FILE="route10-websocket.rules"
NDPI_BYPASS_RULE_FILE="route10-ndpi-bypass.rules"

log() {
    logger -t "$LOGTAG" "$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

normalize_flag() {
    printf '%s' "${1:-0}" | tr -d ' \n\r\t'
}

normalize_text() {
    printf '%s' "${1:-}" | tr -d '\r'
}

resolve_suricata_bin() {
    local candidate
    if [ -x "$VECTORSCAN_WRAPPER" ]; then
        candidate="$VECTORSCAN_WRAPPER"
    else
        candidate="$DEFAULT_SURICATA_BIN"
    fi
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        printf '%s' "$candidate"
    else
        printf '%s' "$DEFAULT_SURICATA_BIN"
    fi
}

resolve_suricata_lib_path() {
    if [ -x "$VECTORSCAN_WRAPPER" ]; then
        printf '%s' "${VECTORSCAN_DIR}/lib:/.deb/lib"
    else
        normalize_text "${SURICATA_LIB_PATH:-$DEFAULT_SURICATA_LIB_PATH}"
    fi
}

run_suricata() {
    local bin lib_path
    bin="$(resolve_suricata_bin)"
    lib_path="$(resolve_suricata_lib_path)"

    if [ "$(basename "$bin")" = "route10-suricata" ]; then
        log "Starting Suricata via wrapper SURICATA_BIN=$bin"
        LD_LIBRARY_PATH= "$bin" "$@"
    elif [ -n "$lib_path" ]; then
        log "Starting Suricata with SURICATA_BIN=$bin and SURICATA_LIB_PATH=$lib_path"
        LD_LIBRARY_PATH="$lib_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$bin" "$@"
    else
        log "Starting Suricata with SURICATA_BIN=$bin"
        "$bin" "$@"
    fi
}

ensure_vectorscan_runtime() {
    link_latest_lib() {
        local lib_dir="$1"
        local glob="$2"
        local direct_link="$3"
        local major_link="$4"
        local real_name=""

        real_name="$(basename "$(ls -1 ${lib_dir}/${glob} 2>/dev/null | sort | tail -n 1)")"
        [ -n "${real_name:-}" ] || return 0
        [ -f "${lib_dir}/${real_name}" ] || return 0

        if [ -n "$major_link" ]; then
            ln -sf "$real_name" "${lib_dir}/${major_link}"
            ln -sf "$major_link" "${lib_dir}/${direct_link}"
        else
            ln -sf "$real_name" "${lib_dir}/${direct_link}"
        fi
    }

    local runtime_dir lib_dir ndpi_real ndpi_major
    runtime_dir="$VECTORSCAN_DIR"
    [ -d "$runtime_dir" ] || return 0

    lib_dir="${runtime_dir}/lib"
    [ -d "$lib_dir" ] || return 0

    link_latest_lib "$lib_dir" 'libhs.so.5.*' 'libhs.so' 'libhs.so.5'
    link_latest_lib "$lib_dir" 'libhs_runtime.so.5.*' 'libhs_runtime.so' 'libhs_runtime.so.5'
    if [ -f "${lib_dir}/libstdc++.so.6.0.30" ]; then
        ln -sf libstdc++.so.6.0.30 "${lib_dir}/libstdc++.so.6"
    fi
    ndpi_real="$(basename "$(ls -1 "${lib_dir}"/libndpi.so.* 2>/dev/null | sort | tail -n 1)")"
    if [ -n "${ndpi_real:-}" ] && [ -f "${lib_dir}/${ndpi_real}" ]; then
        ndpi_major="$(printf '%s' "$ndpi_real" | sed -n 's/^libndpi\.so\.\([0-9][0-9]*\)\..*/\1/p')"
        if [ -n "${ndpi_major:-}" ]; then
            ln -sf "$ndpi_real" "${lib_dir}/libndpi.so.${ndpi_major}"
            ln -sf "libndpi.so.${ndpi_major}" "${lib_dir}/libndpi.so"
        else
            ln -sf "$ndpi_real" "${lib_dir}/libndpi.so"
        fi
    fi
}

sync_managed_rules() {
    local src_dir="${REMOTE_DIR}/rules"
    local rule_file

    [ -d "$src_dir" ] || return 0
    mkdir -p "$RULES_DIR"

    for rule_file in "$WEBSOCKET_RULE_FILE" "$NDPI_BYPASS_RULE_FILE"; do
        if [ -f "${src_dir}/${rule_file}" ]; then
            cp -f "${src_dir}/${rule_file}" "${RULES_DIR}/${rule_file}"
        fi
    done
    chown -R suricata:suricata "$RULES_DIR" 2>/dev/null || true
}

ensure_rule_file_entry() {
    local yaml="$1"
    local rule_file="$2"
    local enabled="$3"
    local escaped_rule
    escaped_rule="$(printf '%s' "$rule_file" | sed 's/[.[\*^$()+?{}|/]/\\&/g')"

    if [ "$enabled" = "1" ]; then
        if ! grep -Fqx "  - ${rule_file}" "$yaml" 2>/dev/null; then
            sed -i "/^[[:space:]]*-[[:space:]]*suricata\\.rules$/a\\  - ${rule_file}" "$yaml"
        fi
    else
        sed -i "\|^[[:space:]]*-[[:space:]]*${escaped_rule}$|d" "$yaml"
    fi
}

ensure_plugin_entry() {
    local yaml="$1"
    local plugin_path="$2"
    local enabled="$3"
    local escaped_plugin
    escaped_plugin="$(printf '%s' "$plugin_path" | sed 's/[.[\*^$()+?{}|/]/\\&/g')"

    if [ "$enabled" = "1" ]; then
        if ! grep -Fqx "  - ${plugin_path}" "$yaml" 2>/dev/null; then
            sed -i "/^plugins:/a\\  - ${plugin_path}" "$yaml"
        fi
    else
        sed -i "\|^[[:space:]]*-[[:space:]]*${escaped_plugin}$|d" "$yaml"
    fi
}

ensure_websocket_parser() {
    local yaml="$1"
    local enabled="$2"
    sed -i '/^    websocket:/,/^    [a-z0-9-]\+:/ {/^[[:space:]]*enabled:[[:space:]]*\(yes\|no\)$/d; /^[[:space:]]*#enabled:[[:space:]]*yes$/d;}' "$yaml"
    if [ "$enabled" = "1" ]; then
        sed -i '/^    websocket:/a\      enabled: yes' "$yaml"
    else
        sed -i '/^    websocket:/a\      #enabled: yes' "$yaml"
    fi
}

ensure_telnet_detection() {
    local yaml="$1"
    sed -i '/^    telnet:/,/^    [a-z0-9-]\+:/ {/^[[:space:]]*enabled:[[:space:]]*\(yes\|no\)$/d; /^[[:space:]]*detection-enabled:[[:space:]]*\(yes\|no\)$/d; /^[[:space:]]*#enabled:[[:space:]]*yes$/d; /^[[:space:]]*#detection-enabled:[[:space:]]*yes$/d;}' "$yaml"
    sed -i '/^    telnet:/a\      detection-enabled: yes\n      enabled: yes' "$yaml"
}

apply_feature_patches() {
    local enable_ndpi enable_websocket enable_ws_rules enable_ndpi_bypass
    local yaml
    enable_ndpi="$1"
    enable_websocket="$2"
    enable_ws_rules="$3"
    enable_ndpi_bypass="$4"

    for yaml in /usr/share/suricata/suricata-ids.yaml /usr/share/suricata/suricata-ips-nfq.yaml; do
        [ -f "$yaml" ] || continue

        if [ "$enable_ndpi" = "1" ] && [ -f "$NDPI_PLUGIN_PATH" ]; then
            ensure_plugin_entry "$yaml" "$NDPI_PLUGIN_PATH" 1
        else
            ensure_plugin_entry "$yaml" "$NDPI_PLUGIN_PATH" 0
            [ "$enable_ndpi" = "1" ] && log "WARNING: ENABLE_NDPI=1 but plugin missing at $NDPI_PLUGIN_PATH"
        fi

        ensure_websocket_parser "$yaml" "$enable_websocket"
        ensure_telnet_detection "$yaml"
        ensure_rule_file_entry "$yaml" "$WEBSOCKET_RULE_FILE" "$enable_ws_rules"
        ensure_rule_file_entry "$yaml" "$NDPI_BYPASS_RULE_FILE" "$enable_ndpi_bypass"
    done
}

is_running() {
    ps -w | grep -E 'Suricata-Main|/usr/bin/.suricata' | grep -v grep >/dev/null 2>&1
}

cleanup_suricata_runtime() {
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
    local queue_balance="0:3"
    local bypass_mark="0x8000/0x8000"

    iptables -t mangle -N "$chain" 2>/dev/null || true
    iptables -t mangle -F "$chain"
    iptables -t mangle -C FORWARD -j "$chain" 2>/dev/null || iptables -t mangle -I FORWARD 1 -j "$chain"
    iptables -t mangle -A "$chain" -m mark --mark "$bypass_mark" -j ACCEPT
    iptables -t mangle -A "$chain" -j NFQUEUE --queue-balance "$queue_balance" --queue-bypass

    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -t mangle -N "$chain" 2>/dev/null || true
        ip6tables -t mangle -F "$chain"
        ip6tables -t mangle -C FORWARD -j "$chain" 2>/dev/null || ip6tables -t mangle -I FORWARD 1 -j "$chain"
        ip6tables -t mangle -A "$chain" -m mark --mark "$bypass_mark" -j ACCEPT
        ip6tables -t mangle -A "$chain" -j NFQUEUE --queue-balance "$queue_balance" --queue-bypass
    fi
}

apply_performance_patches() {
    local yaml
    local enable_stats="$1"
    for yaml in /usr/share/suricata/suricata-ips-nfq.yaml; do
        [ -f "$yaml" ] || continue

        # Opt 2: Enable worker runmode (best for NFQ multi-queue)
        sed -i 's/^#runmode: autofp/runmode: workers/' "$yaml"
        sed -i 's/^#runmode: workers/runmode: workers/' "$yaml"

        # Opt 2: Enable CPU affinity
        sed -i 's/^\(  \)set-cpu-affinity: no/\1set-cpu-affinity: yes/' "$yaml"

        # Opt 3: Increase max-pending-packets from 1024 to 10000
        sed -i 's/^#max-pending-packets: 1024/max-pending-packets: 10000/' "$yaml"

        # Use the high detect profile for the inline path
        sed -i '/^detect:/,/^[a-z]/ s/^\([[:space:]]*\)profile:[[:space:]]*medium/\1profile: high/' "$yaml"
        sed -i '/^detect:/,/^[a-z]/ s/^\([[:space:]]*\)profile:[[:space:]]*high/\1profile: high/' "$yaml"

        # Enable NFQ batchcount, keep fail-open disabled
        sed -i 's/^[[:space:]]*batchcount:[[:space:]]*20/  batchcount: 20/' "$yaml"
        sed -i 's/^#[[:space:]]*batchcount:[[:space:]]*20/  batchcount: 20/' "$yaml"
        sed -i 's/^[[:space:]]*fail-open:[[:space:]]*yes/#  fail-open: yes/' "$yaml"

        # Opt 4: TLS encryption-handling bypass
        sed -i '/^    tls:/,/^    [a-z]/ s/^\(      \)#encryption-handling: track-only/\1encryption-handling: bypass/' "$yaml"

        # Opt 4: SSH encryption-handling bypass
        sed -i '/^    ssh:/,/^    [a-z]/ s/^\(      \)# encryption-handling: track-only/\1encryption-handling: bypass/' "$yaml"

        # Opt 2.1: Balanced CPU affinity (Cores 0-3 for 4 workers)
        if ! grep -q "worker-cpu-set:" "$yaml"; then
            sed -i '/management-cpu-set:/a \    - worker-cpu-set:\n        cpu: [ 0, 1, 2, 3 ]\n        mode: exclusive' "$yaml"
        fi

        # Opt 6: Stats logging toggle
        if [ "$enable_stats" = "1" ]; then
            if ! grep -q "#AUTOGEN_STATS" "$yaml"; then
                sed -i '/^outputs:/a \  #AUTOGEN_STATS\n  - stats:\n      enabled: yes\n      filename: stats.log\n      interval: 15\n  #END_AUTOGEN_STATS' "$yaml"
            fi
        else
            sed -i '/#AUTOGEN_STATS/,/#END_AUTOGEN_STATS/d' "$yaml"
        fi

        log "Applied performance patches to $yaml"
    done
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
    if [ ! -L /var/lib/suricata ] || [ "$(readlink -f /var/lib/suricata 2>/dev/null)" != "/a/suricata/data" ]; then
        ln -sf /a/suricata/data/rules/suricata.rules /var/lib/suricata/rules/suricata.rules
    fi
    mkdir -p /var/lib/suricata/cache/sgh
    mkdir -p /var/log/suricata
    chown -R suricata:suricata /a/suricata/data/cache /a/suricata/data/cache/sgh /var/log/suricata 2>/dev/null || true

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
SURICATA_BIN="$DEFAULT_SURICATA_BIN"
SURICATA_LIB_PATH="$DEFAULT_SURICATA_LIB_PATH"
ENABLE_NDPI=1
ENABLE_WEBSOCKET=1
ENABLE_WEBSOCKET_RULES=1
ENABLE_NDPI_BYPASS=0
[ -f "$POLICY_CONF" ] && . "$POLICY_CONF"
IPS_INLINE="$(normalize_flag "$IPS_INLINE")"
SURICATA_BIN="$(resolve_suricata_bin)"
SURICATA_LIB_PATH="$(resolve_suricata_lib_path)"
ENABLE_NDPI="$(normalize_flag "$ENABLE_NDPI")"
ENABLE_WEBSOCKET="$(normalize_flag "$ENABLE_WEBSOCKET")"
ENABLE_WEBSOCKET_RULES="$(normalize_flag "$ENABLE_WEBSOCKET_RULES")"
ENABLE_NDPI_BYPASS="$(normalize_flag "$ENABLE_NDPI_BYPASS")"
log "Loaded policy from $POLICY_CONF (IPS_INLINE=$IPS_INLINE, ENABLE_NDPI=$ENABLE_NDPI, ENABLE_WEBSOCKET=$ENABLE_WEBSOCKET, ENABLE_WEBSOCKET_RULES=$ENABLE_WEBSOCKET_RULES, ENABLE_NDPI_BYPASS=$ENABLE_NDPI_BYPASS, SURICATA_BIN=$SURICATA_BIN${SURICATA_LIB_PATH:+, SURICATA_LIB_PATH=$SURICATA_LIB_PATH})"

log "post-update prune starting"
ensure_vectorscan_runtime
sync_managed_rules
ensure_runtime_prereqs
apply_feature_patches "$ENABLE_NDPI" "$ENABLE_WEBSOCKET" "$ENABLE_WEBSOCKET_RULES" "$ENABLE_NDPI_BYPASS"

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
    cleanup_suricata_runtime
fi

log "running ips-rule-policy.sh"
/usr/sbin/ips-rule-policy.sh || { log "policy run failed"; exit 1; }

if [ "$was_running" -eq 1 ]; then
    if [ -x /var/run/suricata.sh ]; then
        log "starting via /var/run/suricata.sh"
        /var/run/suricata.sh start || true
    else
        cleanup_suricata_runtime
        if [ "$IPS_INLINE" = "1" ]; then
            log "starting via /usr/bin/suricata in NFQUEUE inline mode (4 queues, workers)"
            ensure_inline_offload_state
            cleanup_nfq_rules
            apply_nfq_rules
            apply_performance_patches "$ENABLE_STATS"
            run_suricata --user suricata --group suricata -c /usr/share/suricata/suricata-ips-nfq.yaml -q 0 -q 1 -q 2 -q 3 -D
        else
            log "starting via /usr/bin/suricata in IDS mode"
            restore_offload_state
            cleanup_nfq_rules
            run_suricata --user suricata --group suricata -c /usr/share/suricata/suricata-ids.yaml --af-packet=br-lan -D
        fi
    fi
fi

log "post-update prune complete"
