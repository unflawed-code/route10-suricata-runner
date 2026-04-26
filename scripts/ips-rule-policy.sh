#!/bin/sh
# Integrated Route10 Suricata Rule Policy & Optimization Script (V5)
# Uses Python3 for robust category-based pruning (BusyBox awk-compatible).

set -eu

# Resolve the absolute path to this script (handle symlinks)
REAL_PATH="$(readlink -f "$0")"
SELF_DIR="$(cd "$(dirname "$REAL_PATH")" && pwd)"
# If inside 'scripts', the project root is one level up
if [ "$(basename "$SELF_DIR")" = "scripts" ]; then
    REMOTE_DIR="$(dirname "$SELF_DIR")"
else
    REMOTE_DIR="$SELF_DIR"
fi

RULES=""
for cand in \
    /a/suricata/data/rules/suricata.rules \
    /var/lib/suricata/rules/suricata.rules \
    /etc/suricata/rules/suricata.rules \
    /usr/share/suricata/rules/suricata.rules
do
    if [ -f "$cand" ]; then
        RULES="$cand"
        break
    fi
done

POLICY_CONF="${REMOTE_DIR}/ips-policy.conf"
if [ ! -f "$POLICY_CONF" ]; then
    POLICY_CONF=/etc/suricata/ips-policy.conf
fi
DISABLE_OUT=/etc/suricata/disable.conf
DROP_OUT=/etc/suricata/drop.conf

# Defaults
IPS_ENABLED=0
IPS_INLINE=0
IPS_INLINE_BLOCK=1
IPS_ALLOWED_CATEGORIES=""
IPS_SUPPRESS_SIDS=""
ENABLE_NDPI=0
[ -f "$POLICY_CONF" ] && . "$POLICY_CONF"
# Source local overrides if present (user-specific, not tracked by git)
LOCAL_CONF="${REMOTE_DIR}/ips-policy-local.conf"
[ -f "$LOCAL_CONF" ] && . "$LOCAL_CONF"

log() { logger -t ips-rule-policy.sh "$@"; }

if [ "${IPS_ENABLED}" != "1" ]; then
    : > "$DISABLE_OUT"
    : > "$DROP_OUT"
    chmod 0644 "$DISABLE_OUT" "$DROP_OUT"
    log "IPS disabled; wrote empty policy files."
    exit 0
fi

if [ -z "$RULES" ] || [ ! -f "$RULES" ]; then
    log "ERROR: rules file not found in known locations."
    exit 1
fi

log "Starting: rules='$RULES' inline=${IPS_INLINE} ndpi=${ENABLE_NDPI} categories='${IPS_ALLOWED_CATEGORIES}'"

# Run Python3 to analyze rules and perform in-place pruning
python3 - "$RULES" "$DISABLE_OUT" "$DROP_OUT" \
         "$IPS_ALLOWED_CATEGORIES" "$IPS_INLINE" "$IPS_INLINE_BLOCK" "$ENABLE_NDPI" "$IPS_SUPPRESS_SIDS" << 'PYEOF'
import sys, re

rules_file   = sys.argv[1]
disable_out  = sys.argv[2]
drop_out     = sys.argv[3]
allowed_cats = set(sys.argv[4].split()) if sys.argv[4].strip() else set()
ips_inline   = sys.argv[5] == "1"
ips_inline_block = sys.argv[6] == "1"
enable_ndpi  = sys.argv[7] == "1"
suppress_raw = sys.argv[8] if len(sys.argv) > 8 else ""
suppress_sids = set(s.strip() for s in suppress_raw.split(',') if s.strip())

# Phase 1: Analyze rules, build disable SID set
SID_RE  = re.compile(r'\bsid:(\d+)')
CLS_RE  = re.compile(r'\bclasstype:(\S+?)(?:;|$|\s)')

# SIDs from IPS_SUPPRESS_SIDS in ips-policy.conf (user-configurable false positive list)
disable_sids = set(suppress_sids)
drop_sids    = set()

with open(rules_file) as f:
    for line in f:
        # Strip comment prefix for analysis
        raw = line.strip()
        if raw.startswith('#'):
            raw = raw.lstrip('#').lstrip()

        m_sid = SID_RE.search(raw)
        if not m_sid:
            continue
        sid = m_sid.group(1)

        # User-defined suppression list
        if sid in suppress_sids:
            disable_sids.add(sid)
            continue

        m_cls  = CLS_RE.search(raw)

        # Protocol filter (Suricata 8 on Route10 is very picky)
        ALLOWED_PROTOS = {'tcp', 'udp', 'icmp', 'ip', 'http', 'tls', 'dns', 'http1', 'http2', 'websocket'}
        proto_match = re.match(r'^\s*#?\s*(?:drop|alert|reject|pass)\s+(\S+)', line)
        if proto_match:
            proto = proto_match.group(1).lower()
            if proto not in ALLOWED_PROTOS:
                disable_sids.add(sid)
                continue

        cls  = m_cls.group(1).rstrip(';') if m_cls else ''

        # nDPI filter
        if not enable_ndpi and 'ndpi-protocol:' in raw:
            disable_sids.add(sid)
            continue

        # Category filter (most aggressive)
        if (not cls) or (cls not in allowed_cats):
            disable_sids.add(sid)
            continue

        if ips_inline and ips_inline_block:
            drop_sids.add(sid)

# Phase 2: Add noise reduction regex entries
noise = [
    're:msg:"SURICATA STREAM FIN invalid ack"',
    're:msg:"SURICATA STREAM packet out of window"',
    're:msg:"SURICATA STREAM reassembly overlap"',
    're:msg:"SURICATA STREAM excessive retransmissions"',
    're:msg:"SURICATA STREAM ESTABLISHED invalid ack"',
]

with open(disable_out, 'w') as f:
    for sid in sorted(disable_sids, key=int):
        f.write(sid + '\n')
    for n in noise:
        f.write(n + '\n')

with open(drop_out, 'w') as f:
    for sid in sorted(drop_sids, key=int):
        f.write(sid + '\n')

print(f"disable: {len(disable_sids)} SIDs, drop: {len(drop_sids)} SIDs", file=sys.stderr)

# Phase 4: In-place pruning
RULE_LINE_RE = re.compile(r'^\s*#?\s*(alert|drop|reject|pass|pkthdr)\s')
pruned = 0
active = 0
with open(rules_file) as inp, open(rules_file + '.tmp', 'w') as out:
    for line in inp:
        stripped = line.strip()
        if not stripped:
            out.write(line)
            continue
            
        orig = stripped.lstrip('#').lstrip()
        m = SID_RE.search(orig)
        if m and RULE_LINE_RE.match(line):
            sid = m.group(1)
            if sid in disable_sids:
                # Ensure line is commented
                if not stripped.startswith('#'):
                    out.write('# ' + line)
                else:
                    out.write(line)
                pruned += 1
            else:
                # Ensure line is UNcommented (restore)
                rule_text = orig
                if ips_inline and ips_inline_block:
                    # Convert alert to drop for active rules only when inline blocking is enabled
                    if rule_text.startswith('alert '):
                        rule_text = 'drop ' + rule_text[6:]
                out.write(rule_text + '\n')
                active += 1
        elif stripped.startswith('#') or RULE_LINE_RE.match(line):
            # Keep comments or headers
            out.write(line)
        else:
            # Skip noise like "DEBUG_COMMENTED"
            continue

import os
os.replace(rules_file + '.tmp', rules_file)
print(f"Rules: {active} active, {pruned} pruned", file=sys.stderr)
PYEOF

log "Category pruning complete. $(wc -l < "$DISABLE_OUT") entries in disable.conf."
