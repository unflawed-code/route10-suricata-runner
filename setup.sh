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
POST_CFG_BLOCK_BEGIN="# BEGIN ${PROJECT_TAG}"
POST_CFG_BLOCK_END="# END ${PROJECT_TAG}"
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

sync_managed_rules() {
    local src_dir="${REMOTE_DIR}/rules"
    local rule_file

    [ -d "$src_dir" ] || return 0
    mkdir -p "$RULES_DST"

    for rule_file in route10-websocket.rules route10-ndpi-bypass.rules; do
        if [ -f "${src_dir}/${rule_file}" ]; then
            cp -f "${src_dir}/${rule_file}" "${RULES_DST}/${rule_file}"
        fi
    done
    chown -R suricata:suricata "$RULES_DST" 2>/dev/null || true
}

ensure_suricata_update_cron() {
    local target_update="30 3 * * * /usr/bin/suricata-update --fail --no-test"
    local target_prune="32 3 * * * ${POST_UPDATE_PRUNE_SCRIPT}"
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
        log "Canonicalized Suricata cron to run real suricata-update at 3:30 AM and post-update prune at 3:32 AM"
        /etc/init.d/cron restart >/dev/null 2>&1 || true
    else
        rm -f "${CRON_FILE}.tmp"
    fi
}

ensure_runner_update_cron() {
    local policy_conf="/etc/suricata/ips-policy.conf"
    [ -f "$policy_conf" ] || policy_conf="${REMOTE_DIR}/ips-policy.conf"
    
    local auto_update
    auto_update=$(sed -n "s/^ENABLE_AUTO_UPDATE=//p" "$policy_conf" | tail -n 1 | tr -d ' \n\r\t')
    
    local target_cron="30 4 * * * /bin/ash ${REMOTE_DIR}/runner.sh update"
    [ -f "$CRON_FILE" ] || return 0

    if [ "$auto_update" = "1" ]; then
        if ! grep -Fqx "$target_cron" "$CRON_FILE" 2>/dev/null; then
            log "Enabling automated runner updates in cron (daily at 4:30 AM)..."
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
        -v begin="$POST_CFG_BLOCK_BEGIN" \
        -v end="$POST_CFG_BLOCK_END" \
        -v marker="$POST_CFG_BLOCK_COMMENT" \
        -v current_start="$START_WRAPPER" '
        BEGIN {
            in_block = 0
            skip_after_marker = 0
        }
        $0 == begin { in_block = 1; next }
        in_block && $0 == end { in_block = 0; next }
        in_block { next }
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
        printf '\n%s\n%s\n%s\n%s\n\n' \
            "$POST_CFG_BLOCK_BEGIN" \
            "$POST_CFG_BLOCK_COMMENT" \
            "$canonical_start" \
            "$POST_CFG_BLOCK_END"

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
[ -f "$CUSTOM_SCRIPT" ] && chmod +x "$CUSTOM_SCRIPT"
[ -f "$BOOT_PRUNE_SCRIPT" ] && chmod +x "$BOOT_PRUNE_SCRIPT"
[ -f "$START_WRAPPER" ] && chmod +x "$START_WRAPPER"
[ -f "$POST_UPDATE_PRUNE_SCRIPT" ] && chmod +x "$POST_UPDATE_PRUNE_SCRIPT"
[ -f "$VECTORSCAN_HELPER" ] && chmod +x "$VECTORSCAN_HELPER"
[ -f "$VERSION_SCRIPT" ] && chmod +x "$VERSION_SCRIPT"
[ -f "${REMOTE_DIR}/scripts/updater.sh" ] && chmod +x "${REMOTE_DIR}/scripts/updater.sh"
[ -f "${REMOTE_DIR}/updater.sh" ] && chmod +x "${REMOTE_DIR}/updater.sh"
# Also handle other scripts if present
[ -f "${REMOTE_DIR}/scripts/suricata-update.sh" ] && chmod +x "${REMOTE_DIR}/scripts/suricata-update.sh"
[ -f "${REMOTE_DIR}/suricata-update.sh" ] && chmod +x "${REMOTE_DIR}/suricata-update.sh"

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
