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
UCI_CONFIG_FILE="/etc/config/suricata-runner"
POST_UPDATE_PRUNE_SCRIPT="${REMOTE_DIR}/scripts/post-update-prune.sh"
[ ! -f "$POST_UPDATE_PRUNE_SCRIPT" ] && POST_UPDATE_PRUNE_SCRIPT="${REMOTE_DIR}/post-update-prune.sh"
RUNNER_SCRIPT="${REMOTE_DIR}/runner.sh"

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$line" >> "$LOG_FILE"
    echo "$line"
}

get_policy_value() {
    local key="$1"
    local default_value="$2"
    local policy_conf="/etc/suricata/ips-policy.conf"
    local value

    [ -f "$policy_conf" ] || policy_conf="${REMOTE_DIR}/ips-policy.conf"
    [ -f "$policy_conf" ] || {
        printf '%s' "$default_value"
        return 0
    }

    value="$(sed -n "s/^${key}=//p" "$policy_conf" | tail -n 1 | tr -d '\r')"
    value="$(printf '%s' "$value" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    if [ -n "$value" ]; then
        printf '%s' "$value"
    else
        printf '%s' "$default_value"
    fi
}

is_valid_cron_schedule() {
    [ -n "${1:-}" ] || return 1
    printf '%s\n' "$1" | awk '
        function isnum(v) { return v ~ /^[0-9]+$/ }
        function check_token(tok, min, max,    base, step, pair) {
            base = tok
            step = ""
            if (index(tok, "/")) {
                split(tok, pair, "/")
                if (length(pair[1]) == 0 || length(pair[2]) == 0) return 0
                base = pair[1]
                step = pair[2]
                if (!isnum(step) || step < 1) return 0
            }
            if (base == "*") return 1
            if (index(base, "-")) {
                split(base, pair, "-")
                if (length(pair[1]) == 0 || length(pair[2]) == 0) return 0
                if (!isnum(pair[1]) || !isnum(pair[2])) return 0
                if (pair[1] < min || pair[1] > max || pair[2] < min || pair[2] > max) return 0
                return (pair[1] <= pair[2])
            }
            if (isnum(base)) return (base >= min && base <= max)
            return 0
        }
        function check_field(field, min, max,    i, n, parts) {
            n = split(field, parts, ",")
            if (n < 1) return 0
            for (i = 1; i <= n; i++) {
                if (!check_token(parts[i], min, max)) return 0
            }
            return 1
        }
        NF != 5 { exit 1 }
        !check_field($1, 0, 59) { exit 1 }
        !check_field($2, 0, 23) { exit 1 }
        !check_field($3, 1, 31) { exit 1 }
        !check_field($4, 1, 12) { exit 1 }
        !check_field($5, 0, 7)  { exit 1 }
        { exit 0 }
    ' >/dev/null 2>&1
}

cron_or_default() {
    local candidate="$1"
    local fallback="$2"
    local label="$3"
    if is_valid_cron_schedule "$candidate"; then
        printf '%s' "$candidate"
    else
        [ -n "$candidate" ] && log "Invalid ${label} cron '$candidate'; using '$fallback'."
        printf '%s' "$fallback"
    fi
}

ensure_suricata_update_cron() {
    local update_cron prune_cron target_update target_prune
    update_cron="$(get_policy_value "SURICATA_UPDATE_CRON" "30 3 * * *")"
    prune_cron="$(get_policy_value "POST_UPDATE_PRUNE_CRON" "32 3 * * *")"
    update_cron="$(cron_or_default "$update_cron" "30 3 * * *" "SURICATA_UPDATE_CRON")"
    prune_cron="$(cron_or_default "$prune_cron" "32 3 * * *" "POST_UPDATE_PRUNE_CRON")"
    target_update="${update_cron} /usr/bin/suricata-update --fail --no-test"
    target_prune="${prune_cron} ${POST_UPDATE_PRUNE_SCRIPT}"
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
        log "Canonicalized Suricata cron (update: $update_cron, prune: $prune_cron)"
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

# 3a. UCI Version Restore
# After a firmware update, the UCI overlay is wiped but .setup_done persists on /cfg.
# Detect this case and re-populate the volatile UCI version data without re-running
# the full setup (archive extraction, patching, etc.).
restore_uci_versions() {
    local version_script="${REMOTE_DIR}/scripts/version.sh"
    [ ! -f "$version_script" ] && version_script="${REMOTE_DIR}/version.sh"
    [ -f "$version_script" ] || return 0
    . "$version_script"
    [ -f "$UCI_CONFIG_FILE" ] || touch "$UCI_CONFIG_FILE"
    if ! uci -q get suricata-runner.system >/dev/null 2>&1; then
        uci set suricata-runner.system=system
    fi
    uci set suricata-runner.system.version="$SURICATA_RUNNER_VERSION"
    uci set suricata-runner.system.suricata="$SURICATA_BUNDLED_VERSION"
    uci set suricata-runner.system.vectorscan="$VECTORSCAN_BUNDLED_VERSION"
    uci set suricata-runner.system.ndpi="$NDPI_BUNDLED_VERSION"
    uci commit suricata-runner
    log "UCI version data restored after firmware update."
}

if ! uci -q get suricata-runner.system >/dev/null 2>&1; then
    log "UCI version data missing (firmware update?). Restoring..."
    restore_uci_versions
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
    if grep -Eq '^[[:space:]]*#[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test' /usr/bin/suricatad.sh 2>/dev/null; then
        :
    elif grep -Eq '^[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test' /usr/bin/suricatad.sh 2>/dev/null; then
        tmp_file="/usr/bin/suricatad.sh.tmp"
        awk '
            /^[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test/ {
                print "# " $0
                next
            }
            { print }
        ' /usr/bin/suricatad.sh > "$tmp_file" && mv "$tmp_file" /usr/bin/suricatad.sh

        if ! grep -Eq '^[[:space:]]*#[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test' /usr/bin/suricatad.sh 2>/dev/null; then
            log "WARNING: Failed to patch /usr/bin/suricatad.sh; vendor script layout may have changed."
        fi
    else
        log "WARNING: /usr/bin/suricatad.sh no longer contains the expected suricata-update call; skipping patch."
    fi
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
