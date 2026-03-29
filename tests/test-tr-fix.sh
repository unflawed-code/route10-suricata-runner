#!/bin/ash
# Test script to verify tr fix on router
. /cfg/suricata-runner/scripts/version.sh

uci_v=$(get_uci_version version)
uci_s=$(get_uci_version suricata)
uci_vs=$(get_uci_version vectorscan)
uci_n=$(get_uci_version ndpi)

echo "=== UCI Values ==="
echo "UCI_VERSION=$uci_v"
echo "UCI_SURICATA=$uci_s"
echo "UCI_VECTORSCAN=$uci_vs"
echo "UCI_NDPI=$uci_n"

echo "=== Script Values ==="
echo "SCRIPT_VERSION=$SURICATA_RUNNER_VERSION"
echo "SCRIPT_SURICATA=$SURICATA_BUNDLED_VERSION"
echo "SCRIPT_VECTORSCAN=$VECTORSCAN_BUNDLED_VERSION"
echo "SCRIPT_NDPI=$NDPI_BUNDLED_VERSION"

echo "=== Match Tests ==="
[ "$uci_v" = "$SURICATA_RUNNER_VERSION" ] && echo "VERSION: PASS" || echo "VERSION: FAIL ($uci_v != $SURICATA_RUNNER_VERSION)"
[ "$uci_s" = "$SURICATA_BUNDLED_VERSION" ] && echo "SURICATA: PASS" || echo "SURICATA: FAIL ($uci_s != $SURICATA_BUNDLED_VERSION)"
[ "$uci_vs" = "$VECTORSCAN_BUNDLED_VERSION" ] && echo "VECTORSCAN: PASS" || echo "VECTORSCAN: FAIL ($uci_vs != $VECTORSCAN_BUNDLED_VERSION)"
[ "$uci_n" = "$NDPI_BUNDLED_VERSION" ] && echo "NDPI: PASS" || echo "NDPI: FAIL ($uci_n != $NDPI_BUNDLED_VERSION)"

echo "=== Flag Normalization ==="
normalize_flag() { printf '%s' "${1:-0}" | tr -d ' \n\r\t'; }
result=$(normalize_flag "1")
[ "$result" = "1" ] && echo "FLAG_1: PASS" || echo "FLAG_1: FAIL (got '$result')"
result=$(normalize_flag "0")
[ "$result" = "0" ] && echo "FLAG_0: PASS" || echo "FLAG_0: FAIL (got '$result')"

echo "=== Auto-Update Parse ==="
auto_update=$(sed -n "s/^ENABLE_AUTO_UPDATE=//p" "/etc/suricata/ips-policy.conf" | tail -n 1 | tr -d ' \n\r\t')
echo "ENABLE_AUTO_UPDATE=$auto_update"

echo "=== Done ==="
