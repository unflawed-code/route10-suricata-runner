#!/bin/ash
set -eu

LOGTAG="suricata-post-update"

log() {
    logger -t "$LOGTAG" "$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

is_running() {
    ps -w | grep -E 'Suricata-Main|/usr/bin/.suricata' | grep -v grep >/dev/null 2>&1
}

ensure_runtime_prereqs() {
    mkdir -p /var/lib/suricata/rules
    ln -sf /a/suricata/data/rules/suricata.rules /var/lib/suricata/rules/suricata.rules
    mkdir -p /var/log/suricata
    chown -R suricata:suricata /var/log/suricata 2>/dev/null || true

    # Avoid libmagic crash by disabling files logger (idempotent).
    YAML="/usr/share/suricata/suricata-ips-nfq.yaml"
    if [ -f "$YAML" ]; then
        if grep -q '^[[:space:]]*-[[:space:]]*files:' "$YAML"; then
            sed -i 's/^[[:space:]]*-[[:space:]]*files:/#        - files:/' "$YAML"
        fi
        if grep -q '^[[:space:]]*force-magic:' "$YAML"; then
            sed -i 's/^[[:space:]]*force-magic:/#            force-magic:/' "$YAML"
        fi
    fi
}

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
        log "starting via /usr/bin/suricata"
        /usr/bin/suricata -c /usr/share/suricata/suricata-ips-nfq.yaml --af-packet=br-lan -D
    fi
fi

log "post-update prune complete"
