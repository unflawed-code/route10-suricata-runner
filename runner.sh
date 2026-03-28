#!/bin/ash

set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

PROJECT_TAG="route10-suricata-runner"
POST_CFG="/cfg/post-cfg.sh"
CRON_FILE="/etc/crontabs/root"
VERSION_SCRIPT="${REMOTE_DIR}/scripts/version.sh"
[ ! -f "$VERSION_SCRIPT" ] && VERSION_SCRIPT="${REMOTE_DIR}/version.sh"
SETUP_SCRIPT="${REMOTE_DIR}/setup.sh"
START_SCRIPT="${REMOTE_DIR}/scripts/start.sh"
[ ! -f "$START_SCRIPT" ] && START_SCRIPT="${REMOTE_DIR}/start.sh"
BOOT_PRUNE_SCRIPT="${REMOTE_DIR}/scripts/boot-prune.sh"
[ ! -f "$BOOT_PRUNE_SCRIPT" ] && BOOT_PRUNE_SCRIPT="${REMOTE_DIR}/boot-prune.sh"
POLICY_CONF="${REMOTE_DIR}/ips-policy.conf"
ACTIVE_POLICY_CONF="/etc/suricata/ips-policy.conf"

error() {
    echo "ERROR: $*" >&2
    exit 1
}

require_file() {
    [ -f "$1" ] || error "Missing required file: $1"
}

load_version() {
    require_file "$VERSION_SCRIPT"
    # shellcheck disable=SC1090
    . "$VERSION_SCRIPT"
}

print_version() {
    load_version
    print_suricata_runner_version
}

print_help() {
    cat <<EOF
Usage:
  /bin/ash <project-dir>/runner.sh <command> [options]
  /bin/ash <project-dir>/runner.sh --version
  /bin/ash <project-dir>/runner.sh --help

Commands:
  apply                    Run boot-prune.sh with default delay 0
  prune                    Alias of apply
  boot-prune               Alias of apply
  start                    Run scripts/start.sh
  status                   Print operational summary
  update [--force]         Check for and apply script/rule updates
  version                  Print version
  help                     Print this help

Apply options:
  --delay <seconds>        Delay before apply (default: 0)
  --stats                  Enable Suricata stats logging for this apply
  --no-stats               Disable Suricata stats logging for this apply (default)

Examples:
  /bin/ash <project-dir>/runner.sh apply
  /bin/ash <project-dir>/runner.sh apply --delay 120
  /bin/ash <project-dir>/runner.sh apply --stats
  /bin/ash <project-dir>/runner.sh start
  /bin/ash <project-dir>/runner.sh status
  /bin/ash <project-dir>/runner.sh update
  /bin/ash <project-dir>/runner.sh --version
EOF
}

run_apply() {
    local delay=0
    local enable_stats=0

    require_file "$BOOT_PRUNE_SCRIPT"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --delay)
                shift
                [ "$#" -gt 0 ] || error "Missing value for --delay"
                delay="$1"
                ;;
            --stats)
                enable_stats=1
                ;;
            --no-stats)
                enable_stats=0
                ;;
            *)
                error "Unknown apply option: $1"
                ;;
        esac
        shift
    done

    case "$delay" in
        ''|*[!0-9]*)
            error "Invalid delay '$delay' (must be integer seconds)"
            ;;
    esac

    /bin/ash "$BOOT_PRUNE_SCRIPT" "$delay" "$enable_stats"
}

run_start() {
    require_file "$START_SCRIPT"
    /bin/ash "$START_SCRIPT"
}

run_update() {
    local updater="${REMOTE_DIR}/scripts/updater.sh"
    require_file "$updater"
    chmod +x "$updater"
    
    local force=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --force) force=1 ;;
            *) error "Unknown update option: $1" ;;
        esac
        shift
    done

    if [ "$force" = "1" ]; then
        /bin/ash "$updater" force
    else
        /bin/ash "$updater" check
    fi
}

get_policy_value() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 0
    sed -n "s/^${key}=//p" "$file" | tail -n 1
}

get_active_yaml() {
    case "$(get_policy_value "$ACTIVE_POLICY_CONF" "IPS_INLINE")" in
        1) echo "/usr/share/suricata/suricata-ips-nfq.yaml" ;;
        *) echo "/usr/share/suricata/suricata-ids.yaml" ;;
    esac
}

run_status() {
    local version project_inline active_inline suricata_proc ips_proc
    local mode matcher rules_line cron_update cron_prune cron_runner hook_status
    local current_start_line commented_start_line vectorscan_present
    local project_ndpi project_websocket project_ws_rules project_ndpi_bypass project_ndpi_security
    local project_auto_update
    local active_yaml ndpi_status websocket_status websocket_rules_status ndpi_bypass_status ndpi_security_status

    load_version
    version="$SURICATA_RUNNER_VERSION"
    project_inline="$(get_policy_value "$POLICY_CONF" "IPS_INLINE")"
    active_inline="$(get_policy_value "$ACTIVE_POLICY_CONF" "IPS_INLINE")"
    project_ndpi="$(get_policy_value "$POLICY_CONF" "ENABLE_NDPI")"
    project_websocket="$(get_policy_value "$POLICY_CONF" "ENABLE_WEBSOCKET")"
    project_ws_rules="$(get_policy_value "$POLICY_CONF" "ENABLE_WEBSOCKET_RULES")"
    project_ndpi_bypass="$(get_policy_value "$POLICY_CONF" "ENABLE_NDPI_BYPASS")"
    project_ndpi_security="$(get_policy_value "$POLICY_CONF" "ENABLE_NDPI_SECURITY")"
    project_auto_update="$(get_policy_value "$POLICY_CONF" "ENABLE_AUTO_UPDATE")"
    active_yaml="$(get_active_yaml)"

    if [ -x "${REMOTE_DIR}/vectorscan/bin/route10-suricata" ]; then
        vectorscan_present="present"
    else
        vectorscan_present="absent"
    fi

    suricata_proc="$(ps -w | grep 'Suricata-Main' | grep -v grep | head -n 1 || true)"
    ips_proc="$(ps -w | grep '/usr/sbin/ips' | grep -v grep | head -n 1 || true)"

    mode="Unknown / stopped"
    if iptables -t mangle -S 2>/dev/null | grep -q 'IPS_NFQ'; then
        mode="Inline IPS"
    elif [ -n "$ips_proc" ] && iptables -S forwarding_rule 2>/dev/null | grep -q ' -j ips'; then
        mode="IDS + reactive blocking"
    elif [ -n "$suricata_proc" ] && [ -n "$ips_proc" ]; then
        mode="IDS + reactive blocking"
    fi

    if [ -x "${REMOTE_DIR}/vectorscan/bin/route10-suricata" ] && "${REMOTE_DIR}/vectorscan/bin/route10-suricata" --build-info 2>/dev/null | grep -iE 'Hyperscan support:[[:space:]]*yes' >/dev/null; then
        matcher="mpm-hs active (Vectorscan)"
    else
        matcher="unavailable"
    fi

    if [ -f "$active_yaml" ] && grep -Fqx "  - /a/suricata-vectorscan/lib/suricata/ndpi.so" "$active_yaml" 2>/dev/null; then
        if [ -f "/a/suricata-vectorscan/lib/suricata/ndpi.so" ]; then
            ndpi_status="enabled"
        else
            ndpi_status="missing"
        fi
    else
        ndpi_status="disabled"
    fi

    if [ -f "$active_yaml" ] && sed -n '/^[[:space:]]*websocket:/,/^[[:space:]]\{4\}[a-z0-9-][a-z0-9-]*:/p' "$active_yaml" | grep -q '^[[:space:]]*enabled:[[:space:]]*yes$'; then
        websocket_status="enabled"
    else
        websocket_status="disabled"
    fi

    if [ -f "$active_yaml" ] && grep -Fq "route10-websocket.rules" "$active_yaml" 2>/dev/null; then
        websocket_rules_status="enabled"
    else
        websocket_rules_status="disabled"
    fi

    if [ -f "$active_yaml" ] && grep -Fq "route10-ndpi-bypass.rules" "$active_yaml" 2>/dev/null; then
        ndpi_bypass_status="enabled"
    else
        ndpi_bypass_status="disabled"
    fi

    if [ -f "$active_yaml" ] && grep -Fq "route10-ndpi-security.rules" "$active_yaml" 2>/dev/null; then
        ndpi_security_status="enabled"
    else
        ndpi_security_status="disabled"
    fi

    rules_line="$(grep 'rules successfully loaded' /var/log/suricata/suricata.log 2>/dev/null | tail -n 1 || true)"
    [ -n "$rules_line" ] || rules_line="unavailable"

    cron_update="$(grep 'suricata-update' "$CRON_FILE" 2>/dev/null | head -n 1 || true)"
    [ -n "$cron_update" ] || cron_update="unavailable"

    cron_prune="$(grep 'post-update-prune.sh' "$CRON_FILE" 2>/dev/null | head -n 1 || true)"
    [ -n "$cron_prune" ] || cron_prune="unavailable"

    cron_runner="$(grep 'runner.sh update' "$CRON_FILE" 2>/dev/null | head -n 1 || true)"
    [ -n "$cron_runner" ] || cron_runner="unavailable"

    hook_status="absent"
    current_start_line="${START_SCRIPT} &"
    commented_start_line="# ${START_SCRIPT} &"
    if [ -f "$POST_CFG" ]; then
        if grep -Fqx "$current_start_line" "$POST_CFG" 2>/dev/null; then
            hook_status="enabled"
        elif grep -Fqx "$commented_start_line" "$POST_CFG" 2>/dev/null; then
            hook_status="disabled (commented)"
        elif grep -Fqx "# BEGIN ${PROJECT_TAG}" "$POST_CFG" 2>/dev/null; then
            hook_status="present"
        fi
    fi

    echo "Project Dir: ${REMOTE_DIR}"
    print_suricata_runner_version
    echo "Vectorscan Runtime: ${vectorscan_present}"
    echo "Policy IPS_INLINE: ${project_inline:-unavailable}"
    echo "Active Policy IPS_INLINE: ${active_inline:-unavailable}"
    echo "Policy ENABLE_NDPI: ${project_ndpi:-unavailable}"
    echo "Policy ENABLE_WEBSOCKET: ${project_websocket:-unavailable}"
    echo "Policy ENABLE_WEBSOCKET_RULES: ${project_ws_rules:-unavailable}"
    echo "Policy ENABLE_NDPI_BYPASS: ${project_ndpi_bypass:-unavailable}"
    echo "Policy ENABLE_NDPI_SECURITY: ${project_ndpi_security:-unavailable}"
    echo "Policy ENABLE_AUTO_UPDATE: ${project_auto_update:-0}"
    if [ -n "$suricata_proc" ]; then
        echo "Suricata Process: running"
    else
        echo "Suricata Process: stopped"
    fi
    if [ -n "$ips_proc" ]; then
        echo "IPS Daemon: running"
    else
        echo "IPS Daemon: stopped"
    fi
    echo "Mode: ${mode}"
    echo "Matcher: ${matcher}"
    echo "nDPI Plugin: ${ndpi_status}"
    echo "WebSocket Parser: ${websocket_status}"
    echo "WebSocket Rules: ${websocket_rules_status}"
    echo "nDPI Bypass Rules: ${ndpi_bypass_status}"
    echo "nDPI Security Rules: ${ndpi_security_status}"
    echo "Rules: ${rules_line}"
    echo "Cron Update: ${cron_update}"
    echo "Cron Prune: ${cron_prune}"
    echo "Cron Runner: ${cron_runner}"
    echo "Post-Cfg Hook: ${hook_status}"
}

main() {
    local cmd

    case "${1:-}" in
        -v|--version)
            print_version
            exit 0
            ;;
        -h|--help|'')
            print_help
            exit 0
            ;;
    esac

    cmd="$1"
    shift || true

    case "$cmd" in
        setup)
            run_setup "$@"
            ;;
        apply|prune|boot-prune)
            run_apply "$@"
            ;;
        start)
            run_start
            ;;
        status)
            run_status
            ;;
        update)
            run_update "$@"
            ;;
        version)
            print_version
            ;;
        help)
            print_help
            ;;
        *)
            error "Unknown command: $cmd"
            ;;
    esac
}

main "$@"
