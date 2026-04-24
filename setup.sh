#!/bin/ash
# Integrated Suricata Optimization Setup for Route10
# Replaces system rule policy script with optimized in-place pruner.

# Detect local directory
REMOTE_DIR="$(cd "$(dirname "$0")" && pwd)"
SYSTEM_SCRIPT="/usr/sbin/ips-rule-policy.sh"
POST_CFG="/cfg/post-cfg.sh"
VECTORSCAN_RUNTIME_ROOT="/a/suricata-vectorscan"
RULES_DST="/var/lib/suricata/rules"
CRON_FILE="/etc/crontabs/root"
PROJECT_TAG="route10-suricata-runner"
POST_CFG_BLOCK_COMMENT="# Initialize optimized Suricata rule policy and configuration"
VERSION_SCRIPT="${REMOTE_DIR}/scripts/version.sh"
[ ! -f "$VERSION_SCRIPT" ] && VERSION_SCRIPT="${REMOTE_DIR}/version.sh"
LOGROTATE_SRC="${REMOTE_DIR}/logrotate/route10-suricata-runner.conf"
LOGROTATE_DST="/etc/logrotate.d/route10-suricata-runner"

normalize_crlf_file() {
    [ -f "$1" ] || return 0
    sed -i 's/\r$//' "$1" 2>/dev/null || true
}

normalize_project_line_endings() {
    local candidate

    find "$REMOTE_DIR" -type f \
        \( \
            -name '*.sh' -o \
            -name '*.conf' -o \
            -name '*.rules' -o \
            -name '*.template' -o \
            -name '*.yaml' -o \
            -name '*.yml' -o \
            -name '*.md' -o \
            -name '*.txt' \
        \) \
        | while IFS= read -r candidate; do
            normalize_crlf_file "$candidate"
        done
}

normalize_project_line_endings

if [ "${1:-}" = "-v" ] || [ "${1:-}" = "--version" ]; then
    if [ -f "$VERSION_SCRIPT" ]; then
        . "$VERSION_SCRIPT"
        print_suricata_runner_version
        exit 0
    fi
    echo "ERROR: Missing version helper at $VERSION_SCRIPT" >&2
    exit 1
fi

# Detect script locations (support flat or scripts/ subdir)
CUSTOM_SCRIPT="${REMOTE_DIR}/scripts/ips-rule-policy.sh"
[ ! -f "$CUSTOM_SCRIPT" ] && CUSTOM_SCRIPT="${REMOTE_DIR}/ips-rule-policy.sh"

BOOT_PRUNE_SCRIPT="${REMOTE_DIR}/scripts/boot-prune.sh"
[ ! -f "$BOOT_PRUNE_SCRIPT" ] && BOOT_PRUNE_SCRIPT="${REMOTE_DIR}/boot-prune.sh"

START_WRAPPER="${REMOTE_DIR}/scripts/start.sh"
[ ! -f "$START_WRAPPER" ] && START_WRAPPER="${REMOTE_DIR}/start.sh"
POST_UPDATE_PRUNE_SCRIPT="${REMOTE_DIR}/scripts/post-update-prune.sh"
[ ! -f "$POST_UPDATE_PRUNE_SCRIPT" ] && POST_UPDATE_PRUNE_SCRIPT="${REMOTE_DIR}/post-update-prune.sh"
VECTORSCAN_HELPER="${REMOTE_DIR}/scripts/vectorscan-runtime.sh"
[ ! -f "$VECTORSCAN_HELPER" ] && VECTORSCAN_HELPER="${REMOTE_DIR}/vectorscan-runtime.sh"

log() {
    echo "[setup] $1"
}

ensure_project_script_permissions() {
    local script_path

    find "$REMOTE_DIR" -type f -name '*.sh' | while IFS= read -r script_path; do
        [ -f "$script_path" ] || continue
        chmod 700 "$script_path" 2>/dev/null || chmod +x "$script_path" 2>/dev/null || true
    done
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

sync_managed_rules() {
    local src_dir="${REMOTE_DIR}/rules"
    [ -d "$src_dir" ] || return 0
    mkdir -p "$RULES_DST"

    # We provide .rules.template files in the repo.
    # The actual .rules files are gitignored (user-owned).
    # If missing on first setup, initialize them from templates.
    local rule_base
    for rule_base in route10-websocket route10-ndpi-bypass route10-ndpi-security; do
        local template_file="${src_dir}/${rule_base}.rules.template"
        local target_local="${src_dir}/${rule_base}.rules"
        local target_system="${RULES_DST}/${rule_base}.rules"

        # Initialize from template if missing
        if [ ! -f "$target_local" ] && [ -f "$template_file" ]; then
            log "Initializing ${rule_base}.rules from template..."
            cp "$template_file" "$target_local"
        fi

        # Sync to system path if rules file exists
        if [ -f "$target_local" ]; then
            cp -f "$target_local" "$target_system"
        fi
    done
    chown -R suricata:suricata "$RULES_DST" 2>/dev/null || true
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

ensure_runner_update_cron() {
    local auto_update
    local runner_update_cron
    local target_cron
    auto_update="$(get_policy_value "ENABLE_AUTO_UPDATE" "0" | tr -d ' \n\r\t')"
    runner_update_cron="$(get_policy_value "RUNNER_UPDATE_CRON" "30 4 * * *")"
    runner_update_cron="$(cron_or_default "$runner_update_cron" "30 4 * * *" "RUNNER_UPDATE_CRON")"
    target_cron="${runner_update_cron} /bin/ash ${REMOTE_DIR}/runner.sh update"
    [ -f "$CRON_FILE" ] || return 0

    if [ "$auto_update" = "1" ]; then
        if ! grep -Fqx "$target_cron" "$CRON_FILE" 2>/dev/null; then
            log "Enabling automated runner updates in cron ($runner_update_cron)..."
            (grep -Fv "runner.sh update" "$CRON_FILE" 2>/dev/null || true; echo "$target_cron") > "${CRON_FILE}.tmp"
            mv "${CRON_FILE}.tmp" "$CRON_FILE"
            /etc/init.d/cron restart >/dev/null 2>&1 || true
        fi
    else
        if grep -Fq "runner.sh update" "$CRON_FILE" 2>/dev/null; then
            log "Disabling automated runner updates in cron..."
            grep -Fv "runner.sh update" "$CRON_FILE" > "${CRON_FILE}.tmp"
            mv "${CRON_FILE}.tmp" "$CRON_FILE"
            /etc/init.d/cron restart >/dev/null 2>&1 || true
        fi
    fi
}

install_logrotate_policy() {
    [ -f "$LOGROTATE_SRC" ] || return 0

    if ! cmp -s "$LOGROTATE_SRC" "$LOGROTATE_DST" 2>/dev/null; then
        cp -f "$LOGROTATE_SRC" "$LOGROTATE_DST"
        chmod 644 "$LOGROTATE_DST" 2>/dev/null || true
        log "Installed logrotate policy at $LOGROTATE_DST"
    fi
}

cleanup_legacy_logrotate_cron() {
    [ -f "$CRON_FILE" ] || return 0

    awk '
        index($0, "/etc/logrotate.d/route10-suricata-runner") { next }
        index($0, "logrotate.route10-suricata.state") { next }
        { print }
    ' "$CRON_FILE" > "${CRON_FILE}.tmp"

    if ! cmp -s "$CRON_FILE" "${CRON_FILE}.tmp" 2>/dev/null; then
        mv "${CRON_FILE}.tmp" "$CRON_FILE"
        /etc/init.d/cron restart >/dev/null 2>&1 || true
        log "Removed legacy 4-hour Route10 Suricata Runner logrotate cron entry."
    else
        rm -f "${CRON_FILE}.tmp"
    fi
}

ensure_post_cfg_hook() {
    local tmp_clean="${POST_CFG}.clean"
    local tmp_final="${POST_CFG}.tmp"
    local canonical_start="${START_WRAPPER} &"

    [ -f "$POST_CFG" ] || {
        printf '#!/bin/ash\n\n' > "$POST_CFG"
    }

    awk \
        -v marker="$POST_CFG_BLOCK_COMMENT" \
        -v current_start="$START_WRAPPER" '
        BEGIN {
            skip_after_marker = 0
        }
        $0 ~ /^# (BEGIN|END) route10-suricata-runner/ { next }
        skip_after_marker {
            skip_after_marker = 0
            if ($0 ~ /^#?[[:space:]]*\/cfg\/[^[:space:]]+\/(scripts\/)?start\.sh[[:space:]]*&[[:space:]]*$/) next
        }
        $0 == marker { skip_after_marker = 1; next }
        $0 == "# " current_start " &" { next }
        $0 == current_start " &" { next }
        $0 ~ /^#?[[:space:]]*\/cfg\/suricata-runner(2)?\/(scripts\/)?start\.sh[[:space:]]*&[[:space:]]*$/ { next }
        { print }
    ' "$POST_CFG" > "$tmp_clean"

    # Assemble final file: Shebang, Gap, Block, Gap, Rest
    {
        head -n 1 "$tmp_clean"
        printf '\n%s\n%s\n\n' \
            "$POST_CFG_BLOCK_COMMENT" \
            "$canonical_start"

        # Output the rest of the file, but skip leading blank lines to ensure exactly 1 gap
        tail -n +2 "$tmp_clean" | awk 'BEGIN { f=0 } /[^[:space:]]/ { f=1 } f { print }'
    } | awk '{ lines[NR] = $0 } END { while (NR > 0 && lines[NR] ~ /^[[:space:]]*$/) NR--; for (i = 1; i <= NR; i++) print lines[i]; print "" }' > "$tmp_final"


    rm -f "$tmp_clean"

    if ! cmp -s "$POST_CFG" "$tmp_final" 2>/dev/null; then
        mv "$tmp_final" "$POST_CFG"
        log "Installed managed startup hook block in $POST_CFG"
    else
        rm -f "$tmp_final"
    fi
}

log "Setting permissions on scripts..."
ensure_project_script_permissions

if [ ! -f "$VECTORSCAN_HELPER" ]; then
    log "ERROR: Missing Vectorscan helper at $VECTORSCAN_HELPER"
    exit 1
fi

. "$VECTORSCAN_HELPER"

log "Ensuring Vectorscan runtime from archive..."
if ! ensure_vectorscan_runtime_from_archive "$REMOTE_DIR" "$VECTORSCAN_RUNTIME_ROOT"; then
    exit 1
fi

# Integrate with system path
if [ ! -L "$SYSTEM_SCRIPT" ]; then
    log "Backing up original system script and creating symlink..."
    [ -f "$SYSTEM_SCRIPT" ] && mv "$SYSTEM_SCRIPT" "$SYSTEM_SCRIPT.bak"
    ln -s "$CUSTOM_SCRIPT" "$SYSTEM_SCRIPT"
else
    log "Symlink to $SYSTEM_SCRIPT already exists."
fi

has_disabled_suricata_update_call() {
    grep -Eq '^[[:space:]]*#[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test' "$1" 2>/dev/null
}

count_active_suricata_update_calls() {
    grep -Ec '^[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test' "$1" 2>/dev/null || true
}

patch_suricatad_script() {
    local script="/usr/bin/suricatad.sh"
    local tmp_file

    [ -f "$script" ] || return 0

    if has_disabled_suricata_update_call "$script"; then
        return 0
    fi

    if [ "$(count_active_suricata_update_calls "$script")" -lt 1 ]; then
        log "WARNING: /usr/bin/suricatad.sh no longer contains the expected suricata-update call; skipping patch."
        return 0
    fi

    log "Patching /usr/bin/suricatad.sh to save memory..."
    tmp_file="${script}.tmp"
    awk '
        /^[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test/ {
            print "# " $0
            next
        }
        { print }
    ' "$script" > "$tmp_file" && mv "$tmp_file" "$script"

    if ! has_disabled_suricata_update_call "$script"; then
        log "WARNING: Failed to patch /usr/bin/suricatad.sh; vendor script layout may have changed."
    fi
}

patch_suricata_update_script() {
    local script="/usr/bin/suricata-update.sh"
    local tmp_file active_count

    [ -f "$script" ] || return 0

    active_count="$(count_active_suricata_update_calls "$script")"
    if [ "$active_count" -le 1 ]; then
        if [ "$active_count" -eq 1 ] || has_disabled_suricata_update_call "$script"; then
            return 0
        fi
        log "WARNING: /usr/bin/suricata-update.sh no longer contains the expected duplicate suricata-update call; skipping patch."
        return 0
    fi

    log "Patching /usr/bin/suricata-update.sh to save memory during cron..."
    tmp_file="${script}.tmp"
    awk '
        /^[[:space:]]*suricata-update[[:space:]]+--fail[[:space:]]+--no-test/ {
            seen++
            if (seen > 1) {
                print "# " $0
                next
            }
        }
        { print }
    ' "$script" > "$tmp_file" && mv "$tmp_file" "$script"

    if [ "$(count_active_suricata_update_calls "$script")" -gt 1 ]; then
        log "WARNING: Failed to patch /usr/bin/suricata-update.sh; vendor script layout may have changed."
    fi
}

patch_suricatad_script
patch_suricata_update_script

# Ensure persistence in post-cfg.sh
log "Checking persistence hook in $POST_CFG..."
ensure_post_cfg_hook
chmod 755 "$POST_CFG"

log "Ensuring nightly Suricata update cron integration..."
ensure_suricata_update_cron
ensure_runner_update_cron
install_logrotate_policy
cleanup_legacy_logrotate_cron

log "Updating installed version in UCI..."
if [ -f "$VERSION_SCRIPT" ]; then
    # Source versions to get the current code values
    . "$VERSION_SCRIPT"
    # Initialize UCI config if missing
    [ -f "/etc/config/suricata-runner" ] || touch /etc/config/suricata-runner
    if ! uci -q get suricata-runner.system >/dev/null; then
        uci set suricata-runner.system=system
    fi
    uci set suricata-runner.system.version="$SURICATA_RUNNER_VERSION"
    uci set suricata-runner.system.suricata="$SURICATA_BUNDLED_VERSION"
    uci set suricata-runner.system.vectorscan="$VECTORSCAN_BUNDLED_VERSION"
    uci set suricata-runner.system.ndpi="$NDPI_BUNDLED_VERSION"
    uci commit suricata-runner
fi

log "Ensuring current session config is active..."
cp "${REMOTE_DIR}/ips-policy.conf" "/etc/suricata/ips-policy.conf"
sync_managed_rules

log "Ensuring Suricata runtime prerequisites..."
mkdir -p /a/suricata/data/rules
mkdir -p /var/log/suricata
mkdir -p /var/run/suricata
chown -R suricata:suricata /var/log/suricata /var/run/suricata 2>/dev/null || true
# Ensure system path is correct
if [ ! -L /var/lib/suricata ] && [ ! -d /var/lib/suricata ]; then
    ln -s /a/suricata/data /var/lib/suricata
fi

touch "${REMOTE_DIR}/.setup_done"

log "Applying policy and starting Suricata via boot-prune..."
"$BOOT_PRUNE_SCRIPT" 0

log "Setup complete. Policy applied and Suricata startup attempted."
log "NOTE: Boot persistence status check completed in $POST_CFG"
