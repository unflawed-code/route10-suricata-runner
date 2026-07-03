#!/bin/sh
set -eu

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SELF_DIR")"
TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t r10suri-multiline)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP_DIR/scripts"
cp "$ROOT_DIR/scripts/ips-rule-policy.sh" "$TMP_DIR/scripts/ips-rule-policy.sh"
cat > "$TMP_DIR/logger" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMP_DIR/logger"

cat > "$TMP_DIR/ips-policy.conf" <<'EOF'
IPS_ENABLED=1
IPS_INLINE=1
IPS_INLINE_BLOCK=1
IPS_ALLOWED_CATEGORIES="web-application-attack"
ENABLE_NDPI=1
EOF

RULES_FILE="$TMP_DIR/suricata.rules"
DISABLE_OUT="$TMP_DIR/disable.conf"
DROP_OUT="$TMP_DIR/drop.conf"

cat > "$RULES_FILE" <<'EOF'
# DNP3 application decoder event rules.
alert dnp3 any any -> any any (msg:"SURICATA DNP3 Request flood detected"; \
      app-layer-event:dnp3.flooded; classtype:protocol-command-decode; sid:2270000; rev:2;)
alert dnp3 any any -> any any (msg:"SURICATA DNP3 Length too small"; \

alert http any any -> any any (msg:"allowed web app attack"; classtype:web-application-attack; sid:1001; rev:1;)
EOF

PATH="$TMP_DIR:$PATH" \
RULES_OVERRIDE="$RULES_FILE" \
DISABLE_OUT="$DISABLE_OUT" \
DROP_OUT="$DROP_OUT" \
/bin/sh "$TMP_DIR/scripts/ips-rule-policy.sh"

grep -Fqx '2270000' "$DISABLE_OUT"
grep -Fqx '# alert dnp3 any any -> any any (msg:"SURICATA DNP3 Request flood detected"; \' "$RULES_FILE"
grep -Fqx '#       app-layer-event:dnp3.flooded; classtype:protocol-command-decode; sid:2270000; rev:2;)' "$RULES_FILE"
grep -Fqx '# alert dnp3 any any -> any any (msg:"SURICATA DNP3 Length too small"; \' "$RULES_FILE"
grep -Fqx 'drop http any any -> any any (msg:"allowed web app attack"; classtype:web-application-attack; sid:1001; rev:1;)' "$RULES_FILE"

echo "PASS: multiline rules are pruned as complete logical rules"